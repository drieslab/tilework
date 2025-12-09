.par_apply <- function (X, FUN,
    method = c("future", "biocparallel"),
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
    return(invisible(BPPARAM))
}
