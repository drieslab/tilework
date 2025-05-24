#' @include generics.R

#' @name tileApply
#' @title Apply Across Spatial Tiles
#' @description
#' Apply a function across spatial tiles to both speed up processing and keep
#' memory usage reasonable for large operations. This function also hooks into
#' the \{future\} parallelization framework.
#'
#' @section SpatRaster:
#' This function currently only works for single source SpatRasters. Support
#' for applying across affine transformed images is still under development.
#'
#' @param x object to tile apply
#' @param FUN function to run across tiles. The first param must be the
#' `SpatRaster` object. If `.I` is included as a parameter, it can be used
#' in the function as the tile number.
#' @param ti `tileIterator` that defines the tiles to apply on.
#' @param lyr numeric. Layer number(s) to use
#' @param log logical. Whether to log processing steps to file.
#' @param logpath filepath. Filepath to log to. Otherwise, a temporary file
#' will be used.
#' @inheritParams GiottoUtils::lapply_flex
#' @param \dots additonal params to pass to [future.apply::future_lapply()]
#' @seealso [GiottoUtils::lapply_flex()] for the function passing to future.
#' @examples
#' f <- system.file("ex/elev.tif", package="terra")
#' r <- rast(f)
#' ti <- tileIterator()
#' ext(ti) <- ext(r)
#' length(ti) <- 4
#'
#' outdir <- file.path(tempdir(), "testwrite")
#' dir.create(outdir)
#'
#' tileApply(r, ti = ti, lyr = 1, FUN = function(x, .I) {
#'     terra::writeRaster(x,
#'         filename = file.path(outdir, sprintf("tile_%03d.tif", .I)))
#' })
#' list.files(outdir)
#'
#' r1 <- terra::rast(file.path(outdir, "tile_001.tif"))
#' plot(r1)
#'
#' # remove
#' rm(r1)
#' unlink(outdir, recursive = TRUE, force = TRUE)
NULL

#' @rdname tileApply
#' @export
setMethod("tileApply", signature("SpatRaster", "missing", "spatialTileIterator"), function(x, FUN, ti,
    lyr = NULL,
    cores = NA,
    future.seed = TRUE,
    log = FALSE,
    logpath = tempdir(),
    ...) {
    checkmate::assert_function(FUN)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    f <- terra::sources(x)[[1]] # only works for single source images
    if (length(unique(f)) > 1L) {
        stop("[tileApply] only works for single file images", call. = FALSE)
    }
    f <- unique(f)
    if (f == "") {
        stop(wrap_txt("[tileApply] no filepath found for image.
                      Please first write to disk."),
             call. = FALSE)
    }
    e <- .ext_to_num_vec(ext(x))

    with_pbar({
        p <- pbar(along = ti)

        lapply_flex(seq_along(ti), function(i) {
            ij <- .tile_idx_to_ij(ti, i)
            tile_id <- sprintf("[tile %d]", i)
            if (log) {
                vmsg(.v = "log", sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]), .log_path = logpath)
                vmsg(.v = "log", tile_id, "lyr:", toString(lyr), .log_path = logpath)
            }

            r <- .create_terra_spatraster(f)
            ext(r) <- e
            tile_ext <- ti[i][[1L]]

            if (log) {
                vmsg(.v = "log", tile_id, "extent:", .ext_to_num_vec(tile_ext), .log_path = logpath)
                vmsg(.v = "log", tile_id, "buffer:", ti@buffer, .log_path = logpath)
            }

            if (!is.null(lyr)) {
                r <- r[[lyr]]
            }
            terra::window(r) <- tile_ext

            if (".I" %in% names(formals(FUN))) {
                res <- FUN(r, .I = i)
            } else {
                res <- FUN(r)
            }

            p(message = sprintf("[tile %d] done", i))
            return(res)
        },
        ...)
    })
})

#' @rdname tileApply
#' @param extend whether to [terra::extend] data to fit expected tile dimensions
#' @param fill numeric. Value to use use for new raster cells if `extend = TRUE`
#' @export
setMethod("tileApply", signature("SpatRaster", "missing", "pixelTileIterator"), function(x, FUN, ti,
    lyr = NULL,
    extend = TRUE,
    fill = NA,
    cores = NA,
    future.seed = TRUE,
    log = FALSE,
    logpath = tempdir(),
    ...) {
    checkmate::assert_function(FUN)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    checkmate::assert_logical(extend)
    f <- terra::sources(x)
    f <- unique(f)
    if (any(f == "")) {
        stop(wrap_txt("[tileApply] no filepath found for image.
                      Please first write to disk."),
             call. = FALSE)
    }
    e <- .ext_to_num_vec(ext(x))

    with_pbar({
        p <- pbar(along = ti)

        lapply_flex(seq_along(ti), function(i) {
            ij <- .tile_idx_to_ij(ti, i)
            tile_id <- sprintf("[tile %d]", i)
            if (log) {
                vmsg(.v = "log", sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]), .log_path = logpath)
                vmsg(.v = "log", tile_id, "lyr:", toString(lyr), .log_path = logpath)
            }

            r <- .create_terra_spatraster(f)
            ext(r) <- e
            pxb <- ti[i][[1L]]

            if (log) {
                vmsg(.v = "log", tile_id, "px bounds:", pxb, .log_path = logpath)
                vmsg(.v = "log", tile_id, "buffer:", ti@buffer, .log_path = logpath)
            }

            if (!is.null(lyr)) { # layer selection
                r <- r[[lyr]]
            }
            # get px tile
            r <- r[pxb[[3]]:min(nrow(r), pxb[[4]]), # rows (y)
                   pxb[[1]]:min(ncol(r), pxb[[2]]), # cols (x)
                   drop = FALSE]

            # handle extend and masking
            pad <- 2 * ti@buffer # since buffer is added on both sides
            expected_dim <- c(ti@nrows + pad, ti@ncols + pad)
            if (nrow(r) != expected_dim[[1L]] ||
                ncol(r) != expected_dim[[2L]]) {
                if (extend) {
                    bottom_rows <- expected_dim[[1L]] - nrow(r)
                    right_cols <- expected_dim[[2L]] - ncol(r)
                    r <- terra::extend(r,
                        # left, right, bottom, top
                        c(0, right_cols, bottom_rows, 0),
                        fill = fill
                    )
                }
            }

            if (".I" %in% names(formals(FUN))) {
                res <- FUN(r, .I = i)
            } else {
                res <- FUN(r)
            }

            p(message = sprintf("[tile %d] done", i))
            return(res)
        },
        ...)
    })
})
