#' @include generics.R
#' @include tilePlan.R
#' @include pixelTilePlan.R
#' @include spatialTilePlan.R
#' @include tileGroup.R

# docs ####

# TODO dual input (y) methods
# TODO pad_y so x has full y context

#' @name tileApply
#' @title Apply Functions Across Spatial Tiles
#' @description
#' Apply a function across spatial tiles to speed up processing and manage
#' memory usage for large data operations. This function dispatches to
#' different processing methods based on the tile type.
#'
#' @section Tile Processing Methods:
#' - **Basic tiling**: See [tileApply-plan] for `spatialTilePlan` and `pixelTilePlan`
#' - **Group processing**: See [tileApply-group] for `tileGroup` hierarchical processing
#' - **Iterator processing**: See [tileApply-iterator] for `tileIterator` streaming/batch processing
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles tile object (`tilePlan`, `tileGroup`, or `tileIterator`)
#' @param FUN function to apply across tiles
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has full
#' spatial context of `y`
#' @param ... additional arguments passed to specific methods
#'
#' @seealso [tileApply-plan], [tileApply-group], [tileApply-iterator]
#' @examples
#' # See specific help pages for detailed examples:
#' # ?`tileApply-plan`     # Basic spatial/pixel tiling
#' # ?`tileApply-group`    # Hierarchical tile groups
#' # ?`tileApply-iterator` # Streaming batch processing
NULL

#' @name tileApply-plan
#' @title Basic Tile Processing
#' @description
#' Apply functions across `tilePlan`-inheriting objects.
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
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has full
#' spatial context of `y`
#' @param lyr numeric. Layer number(s) to use (optional)
#' @param future.seed logical. Enable reproducible random seeds
#' @param log logical. Whether to log processing steps
#' @param logpath character. Log file path (if log = `TRUE`)
#' @param extend logical. For `pixelTilePlan`, extend tiles to expected dimensions
#' @param fill numeric. Fill value when extending tiles
#' @param ... additional arguments passed to future.apply
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
#'   list(
#'     tile_id = .I,
#'     position = paste0("row_", .R, "_col_", .C),
#'     mean_value = terra::global(tile, "mean", na.rm = TRUE)[[1]]
#'   )
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
#'   filename <- file.path(outdir, sprintf("tile_%03d.tif", .I))
#'   terra::writeRaster(tile, filename, overwrite = TRUE)
#'   return(filename)
#' })
#'
#' list.files(outdir)
#' unlink(outdir, recursive = TRUE)
NULL

#' @name tileApply-group
#' @title Hierarchical Tile Group Processing
#' @description
#' Apply functions across tileGroup objects with control over parallelization
#' strategy. Useful when tiles are organized into logical groups that need
#' different processing or aggregation.
#'
#' @section Parallelization Strategies:
#' - `"groups"` - Process groups in parallel, tiles within groups sequentially
#' - `"tiles"` - Process groups sequentially, tiles within groups in parallel
#'
#' @section Special Function Parameters:
#' Your `FUN` can optionally include these special parameters:
#' - `.I` - tile number (integer)
#' - `.TILE` - tile bounds/metadata
#' - `.R` - tile row number
#' - `.C` - tile column number
#' - `.GROUP` - current group name (character)
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles `tileGroup` object
#' @param FUN function to apply to each tile
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has full
#' spatial context of `y`
#' @param parallel_strategy character. "groups" or "tiles"
#' @param group_FUN function. Optional function to apply to each group's results
#' @param lyr numeric. Layer number(s) to use (optional)
#' @param future.seed logical. Enable reproducible random seeds
#' @param log logical. Whether to log processing steps
#' @param logpath character. Log file path (if log = `TRUE`)
#' @param simplify logical. Whether to flatten group results into single list
#' @param ... additional arguments passed to future.apply
#'
#' @seealso [tileApply], [tileGroup()], [tileGroup-class]
#'
#' @examples
#' f <- system.file("ex/elev.tif", package = "terra")
#' r <- terra::rast(f)
#'
#' # Create tile plan
#' tp <- tilePlan("spatial")
#' ext(tp) <- ext(r)
#' length(tp) <- 16
#'
#' # Organize into groups (e.g., by geographic region)
#' tg <- tileGroup(tp, groups = list(
#'   "north" = 1:8,      # northern tiles
#'   "south" = 9:16,     # southern tiles
#'   "corners" = c(1, 4, 13, 16)  # corner tiles
#' ))
#'
#' # Process groups in parallel, with group-level aggregation
#' results <- tileApply(r, tiles = tg,
#'   parallel_strategy = "groups",
#'   FUN = function(tile, .I, .GROUP) {
#'     # Process individual tile
#'     list(
#'       tile_id = .I,
#'       group = .GROUP,
#'       stats = terra::global(tile, c("mean", "sd"), na.rm = TRUE)
#'     )
#'   },
#'   group_FUN = function(group_results, .GROUP) {
#'     # Aggregate results within each group
#'     means <- sapply(group_results, function(x) x$stats$mean)
#'     list(
#'       group = .GROUP,
#'       n_tiles = length(group_results),
#'       group_mean = mean(means),
#'       group_range = range(means)
#'     )
#'   }
#' )
#'
#' # Results organized by group
#' str(results)
NULL

