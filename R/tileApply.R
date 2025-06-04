#' @include generics.R
#' @include tilePlan.R
#' @include pixelTilePlan.R
#' @include spatialTilePlan.R
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
#' * `.TILE` is the tilePlan output for that `.I`. It will include the
#' bounds and attached metdata attributes.
#' * `.R` is the tile row number
#' * `.C` is the tile col number.
#' @param tiles `tile*` object that defines the tiles to apply on.
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
#' tp <- tilePlan()
#' ext(tp) <- ext(r)
#' length(tp) <- 4
#'
#' outdir <- file.path(tempdir(), "testwrite")
#' dir.create(outdir)
#'
#' tileApply(r, tiles = tp, lyr = 1, FUN = function(x, .I) {
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
setMethod("tileApply", signature("SpatRaster", "missing", "spatialTilePlan"), function(x, FUN, tiles,
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
        p <- pbar(along = tiles)

        lapply_flex(seq_along(tiles), function(i) {
            ij <- .tile_idx_to_ij(tiles, i)
            tile_id <- sprintf("[tile %d]", i)
            if (log) {
                vmsg(.v = "log", sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]), .log_path = logpath)
                vmsg(.v = "log", tile_id, "lyr:", toString(lyr), .log_path = logpath)
            }

            r <- .create_terra_spatraster(f)
            ext(r) <- e
            tile_ext <- tiles[i][[1L]]

            if (log) {
                vmsg(.v = "log", tile_id, "extent:", .ext_to_num_vec(tile_ext), .log_path = logpath)
                vmsg(.v = "log", tile_id, "buffer:", tiles@buffer, .log_path = logpath)
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
setMethod("tileApply", signature("SpatRaster", "missing", "pixelTilePlan"), function(x, FUN, tiles,
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
        p <- pbar(along = tiles)

        lapply_flex(seq_along(tiles), function(i) {
            ij <- .tile_idx_to_ij(tiles, i)
            tile_id <- sprintf("[tile %d]", i)
            if (log) {
                vmsg(.v = "log", sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]), .log_path = logpath)
                vmsg(.v = "log", tile_id, "lyr:", toString(lyr), .log_path = logpath)
            }

            r <- .create_terra_spatraster(f)
            ext(r) <- e
            pxb <- tiles[i][[1L]]

            if (log) {
                vmsg(.v = "log", tile_id, "px bounds:", pxb, .log_path = logpath)
                vmsg(.v = "log", tile_id, "buffer:", tiles@buffer, .log_path = logpath)
            }

            if (!is.null(lyr)) { # layer selection
                r <- r[[lyr]]
            }
            # get px tile
            r <- .px_get_tile(
                x = r, tiles = tiles, b = pxb, extend = extend, fill = fill
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
        ...) # tiles, logpath, log, f, e
    })
})

#' @rdname tileApply
#' @param parallel_strategy character. `"groups"` to parallelize across groups,
#'   `"tiles"` to parallelize within groups
#' @param group_FUN function. Optional function to apply to each group's results
#' @param group_sequential logical. If TRUE, process groups sequentially
setMethod("tileApply", signature("SpatRaster", "missing", "tileGroup"),
    function(x, FUN, tiles,
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
            tg = tiles,
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
            tg = tiles,
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

#' @rdname tileApply
#' @export
setMethod("tileApply", signature("SpatRaster", "missing", "tileIterator"),
    function(x, FUN, tiles,
    setup_FUN = NULL,
    lyr = NULL,
    future.seed = TRUE,
    log = FALSE,
    logpath = tempdir(),
    simplify = FALSE,
    ...) {
    checkmate::assert_function(FUN)
    checkmate::assert_integerish(lyr, null.ok = TRUE)

    # validate file source
    f <- terra::sources(x)
    if (any(f == "")) {
        stop(wrap_txt("[tileApply] no filepath found for image.
                  Please first write to disk."),
             call. = FALSE)
    }
    e <- .ext_to_num_vec(ext(x))

    # Get number of workers from future plan
    n_workers <- future::nbrOfWorkers()

    # Split iterator across workers - each gets independent ranges
    worker_iters <- iterSplit(tiles, n = n_workers, distribute = TRUE)
    nsteps <- sum(ceiling(lengths(worker_iters) / tiles$batch_size))

    with_pbar({
        p <- pbar(steps = nsteps) # progress is batch based
        results_list <- lapply_flex(seq_along(worker_iters), function(worker_idx) {
            iter <- worker_iters[[worker_idx]]
            worker_id <- sprintf("[worker %d]", worker_idx)

            # logging ---- #
            if (log) {
                vmsg(.v = "log", sprintf("%s start - %d tiles", worker_id, iter$remaining),
                     .log_path = logpath)
            }
            # logging ---- #

            # Connect to raster
            r <- .create_terra_spatraster(f)
            ext(r) <- e
            if (!is.null(lyr)) {
                r <- r[[lyr]] # layer selection
            }

            # worker setup steps (if needed)
            worker_state <- NULL
            if (!is.null(setup_FUN)) {
                ws_a <- list()
                nf_ws <- names(formals(setup_FUN))
                if (".W" %in% nf_ws) ws_a$.W <- worker_idx
                if (".X" %in% nf_ws) ws_a$.X <- r
                worker_state <- do.call(setup_FUN, ws_a)
            }

            # collect results within worker
            res <- list()
            bid <- 0L
            while (iter$has_next) {
                start_pos <- iter$position + 1L
                bid <- bid + 1L
                tilemeta <- iter$peek_batch() # get meta for this batch
                batch <- getTile(r, iter, ...) # pulls next batch and advances iter
                batch_size <- length(batch)
                end_pos <- iter$position
                idx <- vapply(FUN.VALUE = integer(1L), tilemeta, attr, "tile")
                .tiles <- iter
                while(!inherits(.tiles, "tilePlan")) {
                    # get tilePLan
                    .tiles <- .tiles[]
                }
                ij <- .tile_idx_to_ij(.tiles, idx)

                # logging ---- #
                if (log) {
                    vmsg(.v = "log", sprintf("<worker %s> start batch %d: %d tiles", worker_id, bid, batch_size), .log_path = logpath)
                }
                # logging ---- #

                # special args
                a <- list(batch)
                nf <- names(formals(FUN))
                if (".I" %in% nf) a$.I <- idx
                if (".R" %in% nf) a$.R <- ij[[1L]]
                if (".C" %in% nf) a$.C <- ij[[2L]]
                if (".TILE" %in% nf) a$.TILE <- tilemeta
                if (".POSITION" %in% nf) a$.POSITION <- c(start_pos, end_pos)
                if (".BATCH" %in% nf) a$.BATCH <- bid
                if (".WORKER_STATE" %in% nf) a$.WORKER_STATE <- worker_state

                # apply function
                res[[bid]] <- do.call(FUN, args = a)

                # logging ---- #
                if (log) {
                    vmsg(.v = "log", sprintf("<worker %s> end batch %d: %d tiles", worker_id, bid, batch_size), .log_path = logpath)
                }
                # logging ---- #
                # Update progress bar
                p()
            }
            return(res)
        }, future.seed = future.seed)

        # flatten results from workers into single list
        all_results <- unlist(results_list, recursive = FALSE)
        return(all_results)
    })
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

        tile <- getTile(r, tiles = tg[], i = tile_idx, ...)

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

        tile <- getTile(r, tiles = tg[], i = tile_idx, ...)

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
