#' @include tileApply.R

#' @name tileApply-group
#' @title Hierarchical Tile Group Processing
#' @description
#' Apply functions across tileGroup objects with control over parallelization
#' strategy. Useful when tiles are organized into logical groups that need
#' different processing or aggregation.
#'
#' **`token`** is a stand-in for any input data class (e.g. `SpatRaster`,
#' `SpatExtent`, filpath, etc). See [redispatch_tileapply]
#' and [extending_tilework] for further information.
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
#' - `.SETUP_OUT` - the output of `setup_FUN`
#'
#' Your `setup_FUN` can optionally include these special parameters:
#' - `.GROUP` - current group name (character)
#' - `.X` - the input `x` object
#' - `.Y` - the input `y` object (when provided)
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles `tileGroup` object
#' @param FUN function to apply to each tile
#' @param get_params_x named list. Additional params to pass to [getTile()] for
#'   `x`
#' @param get_params_y named list. Additional params to pass to [getTile()] for
#'   `y`
#' @param pad_y numeric. Additional padding applied to `y` tiling so `x` has
#'   full spatial context of `y`
#' @param parallel_strategy character. `"groups"` to parallelize across groups,
#'   or `"tiles"` to parallelize within groups
#' @param setup_FUN function. Optional per-group initialization function when
#'   `parallel_strategy = "groups"`. Output is accessible within `FUN` as
#'   `.SETUP_OUT`
#' @param callback_x function. Optional preprocessing function for `x` per
#'   worker when `parallel_strategy = "groups"`
#' @param callback_y function. Optional preprocessing function for `y` per
#'   worker when `parallel_strategy = "groups"`
#' @param group_FUN function. Optional function to apply to each group's results
#' @param log logical. Whether to log processing steps
#' @param logpath character. Log file path (if log = `TRUE`)
#' @param simplify logical. Whether to flatten group results into single list.
#'   Group names will not be retained.
#' @param parallel_params named param list. See [parallel_params]
#' @param verbose verbosity. `TRUE`, `FALSE` or `"debug"` for more info on
#'   stack tracing.
#' @param \dots additional params to pass to [`[`][bracket]
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
#'     "north" = 1:8, # northern tiles
#'     "south" = 9:16, # southern tiles
#'     "corners" = c(1, 4, 13, 16) # corner tiles
#' ))
#'
#' # Process groups in parallel, with group-level aggregation
#' results <- tileApply(r,
#'     tiles = tg,
#'     parallel_strategy = "groups",
#'     FUN = function(tile, .I, .GROUP) {
#'         # Process individual tile
#'         list(
#'             tile_id = .I,
#'             group = .GROUP,
#'             stats = terra::global(tile, c("mean", "sd"), na.rm = TRUE)
#'         )
#'     },
#'     group_FUN = function(group_results, .GROUP) {
#'         # Aggregate results within each group
#'         means <- sapply(group_results, function(x) x$stats$mean)
#'         list(
#'             group = .GROUP,
#'             n_tiles = length(group_results),
#'             group_mean = mean(means),
#'             group_range = range(means)
#'         )
#'     }
#' )
#'
#' # Results organized by group
#' str(results)
NULL

# methods ####

#* token x ####

#' @rdname tileApply-group
#' @export
setMethod(
    "tileApply", signature("token", "missing", "tileGroup"),
    function(
        x, tiles, FUN,
        get_params_x = list(),
        parallel_strategy = c("groups", "tiles"),
        setup_FUN = NULL,
        group_FUN = NULL,
        callback_x = NULL,
        log = FALSE,
        logpath = getTileworkLogDir(),
        simplify = FALSE,
        parallel_params = list(),
        verbose = NULL,
        ...) {
        parallel_strategy <- match.arg(parallel_strategy, choices = c("groups", "tiles"))
        checkmate::assert_list(get_params_x)
        checkmate::assert_list(parallel_params)
        checkmate::assert_function(FUN)
        checkmate::assert_function(group_FUN, null.ok = TRUE)

        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        a <- .get_args_list(...) # get all args
        # remove args not used downstream
        a$parallel_strategy <- NULL
        if (parallel_strategy == "tiles") {
            a$setup_FUN <- NULL
            a$callback_x <- NULL
        }

        switch(parallel_strategy,
            "groups" = do.call(.tapp_par_groups, a),
            "tiles" = do.call(.tapp_seq_groups, a)
        )
    }
)

