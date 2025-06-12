.terra_read <- function(x, prefer = NULL, vect_params = list(), rast_params = list()) {
    rast_params$noflip <- rast_params$noflip %null% TRUE # expect no CRS
    vect_params$proxy <- vect_params$proxy %null% TRUE # read as SpatVectorProxy

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
