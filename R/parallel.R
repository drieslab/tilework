#' @name parallel_params
#' @title Parallel Processing Parameters
#' @family parallel settings
#' @description
#' [tileApply()] is parallelized through either [future.apply::future_lapply()]
#' (default) or [BiocParallel::bplapply()].
#'
#' Additional parameters to control parallelization can be passed as a `list`
#' through the `parallel_params` argument in `tileApply()` methods.
#'
#' @section Parameters:
#' Available parameters for the `parallel_params` list:
#'
#' * `method` - character. Either `"future"` (default) or `"biocparallel"`.
#'   Which parallelization framework to use. Overrides `setTileworkParMethod()`
#' * `future_seed` - logical (default = `TRUE`). Passed to the `future.seed`
#'   parameter in [future.apply::future_lapply()]. Only used when
#'   `method = "future"`.
#' * `BPPARAM` - a \{BiocParallel\} parallelization parameter object. Only
#'   used when `method = "biocparallel"`.
#'
#' Additional parameters relevant to the underlying functions may also be
#' passed in the list and will be forwarded via `...`.
#'
#' @section Package Options:
#' * `"tilework.warn_sequential"` - logical (default = `TRUE`). Whether to
#'   warn when using parallelization defaults that run sequentially
#'   (i.e., `future::sequential()` or `BiocParallel::SerialParam()`).
#' * `"tilework.par_method"` - character (default = `"future"`). Either
#' `"future"` or `"biocparallel"`. Which parallelization framework to use.
#' * `"tilework.bpparam"` - a \{BiocParallel\} parameter object. Set this to
#'   automatically use a specific BPPARAM, analogous to setting a
#'   [future::plan()] for the \{future\} backend.
#'
#' @examples
#' getTileworkParMethod()
#'
#' # Set to BiocParallel
#' setTileworkParMethod("biocparallel")
#' getTileworkParMethod()
#'
#' \dontrun{
#' # Example pseudocode for how to use parallelization
#' 
#' # Using future backend with multisession
#' future::plan(future::multisession, workers = 4)
#' tileApply(x, tiles, fun)
#'
#' # Using BiocParallel backend
#' setTileworkParMethod("biocparallel")
#' options(tilework.bpparam = BiocParallel::SnowParam(workers = 4))
#' tileApply(x, tiles, fun)
#'
#' # Or override per-call
#' setTileworkParMethod("future")  # global default is future
#' tileApply(x, tiles, fun, 
#'     parallel_params = list(method = "biocparallel")
#' ) # but use BiocParallel here
#'
#' # Suppress sequential warnings
#' options(tilework.warn_sequential = FALSE)
#' }
#' @seealso [tileApply()]
NULL

#' @rdname parallel_params
#' @export
#' @returns `getTileworkParMethod` returns `character`. The parallelization
#' method being used.
getTileworkParMethod <- function() {
    getOption("tilework.par_method", "future")
}

#' @rdname parallel_params
#' @export
#' @param method character. Either `"future"` (default) or `"biocparallel"`.
#'   Which parallelization framework to use.
#' @returns `setTileworkParMethod` returns `NULL` invisibly
setTileworkParMethod <- function(method) {
    method <- match.arg(tolower(method), c("future", "biocparallel"))
    options("tilework.par_method" = method)
    invisible()
}


.par_lapply <- function (X, FUN,
    method = getTileworkParMethod(),
    future_seed = TRUE,
    BPPARAM = NULL,
    ...) {
    method <- match.arg(tolower(method), c("future", "biocparallel"))
    save_list <- switch(method,
        future = {
            .check_future_parallel_plan()
            future.apply::future_lapply(
                X = X, FUN = FUN, future.seed = future_seed, ...
            )
        },
        biocparallel = {
            .check_package("BiocParallel")
            BPPARAM <- BPPARAM %||% .bpparam()
            BiocParallel::bplapply(X = X, FUN = FUN, BPPARAM = BPPARAM, ...)
        }
    )
    return(save_list)
}

.check_future_parallel_plan <- function() {
    if (!getOption("tilework.warn_sequential", TRUE) ||
        !inherits(future::plan(), "uniprocess")) {
        return(invisible())
    }

    txt <- c(
        .str_reformat("Your code is running sequentially. For better performance, consider using a parallel plan like:"),
        .str_reformat("future::plan(future::multisession)", .initial = "  "),
        .str_reformat("To silence this warning, set options(\"tilework.warn_sequential\" = FALSE)", .initial = "  ")
    )
    warning(paste(txt, collapse = "\n"), call. = FALSE)
}

.check_bpparam <- function(bpparam) {
    if (!getOption("tilework.warn_sequential", TRUE) ||
        !inherits(bpparam, "SerialParam")) {
        return(invisible())
    }

    txt <- c(
        .str_reformat("Your code is running sequentially. For better performance, consider using a parallel plan like:"),
        .str_reformat("options(\"tilework.bpparam\" = BiocParallel::SnowParam())", .initial = "  "),
        .str_reformat("To silence this warning, set options(\"tilework.warn_sequential\" = FALSE)", .initial = "  ")
    )
    warning(paste(txt, collapse = "\n"), call. = FALSE)
}

.bpparam <- function(BPPARAM = NULL) {
    .check_package("BiocParallel")
    if (is.null(BPPARAM)) {
        BPPARAM <- getOption("tilework.bpparam", BiocParallel::SerialParam())
    }
    else {
        checkmate::assert_class(BPPARAM, "BiocParallelParam")
        options(tilework.bpparam = BPPARAM)
    }
    .check_bpparam(BPPARAM)
    return(BPPARAM)
}
