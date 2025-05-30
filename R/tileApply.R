#' @include generics.R
#' @include tileIterator.R
#' @include pixelTileIterator.R
#' @include spatialTileIterator.R
#' @include tileGroup.R

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
#' `SpatRaster` object. Additional special parameters can be optionally included.
#'
#' * `.I` can be used as the tile number.
#' * `.TILE` is the tileIterator output for that `.I`. It will include the
#' bounds and attached metdata attributes.
#' * `.R` is the tile row number
#' * `.C` is the tile col number.
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
#' r <- terra::rast(f)
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
    future.seed = TRUE,
    log = FALSE,
    logpath = tempdir(),
    ...) {
    checkmate::assert_function(FUN)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
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
            tile_ext <- ti[i][[1L]]

            if (log) {
                vmsg(.v = "log", tile_id, "extent:", .ext_to_num_vec(tile_ext), .log_path = logpath)
                vmsg(.v = "log", tile_id, "buffer:", ti@buffer, .log_path = logpath)
            }

            if (!is.null(lyr)) {
                r <- r[[lyr]]
            }
            terra::window(r) <- tile_ext

            # special args
            a <- list(r)
            nf <- names(formals(FUN))
            if (".I" %in% nf) a$.I <- i
            if (".TILE" %in% nf) a$.TILE <- tile_ext
            if (".R" %in% nf) a$.R <- ij[[1L]]
            if (".C" %in% nf) a$.C <- ij[[2L]]

            res <- do.call(FUN, args = a)

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
    future.seed = TRUE,
    log = FALSE,
    logpath = tempdir(),
    ...) { # TODO ensure this is only for other tileApply functionality, not future. make that a separate param list.
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
            r <- .px_get_tile(
                x = r, ti = ti, b = pxb, extend = extend, fill = fill
            )

            # special args
            a <- list(r)
            nf <- names(formals(FUN))
            if (".I" %in% nf) a$.I <- i
            if (".TILE" %in% nf) a$.TILE <- pxb
            if (".R" %in% nf) a$.R <- ij[[1L]]
            if (".C" %in% nf) a$.C <- ij[[2L]]

            res <- do.call(FUN, args = a)

            p(message = sprintf("[tile %d] done", i))
            return(res)
        },
        ...) # ti, logpath, log, f, e
    })
})

