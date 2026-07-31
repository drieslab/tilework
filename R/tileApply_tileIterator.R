#' @include tileApply.R

#' @name tileApply-iterator
#' @title Streaming Tile Processing with Iterators
#' @family tile processing
#' @description
#' Apply functions using tileIterator objects for memory-constrained batch
#' processing. Ideal for very large datasets or when you need fine control
#' over processing workflow.
#'
#' **`token`** is a stand-in for any input data class (e.g. `SpatRaster`,
#' `SpatExtent`, filepath, etc). See [redispatch_tileapply]
#' and [extending_tilework] for further information.
#'
#' @section Worker Distribution:
#' [iterSplit()] is run with `n =` [future::nbrOfWorkers()] to distribute the
#' tiles to process across the expected number of workers, with each worker
#' processing its assigned tiles in batches.
#'
#' @section Special Function Parameters:
#' Your `FUN` can optionally include these special parameters:
#' - `.I` - tile number (integer)
#' - `.TILE` - tile bounds/metadata
#' - `.R` - tile row number
#' - `.C` - tile column number
#' - `.POSITION` - batch position range (start, end)
#' - `.BATCH` - batch number within worker
#' - `.SETUP_OUT` - the output of `setup_FUN`
#'
#' Your `setup_FUN` can optionally include these special parameters:
#' - `.W` - worker number
#' - `.X` - the input `x` object.
#' - `.Y` - the input `y` object (when provided)
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles `tileIterator` object
#' @param FUN function to apply to each batch of tiles
#' @param get_params_x named list. Additional params to pass to [getTile()] for
#'   `x`
#' @param get_params_y named list. Additional params to pass to [getTile()] for
#'   `y`
#' @param setup_FUN function. Optional per-worker initialization function. Output
#' is accessible within `FUN` as `.SETUP_OUT`
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has full
#' spatial context of `y`
#' @param log logical. Whether to log processing steps
#' @param logpath character. Log file path (if log = `TRUE`)
#' @param simplify logical. Whether to flatten results
#' @param parallel_params named param list. See [parallel_params]
#' @param verbose verbosity. `TRUE`, `FALSE` or `"debug"` for more info on
#'   stack tracing.
#' @param \dots additional params to pass to [`[`][bracket]
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
#' results <- tileApply(r,
#'     tiles = iter,
#'     setup_FUN = function(.W, .X) {
#'         # Initialize per-worker state
#'         list(
#'             worker_id = .W,
#'             start_time = Sys.time(),
#'             raster_info = list(nrow = nrow(.X), ncol = ncol(.X))
#'         )
#'     },
#'     FUN = function(batch, .BATCH, .POSITION, .SETUP_OUT) {
#'         # Process batch of tiles
#'         batch_stats <- lapply(batch, function(tile) {
#'             terra::global(tile, "mean", na.rm = TRUE)[[1]]
#'         })
#'
#'         list(
#'             worker = .SETUP_OUT$worker_id,
#'             batch_num = .BATCH,
#'             tiles_processed = .POSITION,
#'             batch_mean = mean(unlist(batch_stats))
#'         )
#'     }
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
#'     batch <- getTile(r, large_iter)
#'
#'     # Process batch
#'     batch_results <- lapply(batch, function(tile) {
#'         # Your processing here
#'         terra::global(tile, "mean")
#'     })
#'
#'     processed_count <- processed_count + length(batch)
#'     cat("Processed", processed_count, "of", length(tp), "tiles\n")
#' }
NULL

# core methods ####

#* token x ####