#* token,token xy ####

#' @rdname tileApply-group
#' @export
setMethod(
    "tileApply", signature("token", "token", "tileGroup"),
    function(
        x, y, tiles, FUN,
        get_params_x = list(),
        get_params_y = list(),
        pad_y = NULL,
        parallel_strategy = c("groups", "tiles"),
        setup_FUN = NULL,
        group_FUN = NULL,
        callback_x = NULL,
        callback_y = NULL,
        log = FALSE,
        logpath = getTileworkLogDir(),
        simplify = FALSE,
        parallel_params = list(),
        verbose = NULL,
        ...) {
        parallel_strategy <- match.arg(parallel_strategy, choices = c("groups", "tiles"))
        checkmate::assert_list(get_params_x)
        checkmate::assert_list(get_params_y)
        checkmate::assert_list(parallel_params)
        checkmate::assert_function(FUN)
        checkmate::assert_function(group_FUN, null.ok = TRUE)

        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        a <- .get_args_list(...) # get all args
        # remove args not used downstream
        a$parallel_strategy <- NULL
        if (parallel_strategy == "tiles") {
            a$setup_FUN <- NULL
            a$callback_x <- NULL
        }

        switch(parallel_strategy,
            "groups" = do.call(.tapp_par_groups, a),
            "tiles" = do.call(.tapp_seq_groups, a)
        )
    }
)

