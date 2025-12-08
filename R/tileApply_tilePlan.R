#' @include tileApply.R

# docs ####

#' @name tileApply-plan
#' @title Basic Tile Processing
#' @description
#' Apply functions across `tilePlan`-inheriting objects.
#'
#' **`token`** is a stand-in for any input data class (e.g. `SpatRaster`,
#' `SpatExtent`, filpath, etc). See [redispatch_tileapply]
#' and [extending_giottotile] for further information.
#'
#' @section Special Function Parameters:
#' Your `FUN` can optionally include these special parameters:
#' - `.I` - tile number (integer)
#' - `.TILE` - tile bounds/metadata
#' - `.R` - tile row number
#' - `.C` - tile column number
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles `tilePlan` inheriting object (`spatialTilePlan` or `pixelTilePlan`)
#' @param FUN function to apply to each tile
#' @param get_params_x named list. Additional params to pass to [getTile()] for
#'   `x`
#' @param get_params_y named list. Additional params to pass to [getTile()] for
#'   `y`
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has full
#' spatial context of `y`
#' @param future.seed logical. Enable reproducible random seeds
#' @param log logical. Whether to log processing steps
#' @param logpath character. Log file path (if log = `TRUE`)
#' @param verbose be verbose. Set as "debug" for more info on stack tracing.
#' @param \dots additional params to pass to [`[`][bracket]
#'
#' @seealso [tileApply], [tilePlan()], [spatialTilePlan-class], [pixelTilePlan-class]
#'
#' @examples
#' f <- system.file("ex/elev.tif", package = "terra")
#' r <- terra::rast(f)
#'
#' # Spatial tiling example
#' tp_spatial <- tilePlan("spatial")
#' ext(tp_spatial) <- ext(r)
#' length(tp_spatial) <- 4
#'
#' # Apply function with tile metadata
#' results <- tileApply(r, tiles = tp_spatial, FUN = function(tile, .I, .R, .C) {
#'     list(
#'         tile_id = .I,
#'         position = paste0("row_", .R, "_col_", .C),
#'         mean_value = terra::global(tile, "mean", na.rm = TRUE)[[1]]
#'     )
#' })
#' force(results)
#'
#' # Pixel tiling example
#' tp_pixel <- tilePlan("pixel")
#' tp_pixel$pxdims <- dim(r)[1:2]
#' tp_pixel$nrows <- 50
#' tp_pixel$ncols <- 50
#'
#' # Save tiles to disk
#' outdir <- file.path(tempdir(), "tiles")
#' dir.create(outdir, showWarnings = FALSE)
#'
#' tileApply(r, tiles = tp_pixel, FUN = function(tile, .I) {
#'     filename <- file.path(outdir, sprintf("tile_%03d.tif", .I))
#'     terra::writeRaster(tile, filename, overwrite = TRUE)
#'     return(filename)
#' })
#'
#' list.files(outdir)
#' unlink(outdir, recursive = TRUE)
NULL

# core methods ####

#* token x ####

#' @rdname tileApply-plan
#' @export
setMethod(
    "tileApply", signature("token", "missing", "tilePlan"),
    function(
        x, tiles, FUN,
        get_params_x = list(),
        log = FALSE,
        logpath = getTileworkLogDir(),
        future_params = list(future.seed = TRUE),
        verbose = NULL,
        ...) {
        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        checkmate::assert_list(get_params_x)
        checkmate::assert_list(future_params)
        checkmate::assert_function(FUN)
        checkmate::assert_flag(log)
        jid <- getTileworkJobID(advance = TRUE)
        if (log) .vmsg(.v = verbose, "logging as job", jid)
        with_pbar({
            p <- pbar(along = tiles)

            .future_fun <- function(i) {
                ij <- .tile_idx_to_ij(tiles, i)
                tile_id <- sprintf("[tile %d]", i)
                if (log) {
                    conn <- .log_conn(log_dir = logpath, job_id = jid)
                    on.exit(close(conn), add = TRUE)
                    .log_write(conn, sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]))
                }

                tile_ext <- tiles[i][[1L]]

                if (log) {
                    .log_write(conn, tile_id, "bounds:", .ext_to_num_vec(tile_ext))
                    .log_write(conn, tile_id, "pad:", tiles@pad)
                }

                get_params_x <- c(list(x, tiles, i = i), get_params_x, list(...))
                tile_data <- do.call(getTile, get_params_x)[[1L]]

                # special args injection
                a <- list(tile_data)
                nf <- names(formals(FUN))
                if (".I" %in% nf) a$.I <- i
                if (".TILE" %in% nf) a$.TILE <- tile_ext
                if (".R" %in% nf) a$.R <- ij[[1L]]
                if (".C" %in% nf) a$.C <- ij[[2L]]

                res <- do.call(FUN, args = a)

                p(message = paste(tile_id, "done"))
                if (log) .log_write(conn, paste(tile_id, "done"))
                return(res)
            }

            future_params <- c(
                X = list(seq_along(tiles)),
                FUN = .future_fun,
                future_params
            )

            do.call(lapply_flex, future_params)
        })
    }
)

