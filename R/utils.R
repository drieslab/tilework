# handle reading as SpatRaster
.create_terra_spatraster <- function(image_path) {
    raster_object <- try(terra::rast(x = image_path, noflip = TRUE))
    if (inherits(raster_object, "try-error")) {
        stop(raster_object, " can not be read by terra::rast() \n")
    }
    return(raster_object)
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