#' @rdname tileApply-iterator
#' @param callback_x function, (advanced). If provided, programmatic escape hatch for
#' preprocessing `x` per worker before `setup_FUN` and batch streamed processing
#' of `FUN` begins.
#' @export
setMethod(
    "tileApply", signature("token", "missing", "tileIterator"),
    function(
        x, tiles, FUN,
        get_params_x = list(),
        setup_FUN = NULL,
        callback_x = NULL,
        log = FALSE,
        logpath = getTileworkLogDir(),
        simplify = FALSE,
        parallel_params = list(),
        verbose = NULL,
        ...) {
        checkmate::assert_list(get_params_x)
        checkmate::assert_list(parallel_params)
        checkmate::assert_function(FUN)

        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        # Get number of workers from future plan
        n_workers <- future::nbrOfWorkers()

        # Split iterator across workers - each gets independent ranges
        worker_iters <- iterSplit(tiles, n = n_workers, distribute = TRUE)
        nsteps <- sum(ceiling(lengths(worker_iters) / tiles$batch_size))

        if (log) {
            jid <- getTileworkJobID(advance = TRUE)
            .vmsg(.v = verbose, "logging as job", jid)
        }

        progressr::with_progress({
            p <- progressr::progressor(steps = nsteps) # progress is batch based

            .future_fun <- function(worker_idx) {
                iter <- worker_iters[[worker_idx]]
                worker_id <- sprintf("[worker %d]", worker_idx)

                # logging ---- #
                if (log) {
                    conn <- .log_conn(log_dir = logpath, job_id = jid)
                    on.exit(close(conn), add = TRUE)
                    .log_write(conn, sprintf("%s start - %d tiles",
                        worker_id, iter$remaining))
                }
                # logging ---- #

                if (!is.null(callback_x)) {
                    x <- callback_x(x)
                }

                # worker setup steps (if needed)
                setup_out <- NULL
                if (!is.null(setup_FUN)) {
                    ws_a <- list()
                    nf_ws <- names(formals(setup_FUN))
                    if (".W" %in% nf_ws) ws_a$.W <- worker_idx
                    if (".X" %in% nf_ws) ws_a$.X <- x
                    setup_out <- do.call(setup_FUN, ws_a)
                }

                # setup get params
                gt_params_x <- c(list(x, iter), get_params_x, list(...))

                # collect results within worker
                res <- list()
                bid <- 0L
                while (iter$has_next) {
                    start_pos <- iter$position + 1L
                    bid <- bid + 1L
                    tilemeta <- iter$peek_batch() # get meta for this batch
                    batch <- do.call(getTile, gt_params_x) # pulls next batch and advances iter
                    batch_size <- length(batch)
                    end_pos <- iter$position
                    idx <- vapply(FUN.VALUE = integer(1L), tilemeta, attr, "tile")
                    .tiles <- iter
                    while (!inherits(.tiles, "tilePlan")) {
                        # get tilePLan
                        .tiles <- .tiles[]
                    }
                    ij <- .tile_idx_to_ij(.tiles, idx)

                    # logging ---- #
                    if (log) {
                        .log_write(conn,
                            sprintf("<worker %s> start batch %d: %d tiles",
                                worker_id, bid, batch_size))
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
                    if (".SETUP_OUT" %in% nf) a$.SETUP_OUT <- setup_out

                    # apply function
                    res[[bid]] <- do.call(FUN, args = a)

                    # logging ---- #
                    if (log) {
                        .log_write(conn,
                            sprintf("<worker %s> end batch %d: %d tiles",
                                worker_id, bid, batch_size))
                    }
                    # logging ---- #
                    # Update progress bar
                    p()
                }
                return(res)
            }

            parallel_params <- c(
                X = seq_along(worker_iters), # parallelize on number of worker iters
                FUN = .future_fun,
                parallel_params
            )

            results_list <- do.call(.par_lapply, parallel_params)

            # flatten results from workers into single list
            all_results <- unlist(results_list, recursive = FALSE)
            return(all_results)
        })
    }
)

#* token,token xy ####

#' @rdname tileApply-iterator
#' @param callback_y function, (advanced). If provided, programmatic escape hatch for
#' preprocessing `y` per worker before `setup_FUN` and batch streamed processing
#' of `FUN` begins.
#' @export
setMethod(
    "tileApply", signature("token", "token", "tileIterator"),
    function(
        x, y, tiles, FUN,
        get_params_x = list(),
        get_params_y = list(),
        pad_y = NULL,
        setup_FUN = NULL,
        callback_x = NULL,
        callback_y = NULL,
        log = FALSE,
        logpath = getTileworkLogDir(),
        simplify = FALSE,
        parallel_params = list(),
        verbose = NULL,
        ...) {
        checkmate::assert_list(get_params_x)
        checkmate::assert_list(get_params_y)
        checkmate::assert_list(parallel_params)
        checkmate::assert_function(FUN)

        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        # Get number of workers from future plan
        n_workers <- future::nbrOfWorkers()

        # Split iterator across workers - each gets independent ranges
        worker_iters <- iterSplit(tiles, n = n_workers, distribute = TRUE)
        nsteps <- sum(ceiling(lengths(worker_iters) / tiles$batch_size))

        if (log) {
            jid <- getTileworkJobID(advance = TRUE)
            .vmsg(.v = verbose, "logging as job", jid)
        }

        progressr::with_progress({
            p <- progressr::progressor(steps = nsteps) # progress is batch based

            .future_fun <- function(worker_idx) {
                iter <- worker_iters[[worker_idx]]
                worker_id <- sprintf("[worker %d]", worker_idx)

                # logging ---- #
                if (log) {
                    conn <- .log_conn(log_dir = logpath, job_id = jid)
                    on.exit(close(conn), add = TRUE)
                    .log_write(conn, sprintf("%s start - %d tiles",
                        worker_id, iter$remaining))
                }
                # logging ---- #

                if (!is.null(callback_x)) {
                    x <- callback_x(x)
                }
                if (!is.null(callback_y)) {
                    y <- callback_y(y)
                }

                # worker setup steps (if needed)
                setup_out <- NULL
                if (!is.null(setup_FUN)) {
                    ws_a <- list()
                    nf_ws <- names(formals(setup_FUN))
                    if (".W" %in% nf_ws) ws_a$.W <- worker_idx
                    if (".X" %in% nf_ws) ws_a$.X <- x
                    if (".Y" %in% nf_ws) ws_a$.Y <- y
                    setup_out <- do.call(setup_FUN, ws_a)
                }

                # setup get params (use tiles[] to use unified indices for extraction)
                gt_params_x <- c(list(x, tiles[]), get_params_x, list(...))
                gt_params_y <- c(list(y, tiles[], pad = pad_y), get_params_y, list(...))

                # collect results within worker
                res <- list()
                bid <- 0L
                while (iter$has_next) {
                    start_pos <- iter$position + 1L
                    bid <- bid + 1L
                    tilemeta <- iter$peek_batch() # get meta for this batch
                    indices <- iter$next_indices(advance = TRUE)
                    gt_params_x$i <- indices
                    gt_params_y$i <- indices
                    batch_x <- do.call(getTile, gt_params_x)
                    batch_y <- do.call(getTile, gt_params_y)
                    batch_size <- length(batch_x)
                    end_pos <- iter$position
                    idx <- vapply(FUN.VALUE = integer(1L), tilemeta, attr, "tile")
                    .tiles <- iter
                    while (!inherits(.tiles, "tilePlan")) {
                        # get tilePLan
                        .tiles <- .tiles[]
                    }
                    ij <- .tile_idx_to_ij(.tiles, idx)

                    # logging ---- #
                    if (log) {
                        .log_write(conn,
                            sprintf("<worker %s> start batch %d: %d tiles",
                                worker_id, bid, batch_size))
                    }
                    # logging ---- #

                    # special args
                    a <- list(batch_x, batch_y)
                    nf <- names(formals(FUN))
                    if (".I" %in% nf) a$.I <- idx
                    if (".R" %in% nf) a$.R <- ij[[1L]]
                    if (".C" %in% nf) a$.C <- ij[[2L]]
                    if (".TILE" %in% nf) a$.TILE <- tilemeta
                    if (".POSITION" %in% nf) a$.POSITION <- c(start_pos, end_pos)
                    if (".BATCH" %in% nf) a$.BATCH <- bid
                    if (".SETUP_OUT" %in% nf) a$.SETUP_OUT <- setup_out

                    # apply function
                    res[[bid]] <- do.call(FUN, args = a)

                    # logging ---- #
                    if (log) {
                        .log_write(conn,
                            sprintf("<worker %s> end batch %d: %d tiles",
                                worker_id, bid, batch_size))
                    }
                    # logging ---- #
                    # Update progress bar
                    p()
                }
                return(res)
            }

            parallel_params <- c(
                X = seq_along(worker_iters), # parallelize on number of worker iters
                FUN = .future_fun,
                parallel_params
            )

            results_list <- do.call(.par_lapply, parallel_params)

            # flatten results from workers into single list
            all_results <- unlist(results_list, recursive = FALSE)
            return(all_results)
        })
    }
)

# specific methods ####

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("character", "tileIterator"),
    function(sig, tiles, ...) {
        sig <- .handle_warnings(.terra_read(sig))$result
        redispatch_tileapply(sig, tiles, ...)
    }
)

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("SpatRaster", "tileIterator"), function(sig, tiles, param_xy, ...) {
    param_xy <- match.arg(param_xy, c("x", "y"))
    f <- terra::sources(sig)
    f <- unique(f)
    .guard_disk_terra_raster(f)
    e <- .ext_to_num_vec(ext(sig))

    lyr <- NULL # default
    dots <- list(...)
    if (param_xy == "x") {
        lyr <- dots$get_params_x$lyr %||% lyr
    } else {
        lyr <- dots$get_params_y$lyr %||% lyr
    }

    callNextMethod(f, tiles,
        default_callback = function(x) {
            r <- .terra_read(x[], prefer = "raster") # unwrap and read SpatRaster
            ext(r) <- e
            if (!is.null(lyr)) {
                r <- r[[lyr]] # layer selection
            }
            r
        },
        param_xy = param_xy,
        ...
    )
})

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("SpatVector", "tileIterator"), function(sig, tiles, ...) {
    f <- terra::sources(sig)
    f <- unique(f)
    .guard_disk_terra_vector(f)

    callNextMethod(f, tiles,
        default_callback = function(x) {
            .terra_read(x[], prefer = "vector") # unwrap and read svp
        },
        ...
    )
})

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("ANY", "tileIterator"), function(
        sig, tiles,
        default_get_params = list(),
        default_callback = NULL,
        param_xy,
        verbose = NULL,
        ...) {
    checkmate::assert_list(default_get_params)
    param_xy <- match.arg(param_xy, c("x", "y"))
    .dmsg(.v = verbose, "[redispatch] step done. Route as", param_xy, "...")
    # default is no change
    sig <- as(sig, "token")
    # args list
    a <- list(tiles = tiles, verbose = verbose, ...)

    .dmsg(.v = verbose, .initial = "  ", plist = list(...))

    if (param_xy == "x") {
        a$get_params_x <- c(a$get_params_x, default_get_params)
        ns <- names(a$get_params_x)
        a$get_params_x <- a$get_params_x[!duplicated(ns)]
        a$callback_x <- a$callback_x %||% default_callback
        do.call(tileApply, c(list(x = sig), a))
    } else {
        a$get_params_y <- c(a$get_params_y, default_get_params)
        ns <- names(a$get_params_y)
        a$get_params_y <- a$get_params_y[!duplicated(ns)]
        a$callback_y <- a$callback_y %||% default_callback
        do.call(tileApply, c(list(y = sig), a))
    }
})
