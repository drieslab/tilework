
#' @rdname tileApply-plan
#' @export
setMethod(
    "tileApply", signature("token", "missing", "tileSelection"),
    function(
        x, tiles, FUN,
        get_params_x = list(),
        log = FALSE,
        logpath = getTileworkLogDir(),
        parallel_params = list(),
        verbose = NULL,
        ...) {
        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        checkmate::assert_list(get_params_x)
        checkmate::assert_list(parallel_params)
        checkmate::assert_function(FUN)
        checkmate::assert_flag(log)
        jid <- getTileworkJobID(advance = TRUE)
        if (log) .vmsg(.v = verbose, "logging as job", jid)
        progressr::with_progress({
            p <- progressr::progressor(along = tiles@indices)

            .future_fun <- function(i) {
                i <- tiles@indices[i]
                tp <- tiles@tp
                ij <- .tile_idx_to_ij(tp, i)
                tile_id <- sprintf("[tile %d]", i)
                if (log) {
                    conn <- .log_conn(log_dir = logpath, job_id = jid)
                    on.exit(close(conn), add = TRUE)
                    .log_write(conn, sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]))
                }

                tile_ext <- tp[i][[1L]]

                if (log) {
                    .log_write(conn, tile_id, "bounds:", .ext_to_num_vec(tile_ext))
                    .log_write(conn, tile_id, "pad:", tp@pad)
                }

                gt_params_x <- c(list(x, tp, i = i), list(get_params = get_params_x), list(...))
                tile_data <- do.call(getTile, gt_params_x)[[1L]]

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

            parallel_params <- c(
                X = list(seq_along(tiles@indices)),
                FUN = .future_fun,
                parallel_params
            )

            do.call(.par_lapply, parallel_params)
        })
    }
)

#* token,token xy ####

#' @rdname tileApply-plan
#' @export
setMethod(
    "tileApply", signature("token", "token", "tileSelection"),
    function(
        x, y, tiles, FUN,
        get_params_x = list(),
        get_params_y = list(),
        pad_y = NULL,
        log = FALSE,
        logpath = getTileworkLogDir(),
        parallel_params = list(),
        verbose = NULL,
        ...) {
        .dmsg(.v = verbose, "[tileApply] running...", plist = list(...))

        checkmate::assert_list(get_params_x)
        checkmate::assert_list(get_params_y)
        checkmate::assert_list(parallel_params)
        checkmate::assert_function(FUN)
        checkmate::assert_flag(log)
        jid <- getTileworkJobID(advance = TRUE)
        if (log) .vmsg(.v = verbose, "logging as job", jid)
        if (is.null(y)) stop("[tileApply] `y` may not be NULL\n.", call. = FALSE)
        progressr::with_progress({
            p <- progressr::progressor(along = tiles@indices)

            .future_fun <- function(i) {
                i <- tiles@indices[i]
                tp <- tiles@tp
                ij <- .tile_idx_to_ij(tp, i)
                tile_id <- sprintf("[tile %d]", i)
                if (log) {
                    conn <- .log_conn(log_dir = logpath, job_id = jid)
                    on.exit(close(conn), add = TRUE)
                    .log_write(conn, sprintf("%s start (row %d, col %d)", tile_id, ij[[1]], ij[[2]]))
                }

                tile_ext <- tp[i][[1L]]

                if (log) {
                    .log_write(conn, tile_id, "bounds:", .ext_to_num_vec(tile_ext))
                    .log_write(conn, tile_id, "pad:", tp@pad)
                }

                # prep args
                gt_params_x <- c(list(x, tp, i = i), list(get_params = get_params_x), list(...))
                gt_params_y <- c(list(y, tp, i = i, pad = pad_y), list(get_params = get_params_y), list(...))
                # these are retrieved as list of 1
                tile_x <- do.call(getTile, gt_params_x)[[1L]]
                tile_y <- do.call(getTile, gt_params_y)[[1L]]

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

            parallel_params <- c(
                X = list(seq_along(tiles@indices)),
                FUN = .future_fun,
                parallel_params
            )

            do.call(.par_lapply, parallel_params)
        })
    }
)

# specific methods ####

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("character", "tileSelection"),
    function(sig, tiles, ...) {
        sig <- .handle_warnings(.terra_read(sig))$result
        redispatch_tileapply(sig, tiles, ...)
    }
)

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("SpatVector", "tileSelection"), function(sig, tiles, ...) {
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
setMethod("redispatch_tileapply", signature("SpatRaster", "tileSelection"), function(sig, tiles, ...) {
    f <- terra::sources(sig)
    f <- unique(f)
    .guard_disk_terra_raster(f)
    e <- .ext_to_num_vec(ext(sig))
  
    dgp <- list(
        lyr = NULL, # to getTile,SpatRaster
        prefer = "raster", # to getTile,character
        ext = e # to getTile,character
    )
  
    if (inherits(tiles@tp, "pixelTilePlan")) {
        dgp$extend <- FALSE # to getTile,SpatRaster,pixelTilePlan
        dgp$fill <- NA # to getTile,SpatRaster,pixelTilePlan
    }
  
    callNextMethod(f, tiles, default_get_params = dgp, ...)
})