#' @name tileApply-iterator
#' @title Streaming Tile Processing with Iterators
#' @description
#' Apply functions using tileIterator objects for memory-constrained batch
#' processing. Ideal for very large datasets or when you need fine control
#' over processing workflow.
#'
#' @section Worker Distribution:
#' The iterator automatically splits tiles across available workers, with each
#' worker processing its assigned tiles in batches.
#'
#' @section Special Function Parameters:
#' Your `FUN` can optionally include these special parameters:
#' - `.I` - tile number (integer)
#' - `.TILE` - tile bounds/metadata
#' - `.R` - tile row number
#' - `.C` - tile column number
#' - `.POSITION` - batch position range (start, end)
#' - `.BATCH` - batch number within worker
#' - `.WORKER_STATE` - the output of `setup_FUN`
#'
#' Your `setup_FUN` can optionally include these special parameters:
#' - `.W` - worker number
#' - `.X` - the input `x` object.
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles `tileIterator` object
#' @param FUN function to apply to each batch of tiles
#' @param setup_FUN function. Optional per-worker initialization function. Output
#' is accessible within `FUN` as `.WORKER_STATE`
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has full
#' spatial context of `y`
#' @param lyr numeric. Layer number(s) to use (optional)
#' @param future.seed logical. Enable reproducible random seeds
#' @param log logical. Whether to log processing steps
#' @param logpath character. Log file path (if log = `TRUE`)
#' @param simplify logical. Whether to flatten results
#' @param ... additional arguments
#'
#' @seealso [tileApply], [tileIterator()], [tileIterator-class]
#'
#' @examples
#' f <- system.file("ex/elev.tif", package = "terra")
#' r <- terra::rast(f)
#'
#' # Create pixel tile plan
#' tp <- tilePlan("pixel")
#' tp$pxdims <- dim(r)[1:2]
#' tp$nrows <- 30
#' tp$ncols <- 30
#'
#' # Create iterator for batch processing
#' iter <- tileIterator(tp, batch_size = 5)
#'
#' # Process with worker initialization
#' results <- tileApply(r, tiles = iter,
#'   setup_FUN = function(.W, .X) {
#'     # Initialize per-worker state
#'     list(
#'       worker_id = .W,
#'       start_time = Sys.time(),
#'       raster_info = list(nrow = nrow(.X), ncol = ncol(.X))
#'     )
#'   },
#'   FUN = function(batch, .BATCH, .POSITION, .WORKER_STATE) {
#'     # Process batch of tiles
#'     batch_stats <- lapply(batch, function(tile) {
#'       terra::global(tile, "mean", na.rm = TRUE)[[1]]
#'     })
#'
#'     list(
#'       worker = .WORKER_STATE$worker_id,
#'       batch_num = .BATCH,
#'       tiles_processed = .POSITION,
#'       batch_mean = mean(unlist(batch_stats))
#'     )
#'   }
#' )
#'
#' # Check results structure
#' str(results)
#'
#' # Example: Streaming processing for memory management
#' large_iter <- tileIterator(tp, batch_size = 3)
#' processed_count <- 0
#'
#' while (large_iter$has_next) {
#'   batch <- getTile(r, large_iter)
#'
#'   # Process batch
#'   batch_results <- lapply(batch, function(tile) {
#'     # Your processing here
#'     terra::global(tile, "mean")
#'   })
#'
#'   processed_count <- processed_count + length(batch)
#'   cat("Processed", processed_count, "of", length(tp), "tiles\n")
#' }
NULL

# methods ####

#' @rdname tileApply-plan
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
                vmsg(.v = "log", tile_id, "pad:", tiles@pad, .log_path = logpath)
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

#' @rdname tileApply-plan
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
                vmsg(.v = "log", tile_id, "pad:", tiles@pad, .log_path = logpath)
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

#' @rdname tileApply-group
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

#' @rdname tileApply-iterator
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

        tile <- getTile(r, tiles = tg[], i = tile_idx, ...) # returns as list

        # Prepare function arguments
        a <- list(tile[[1L]])
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
    results <- vector("list", length = length(blist))

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

        tile <- getTile(r, tiles = tg[], i = tile_idx, ...) # returns as list

        # Prepare function arguments
        a <- list(tile[[1L]])
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
