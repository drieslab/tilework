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
