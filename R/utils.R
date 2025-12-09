.terra_read <- function(x, prefer = NULL, vect_params = list(), rast_params = list()) {
    rast_params$noflip <- rast_params$noflip %||% TRUE # expect no CRS
    vect_params$proxy <- vect_params$proxy %||% TRUE # read as SpatVectorProxy

    # if expected type
    if (!is.null(prefer)) {
        prefer <- match.arg(prefer, c("vector", "raster"))
        return(switch(prefer,
            "raster" = .terra_read_raster(x, rast_params),
            "vector" = .terra_read_vector(x, vect_params)
        ))
    }

    # fallback: try with handling
    try_rast <- try(.terra_read_raster(x, rast_params), silent = TRUE)
    if (!inherits(try_rast, "try-error")) {
        return(try_rast)
    }
    try_vect <- try(.terra_read_vector(x, vect_params), silent = TRUE)
    if (!inherits(try_vect, "try-error")) {
        return(try_vect)
    }
    stop("[fileConnect] File not readable by {terra}\n", call. = FALSE)
}

.terra_read_raster <- function(x, rast_params = list()) {
    do.call(terra::rast, c(list(x), rast_params))
}

.terra_read_vector <- function(x, vect_params = list()) {
    do.call(terra::vect, c(list(x), vect_params))
}

# convert SpatExtent to unnamed numeric vector
.ext_to_num_vec <- function(x) {
    out <- x[]
    names(out) <- NULL
    out
}

# x: tilePlan or matrix-like
# i: index
# returns: i and j as a list of row then col indices.
.tile_idx_to_ij <- function(x, i) {
    i_idx <- floor(i / ncol(x)) + 1L
    no_resid <- i %% ncol(x) == 0L
    i_idx[no_resid] <- i_idx[no_resid] - 1L
    j_idx <- i %% ncol(x)
    j_idx[j_idx == 0L] <- ncol(x)
    list(i_idx, j_idx)
}

# x: tilePlan or matrix-like
# i: row index
# j: col index
# returns: tile index as a numeric
.ij_to_tile_idx <- function(x, i, j) {
    if (i > nrow(x)) {
        stop("[.ij_to_tile_idx] not that many rows", call. = FALSE)
    }
    if (j > ncol(x)) {
        stop("[.ij_to_tile_idx] not that many cols", call. = FALSE)
    }
    ((i - 1) * ncol(x)) + j
}

# convenience for getting all the args supplied to the function as a list
# `keep` - character, names of input args to keep
# `toplevel` - numeric number of levels to go up the callstack
#  ... additional params to capture
.get_args_list <- function (toplevel = 1L, keep = NULL, ...) {
    a <- as.list(as.environment(parent.frame(toplevel)))
    if (!is.null(keep)) {
        a <- a[names(a) %in% keep]
    }
    c(a, list(...))
}

# ID random across nodes and workers
.random_id <- function(len = 12L) {
    sampleset <- c(LETTERS, letters, seq(from = 0, to = 9))
    paste0(sample(sampleset, size = len, replace = TRUE), collapse = "")
}

# consistent timestamping
.timestamp <- function () {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
}

.check_package <- function(x) {
    if (length(x) > 1L) {
        lapply(x, function(x_i) .check_package(x_i))
        return(invisible())
    }

    if (requireNamespace(x, quietly = TRUE)) return(invisible())
    stop(sprintf("{%s} is not installed yet.", x), call. = FALSE)
    invisible()
}

.print_list <- function(x, pre = "") {
    if (length(x) == 0) {
        cat("<empty>\n")
    }
    ns <- names(x)
    if (length(ns) != length(x)) {
        stop("all elements must be named")
    }
    x <- lapply(x, function(i) {
        if (is.character(i) || is.logical(i) || is.factor(i) ||
            is.numeric(i)) {
            return(as.character(i))
        }
        .print_fallback(i)
    })
    cat(sprintf("%s%s : %s", pre, format(ns), x), sep = "\n")
    invisible(x)
}

.print_fallback <- function(x) {
    sprintf("<%s> length %d", class(x), length(x))
}

.handle_warnings <- function(expr) {
    warnings <- character(0)
    result <- withCallingHandlers(expr, warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
    })
    list(result = result, warnings = warnings)
}

# backwards compat
if (getRversion() < "4.4.0") {
    `%||%` <- function(x, y) {
        if (is.null(x)) y else x
    }
}