# specific methods ####

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("character", "tileGroup"),
    function(sig, tiles, ...) {
        sig <- .handle_warnings(.terra_read(sig))$result
        redispatch_tileapply(sig, tiles, ...)
    }
)

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("SpatVector", "tileGroup"),
    function(sig, tiles, parallel_strategy = c("groups", "tiles"), ...) {
        parallel_strategy <- match.arg(parallel_strategy, c("groups", "tiles"))
        f <- terra::sources(sig)
        f <- unique(f)
        .guard_disk_terra_vector(f)

        a <- list(f, tiles, ...)
        if (parallel_strategy == "tiles") { # tiles par only
            a$default_get_params <- list(
                prefer = "vector" # to getTile,character
            )
        } else { # groups par only
            a$default_callback <- function(x) {
                .terra_read(x[], prefer = "vector") # unwrap and read svp
            }
        }

        do.call(callNextMethod, a)
    }
)

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("SpatRaster", "tileGroup"),
    function(
        sig, tiles, param_xy,
        parallel_strategy = c("groups", "tiles"),
        ...) {
        param_xy <- match.arg(param_xy, c("x", "y"))
        parallel_strategy <- match.arg(parallel_strategy, c("groups", "tiles"))
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

        a <- list(f, tiles, param_xy = param_xy, ...)
        if (parallel_strategy == "tiles") { # tiles par only
            a$default_get_params <- list(
                lyr = lyr, # to getTile,SpatRaster
                prefer = "raster", # to getTile,character
                ext = e # to getTile,character
            )
        } else { # groups par only
            a$default_callback <- function(x) {
                r <- .terra_read(x[], prefer = "raster") # unwrap and read SpatRaster
                ext(r) <- e
                if (!is.null(lyr)) {
                    r <- r[[lyr]] # layer selection
                }
                r
            }
        }

        do.call(callNextMethod, a)
    }
)

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("ANY", "tileGroup"), function(
        sig, tiles,
        default_get_params = list(),
        default_callback = NULL,
        param_xy,
        parallel_strategy = c("groups", "tiles"),
        verbose = NULL,
        ...) {
    dots <- list(...)
    # to redispatch_tileapply (ANY,ANY) method when callback_* handling is not needed
    parallel_strategy <- match.arg(parallel_strategy, c("groups", "tiles"))
    if (parallel_strategy == "tiles") {
        callNextMethod(sig, tiles,
            default_get_params = default_get_params,
            param_xy = param_xy,
            verbose = verbose,
            ...
        )
    }

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

# helpers ####

# par groups / seq tiles
.tapp_par_groups <- function(
        x, y = NULL, tiles,
        setup_FUN = NULL,
        group_FUN = NULL,
        callback_x = NULL,
        callback_y = NULL,
        parallel_params,
        log,
        logpath,
        simplify = FALSE,
        verbose = NULL,
        ...) {
    ngroups <- length(tiles)
    if (log) {
        jid <- getTileworkJobID(advance = TRUE)
        .vmsg(.v = verbose, "logging as job", jid)
    }
    progressr::with_progress({
        p <- progressr::progressor(steps = ngroups)

        .future_fun <- function(group) {
            # logging ---- #
            conn <- NULL
            if (log) {
                conn <- .log_conn(log_dir = logpath, job_id = jid)
                on.exit(close(conn), add = TRUE)
                .log_write(conn, sprintf("[group %s] start", group))
            }
            # logging ---- #

            if (!is.null(callback_x)) {
                x <- callback_x(x)
            }
            if (!is.null(y) && !is.null(callback_y)) {
                y <- callback_y(y)
            }

            # worker setup steps (if needed)
            setup_out <- NULL
            if (!is.null(setup_FUN)) {
                ws_a <- list()
                nf_ws <- names(formals(setup_FUN))
                if (".GROUP" %in% nf_ws) ws_a$.GROUP <- group
                if (".X" %in% nf_ws) ws_a$.X <- x
                if (".Y" %in% nf_ws && !is.null(y)) ws_a$.Y <- y
                setup_out <- do.call(setup_FUN, ws_a)
            }

            pst_args <- list(
                x = x, y = y,
                tiles = tiles,
                group = group,
                setup_out = setup_out,
                log = log,
                logconn = conn,
                ...
            )
            gres <- do.call(.process_seq_tile, pst_args)

            # Apply group function if provided
            if (!is.null(group_FUN)) {
                a <- list(gres)
                nf <- names(formals(group_FUN))
                if (".GROUP" %in% nf) a$.GROUP <- group
                gres <- do.call(group_FUN, args = a)
            }

            # logging ---- #
            if (log) .log_write(conn, sprintf("[group %s] done", group))
            # logging ---- #

            p(message = sprintf("[group %s] done", group))
            return(gres)
        }

        parallel_params <- c(
            X = list(names(tiles)),
            FUN = .future_fun,
            parallel_params
        )

        group_results <- do.call(.par_lapply, parallel_params)

        if (simplify) {
            group_results <- unlist(group_results,
                recursive = FALSE, use.names = FALSE
            )
        } else {
            names(group_results) <- names(tiles)
        }

        group_results
    })
}

# seq groups / par tiles
.tapp_seq_groups <- function(
        tiles,
        group_FUN,
        parallel_params,
        log,
        logpath,
        simplify = FALSE,
        verbose = NULL,
        ...) {
    ngroups <- length(tiles)
    # allocate group results list
    group_results <- vector("list", length = ngroups)
    names(group_results) <- names(tiles)

    if (log) {
        jid <- getTileworkJobID(advance = TRUE)
        .vmsg(.v = verbose, "logging as job", jid)
        # make master directory for individual group jobs
        logpath <- file.path(logpath, jid)
        conn <- .log_conn(log_dir = logpath, job_id = jid)
        on.exit(close(conn), add = TRUE)
    }

    progressr::with_progress({
        p <- progressr::progressor(steps = ngroups)

        for (group in names(tiles)) {
            # logging ---- #
            if (log) {
                .log_write(conn, sprintf("[group %s] start", group))
                sjid <- getTileworkJobID(advance = TRUE)
                .vmsg(.v = verbose,
                      sprintf("[group %s] logging as sub-job %s", group, sjid))
            }

            # logging ---- #

            gres <- .process_par_tile(
                tiles = tiles, group = group, log = log, logpath = logpath,
                parallel_params = parallel_params, jid = sjid, ...
            )

            # Apply group function if provided
            if (!is.null(group_FUN)) {
                a <- list(gres)
                nf <- names(formals(group_FUN))
                if (".GROUP" %in% nf) a$.GROUP <- group
                gres <- do.call(group_FUN, args = a)
            }
            group_results[[group]] <- gres # append

            # logging ---- #
            if (log) .log_write(conn, sprintf("[group %s] done", group))
            # logging ---- #

            p(message = sprintf("[group %s] done", group))
        }

        if (simplify) {
            group_results <- unlist(group_results,
                recursive = FALSE, use.names = FALSE
            )
        }
        return(group_results)
    })
}

.process_par_tile <- function(
        x, y = NULL, tiles, group,
        get_params_x = list(),
        get_params_y = list(),
        pad_y = NULL,
        FUN,
        log,
        logpath,
        jid = "",
        parallel_params,
        ...) {
    tiles$active <- group

    .future_fun <- function(i) {
        b <- tiles[i][[1L]]

        tile_idx <- attr(b, "tile")
        ij <- .tile_idx_to_ij(tiles[], tile_idx)
        tile_id <- sprintf("[group %s][tile %d]", group, tile_idx)


        # logging ---- #
        if (log) {
            # sub-job ID passed from master session
            conn <- .log_conn(log_dir = logpath, job_id = jid)
            on.exit(close(conn), add = TRUE)
            .log_write(conn, sprintf("%s start (row %d, col %d)",
                tile_id, ij[[1]], ij[[2]]
            ))
        }
        # logging ---- #

        get_params_x <- c(list(x, tiles, i = i), get_params_x, list(...))
        tile_x <- do.call(getTile, get_params_x)[[1L]] # returns as list
        if (!is.null(y)) {
            get_params_y <- c(list(y, tiles, i = i, pad = pad_y), get_params_y, list(...))
            tile_y <- do.call(getTile, get_params_y)[[1L]]
        }

        # Prepare function arguments
        a <- list(tile_x)
        if (!is.null(y)) a <- c(a, tile_y)
        nf <- names(formals(FUN))
        if (".I" %in% nf) a$.I <- tile_idx
        if (".TILE" %in% nf) a$.TILE <- b
        if (".R" %in% nf) a$.R <- ij[[1L]]
        if (".C" %in% nf) a$.C <- ij[[2L]]
        if (".GROUP" %in% nf) a$.GROUP <- group

        # Apply function
        results <- do.call(FUN, args = a)

        # logging ---- #
        if (log) .log_write(conn, sprintf("%s done", tile_id))
        # logging ---- #
        return(results)
    }

    parallel_params <- c(
        X = list(seq_along(tiles)),
        FUN = .future_fun,
        parallel_params
    )

    do.call(.par_lapply, parallel_params)
}

# group: group index (character name)
.process_seq_tile <- function(
        x, y = NULL, tiles, group,
        get_params_x = list(),
        get_params_y = list(),
        pad_y = NULL,
        FUN,
        setup_out = NULL,
        log,
        logconn, # conn opened and closed in calling function
        ...) {
    tiles$active <- group
    results <- vector("list", length = length(tiles))

    get_params_x <- c(list(x, tiles), get_params_x, list(...))
    if (!is.null(y)) {
        get_params_y <- c(list(y, tiles, pad = pad_y), get_params_y, list(...))
    }

    for (i in seq_along(tiles)) {
        b <- tiles[i][[1L]]
        tile_idx <- attr(b, "tile")
        ij <- .tile_idx_to_ij(tiles[], tile_idx)

        # logging ---- #
        tile_id <- sprintf("[group %s][tile %d]", group, tile_idx)
        if (log) {
            .log_write(logconn, sprintf("%s start (row %d, col %d)",
                tile_id, ij[[1L]], ij[[2L]]
            ))
        }
        # logging ---- #

        # assign index to get
        get_params_x$i <- i
        tile_x <- do.call(getTile, get_params_x)[[1L]] # returns as list
        if (!is.null(y)) {
            get_params_y$i <- i
            tile_y <- do.call(getTile, get_params_y)[[1L]]
        }

        # Prepare function arguments
        a <- list(tile_x)
        if (!is.null(y)) a <- c(a, tile_y)
        nf <- names(formals(FUN))
        if (".I" %in% nf) a$.I <- tile_idx
        if (".TILE" %in% nf) a$.TILE <- b
        if (".R" %in% nf) a$.R <- ij[[1L]]
        if (".C" %in% nf) a$.C <- ij[[2L]]
        if (".GROUP" %in% nf) a$.GROUP <- group
        if (".SETUP_OUT" %in% nf) a$.SETUP_OUT <- setup_out

        # Apply function
        results[[i]] <- do.call(FUN, args = a)

        # logging ---- #
        if (log) .log_write(logconn, sprintf("%s done", tile_id))
        # logging ---- #
    }

    results
}