#' @rdname tileApply
#' @param parallel_strategy character. `"groups"` to parallelize across groups,
#'   `"tiles"` to parallelize within groups
#' @param group_FUN function. Optional function to apply to each group's results
#' @param group_sequential logical. If TRUE, process groups sequentially
setMethod("tileApply", signature("SpatRaster", "missing", "tileGroup"),
    function(x, FUN, ti,
    parallel_strategy = c("groups", "tiles"),
    group_FUN = NULL,
    lyr = NULL,
    future.seed = TRUE,
    log = FALSE,
    logpath = tempdir(),
    simplify = FALSE,
    ...) {
    parallel_strategy <- match.arg(parallel_strategy, choices = c("groups", "tiles"))
    checkmate::assert_function(FUN)
    checkmate::assert_function(group_FUN, null.ok = TRUE)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    # validate file source
    f <- terra::sources(x)
    if (any(f == "")) {
        stop(wrap_txt("[tileApply] no filepath found for image.
                      Please first write to disk."),
             call. = FALSE)
    }
    if (!is.null(lyr)) f <- f[lyr] # subset layers by source
    e <- .ext_to_num_vec(ext(x))

    switch(parallel_strategy,
        "groups" = .tapp_par_groups(
            tg = ti,
            FUN = FUN,
            group_FUN = group_FUN,
            f = f,
            e = e,
            future.seed = future.seed,
            log = log,
            logpath = logpath,
            simplify = simplify,
            ...
        ),
        "tiles" = .tapp_seq_groups(
            tg = ti,
            FUN = FUN,
            group_FUN = group_FUN,
            f = f,
            e = e,
            future.seed = future.seed,
            log = log,
            logpath = logpath,
            simplify = simplify,
            ...
        )
    )
})


# helpers ####

# par groups / seq tiles
.tapp_par_groups <- function(tg, FUN, group_FUN, f, e, future.seed, log, logpath, simplify = FALSE, ...) {
    ngroups <- length(tg)
    with_pbar({
        p <- pbar(steps = ngroups)
        group_results <- lapply_flex(names(tg), function(group) {
            # logging ---- #
            if (log) {
                vmsg(.v = "log", sprintf("[group %s] start", group),
                     .log_path = logpath)
            }
            # logging ---- #
            gres <- .process_seq_tile(tg, group, FUN, f, e, log, logpath, ...)

            # Apply group function if provided
            if (!is.null(group_FUN)) {
                a <- list(gres)
                nf <- names(formals(group_FUN))
                if (".GROUP" %in% nf) a$.GROUP <- group
                gres <- do.call(group_FUN, args = a)
            }

            # logging ---- #
            if (log) {
                vmsg(.v = "log", sprintf("[group %s] done", group),
                     .log_path = logpath)
            }
            # logging ---- #

            p(message = sprintf("[group %s] done", group))
            return(gres)
        }, future.seed = future.seed)

        if (simplify) {
            unlist(group_results, recursive = FALSE)
        } else {
            names(group_results) <- names(tg)
        }

        group_results
    })
}

# seq groups / par tiles
.tapp_seq_groups <- function(tg, FUN, group_FUN, f, e, future.seed, log, logpath, simplify = FALSE, ...) {
    ngroups <- length(tg)
    group_results <- vector("list", length = ngroups)
    names(group_results) <- names(tg)

    with_pbar({
        p <- pbar(steps = ngroups)

        for (group in names(tg)) {
            # logging ---- #
            if (log) {
                vmsg(.v = "log", sprintf("[group %s] start", group),
                     .log_path = logpath)
            }
            # logging ---- #

            gres <- .process_par_tile(tg, group, FUN, f, e, log, logpath, ...)

            # Apply group function if provided
            if (!is.null(group_FUN)) {
                a <- list(gres)
                nf <- names(formals(group_FUN))
                if (".GROUP" %in% nf) a$.GROUP <- group
                gres <- do.call(group_FUN, args = a)
            }
            group_results[[group]] <- gres # append

            # logging ---- #
            if (log) {
                vmsg(.v = "log", sprintf("[group %s] done", group),
                     .log_path = logpath)
            }
            # logging ---- #

            p(message = sprintf("[group %s] done", group))
        }

        if (simplify) {
            unlist(group_results, recursive = FALSE)
        }
        return(group_results)
    })
}

.process_par_tile <- function(tg, group, FUN, f, e, log, logpath, ...) {
    blist <- tg[group]
    lapply_flex(seq_along(blist), function(idx_pos) {
        b <- blist[[idx_pos]]
        # connect raster and add ext
        r <- .create_terra_spatraster(f)
        ext(r) <- e

        tile_idx <- attr(b, "tile")
        ij <- .tile_idx_to_ij(tg[], tile_idx)
        tile_id <- sprintf("[group %s][tile %d]", group, tile_idx)

        # logging ---- #
        if (log) {
            vmsg(.v = "log", sprintf("%s start (row %d, col %d)",
                                     tile_id, ij[[1]], ij[[2]]),
                 .log_path = logpath)
        }
        # logging ---- #

        tile <- getTile(r, ti = tg[], i = tile_idx, ...)

        # Prepare function arguments
        a <- list(tile)
        nf <- names(formals(FUN))
        if (".I" %in% nf) a$.I <- tile_idx
        if (".TILE" %in% nf) a$.TILE <- b
        if (".R" %in% nf) a$.R <- ij[[1L]]
        if (".C" %in% nf) a$.C <- ij[[2L]]
        if (".GROUP" %in% nf) a$.GROUP <- group

        # Apply function
        results <- do.call(FUN, args = a)

        # logging ---- #
        if (log) {
            vmsg(.v = "log", sprintf("%s done", tile_id), .log_path = logpath)
        }
        # logging ---- #
        return(results)
    }, future.seed = future.seed)
}

# group: group index (character name)
.process_seq_tile <- function(tg, group, FUN, f, e, log, logpath, ...) {
    # connect raster and add ext
    r <- .create_terra_spatraster(f)
    ext(r) <- e

    blist <- tg[group]
    results <- vector("list", length = blist)

    for (idx_pos in seq_along(blist)) {
        b <- blist[[idx_pos]]
        tile_idx <- attr(b, "tile")
        ij <- .tile_idx_to_ij(tg[], tile_idx)

        # logging ---- #
        tile_id <- sprintf("[group %s][tile %d]", group, tile_idx)
        if (log) {
            vmsg(.v = "log", sprintf("%s start (row %d, col %d)",
                                     tile_id, ij[[1L]], ij[[2L]]),
                 .log_path = logpath)
        }
        # logging ---- #

        tile <- getTile(r, ti = tg[], i = tile_idx, ...)

        # Prepare function arguments
        a <- list(tile)
        nf <- names(formals(FUN))
        if (".I" %in% nf) a$.I <- tile_idx
        if (".TILE" %in% nf) a$.TILE <- b
        if (".R" %in% nf) a$.R <- ij[[1L]]
        if (".C" %in% nf) a$.C <- ij[[2L]]
        if (".GROUP" %in% nf) a$.GROUP <- group

        # Apply function
        results[[idx_pos]] <- do.call(FUN, args = a)

        # logging ---- #
        if (log) {
            vmsg(.v = "log", sprintf("%s done", tile_id), .log_path = logpath)
        }
        # logging ---- #
    }
    results
}