#* token,token xy ####

#' @rdname tileApply-plan
#' @export
setMethod(
    "tileApply", signature("token", "token", "tilePlan"),
    function(
        x, y, tiles, FUN,
        get_params_x = list(),
        get_params_y = list(),
        pad_y = NULL,
        log = FALSE,
        logpath = getTileworkLogDir(),
        future_params = list(future.seed = TRUE),
        verbose = NULL,
        ...) {
        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        checkmate::assert_list(get_params_x)
        checkmate::assert_list(get_params_y)
        checkmate::assert_list(future_params)
        checkmate::assert_function(FUN)
        checkmate::assert_flag(log)
        jid <- getTileworkJobID(advance = TRUE)
        if (log) .vmsg(.v = verbose, "logging as job", jid)
        if (is.null(y)) stop("[tileApply] `y` may not be NULL\n.", call. = FALSE)
        with_pbar({
            p <- pbar(along = tiles)

            .future_fun <- function(i) {
                ij <- .tile_idx_to_ij(tiles, i)
                tile_id <- sprintf("[tile %d]", i)
                if (log) {
                    conn <- .log_conn(log_dir = logpath, job_id = jid)
                    on.exit(close(conn), add = TRUE)
                    .log_write(conn, sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]))
                }

                tile_ext <- tiles[i][[1L]]

                if (log) {
                    .log_write(conn, tile_id, "bounds:", .ext_to_num_vec(tile_ext))
                    .log_write(conn, tile_id, "pad:", tiles@pad)
                }

                # prep args
                get_params_x <- c(list(x, tiles, i = i), get_params_x, list(...))
                get_params_y <- c(list(y, tiles, i = i, pad = pad_y), get_params_y, list(...))
                # these are retrieved as list of 1
                tile_x <- do.call(getTile, get_params_x)[[1L]]
                tile_y <- do.call(getTile, get_params_y)[[1L]]

                # special args injection
                a <- list(tile_x, tile_y)
                nf <- names(formals(FUN))
                if (".I" %in% nf) a$.I <- i
                if (".TILE" %in% nf) a$.TILE <- tile_ext
                if (".R" %in% nf) a$.R <- ij[[1L]]
                if (".C" %in% nf) a$.C <- ij[[2L]]

                res <- do.call(FUN, args = a)

                p(message = paste(tile_id, "done"))
                if (log) .log_write(conn, paste(tile_id, "done"))
                return(res)
            }

            future_params <- c(
                X = list(seq_along(tiles)),
                FUN = .future_fun,
                future_params
            )

            do.call(lapply_flex, future_params)
        })
    }
)

# specific methods ####

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("character", "tilePlan"),
    function(sig, tiles, ...) {
        # expect warning about unknown type if wrong (rast vs vect) fun
        sig <- GiottoUtils::handle_warnings(.terra_read(sig))$result
        redispatch_tileapply(sig, tiles, ...)
    }
)

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("SpatVector", "spatialTilePlan"), function(sig, tiles, ...) {
    f <- terra::sources(sig)
    f <- unique(f)
    .guard_disk_terra_vector(f)
    callNextMethod(f, tiles,
        default_get_params = list(
            prefer = "vector" # to getTile,character
        ),
        ...
    )
})

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("SpatRaster", "spatialTilePlan"), function(sig, tiles, ...) {
    f <- terra::sources(sig)
    f <- unique(f)
    .guard_disk_terra_raster(f)
    e <- .ext_to_num_vec(ext(sig))
    callNextMethod(f, tiles,
        default_get_params = list(
            lyr = NULL, # to getTile,SpatRaster
            prefer = "raster", # to getTile,character
            ext = e # to getTile,character
        ),
        ...
    )
})

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("SpatRaster", "pixelTilePlan"), function(sig, tiles, ...) {
    f <- terra::sources(sig)
    f <- unique(f)
    .guard_disk_terra_raster(f)
    e <- .ext_to_num_vec(ext(sig))
    callNextMethod(f, tiles,
        default_get_params = list(
            lyr = NULL, # to getTile,SpatRaster
            prefer = "raster", # to getTile,character
            ext = e, # to getTile,character
            extend = FALSE, # to getTile,SpatRaster,pixelTilePlan
            fill = NA # to getTile,SpatRaster,pixelTilePlan
        ),
        ...
    )
})
