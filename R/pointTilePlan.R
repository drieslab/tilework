#' @include package_imports.R
#' @include classes.R
#' @include tilePlan.R

# pointTilePlan ####
# * docs ####

#' @name pointTilePlan-class
#' @title Point Tile Plan
#' @aliases pointTilePlan
#' @description
#' Utility class for tiling centered on arbitrary (x, y) coordinates with a
#' uniform tile size. Unlike grid-based tile plans, tile placement is driven
#' entirely by the supplied point locations.
#'
#' All coordinates, tile dims, and padding live in one consistent reference
#' frame set by `$input` (`"spatial"` for CRS units, `"pixel"` for pixel
#' indices). The bound type returned by [getTile()] is a separate concern
#' controlled by `$output` and resolved at extraction time.
#'
#' @section Setup:
#' * `pointTilePlan()` creates an instance. `input` defaults to `"spatial"`;
#'   `output` defaults to `input`.
#' * `$coords<-` sets the n x 2 center coordinate matrix (columns: x, y).
#' * `$width<-` / `$height<-` set the uniform tile width and height in input
#'   coordinate units.
#' * `$input<-` / `$output<-` change the coordinate / output mode.
#' * `$nrows<-` / `$ncols<-` are aliases for `$height<-` / `$width<-` for
#'   consistency with [pixelTilePlan-class] when using pixel coordinates.
#' * `$rast_dims<-` sets `c(nrow, ncol)` of the reference raster — required
#'   for `plot()` when `input = "pixel"` and for cross-mode `getTile()` calls
#'   when no raster is provided.
#' * `$extent<-` sets `c(xmin, xmax, ymin, ymax)` — required for
#'   pixel → CRS conversion without a raster.
#'
#' @section Coordinate modes and required raster metadata:
#'
#' | Scenario | `@rast_dims` | `@extent` |
#' |---|---|---|
#' | `input = "spatial"`, `output = "spatial"` | not needed | not needed |
#' | `input = "pixel"`, `output = "pixel"` | for `plot()` | not needed |
#' | `input = "pixel"`, `output = "spatial"` | required | required |
#' | `input = "spatial"`, `output = "pixel"` | required | derived |
#'
#' When [getTile()] is called with a `SpatRaster`, the raster's own metadata
#' is used for conversion — `@rast_dims` and `@extent` are only needed for
#' standalone operations (plotting, validation) without a raster.
#'
#' @section Getting tile bounds:
#' `[i]` returns bounds in the **input** coordinate space: `SpatExtent` when
#' `input = "spatial"`, `integer[4]` when `input = "pixel"`. `$output` is not
#' consulted at `[i]` time. Use [getTile()] for output-mode conversion.
#'
#' @section Pixel mode and center ambiguity:
#' When `input = "pixel"`, tile dims should be odd for an unambiguous center
#' pixel. With even dimensions `center ± width/2` produces non-integer bounds
#' that are truncated by `as.integer()`.
#'
#' @section metadata:
#' After setting coords, metadata is auto-populated with `"tile"`, `"x"`, and
#' `"y"` columns. Additional columns can be added via `$<-`.
#'
#' @examples
#' tp <- pointTilePlan("spatial")
#' tp$coords <- cbind(x = c(10, 20, 30), y = c(5, 15, 25))
#' tp$width  <- 5
#' tp$height <- 5
#' tp
#'
#' length(tp)
#' tp[1]
#' tp[2:3]
#' centroids(tp)
#' plot(tp)
#'
#' # CRS input, pixel output (raster needed at getTile time)
#' tp2 <- pointTilePlan(input = "spatial", output = "pixel")
#' tp2$coords <- cbind(x = c(10, 20), y = c(5, 15))
#' tp2$width  <- 100
#' tp2$height <- 100
NULL

# * initialize ####

setMethod("initialize", signature("pointTilePlan"), function(.Object, ...) {
    .Object <- callNextMethod(.Object, ...)

    if (length(.Object@input) == 0L)  .Object@input  <- "spatial"
    if (length(.Object@output) == 0L) .Object@output <- .Object@input

    if (length(.Object@tile_dims) == 1L) .Object@tile_dims <- rep(.Object@tile_dims, 2L)

    # return early if coords not provided
    if (nrow(.Object@coords) == 0L) return(.Object)
    checkmate::assert_matrix(.Object@coords, ncols = 2L, mode = "numeric")

    # return early if tile_dims not set
    if (all(.Object@tile_dims == c(0, 0))) return(.Object)

    n <- nrow(.Object@coords)
    .Object@dims <- c(as.integer(n), 1L)
    .Object@n   <- as.numeric(n)

    # (re)build metadata only when row count has changed
    if (nrow(.Object@metadata) == 0L || nrow(.Object@metadata) != n) {
        .Object@metadata <- data.frame(
            tile = seq_len(n),
            x    = .Object@coords[, 1L],
            y    = .Object@coords[, 2L]
        )
    }

    .Object
})

# * show ####

#' @rdname hidden_docs
#' @export
setMethod("show", signature("pointTilePlan"), function(object) {
    cat("Object of class", class(object), "\n")

    if (nrow(object@coords) == 0L) {
        cat("<empty>\n")
        return(invisible())
    }

    plist <- list(
        input     = object@input,
        output    = object@output,
        n         = length(object),
        tile_dims = sprintf("%s (height, width)", paste(object@tile_dims, collapse = ", ")),
        pad       = object@pad
    )
    .print_list(plist)
})

# * $ and $<- ####

#' @rdname dollar
#' @export
setMethod("$<-", signature("pointTilePlan", "ANY"), function(x, name, value) {
    if (name == "coords") {
        if (!is.matrix(value)) value <- as.matrix(value)
        if (ncol(value) != 2L) stop("$coords must be an n x 2 matrix (columns: x, y)", call. = FALSE)
        x@coords <- value
        return(initialize(x))
    }
    if (name == "width" || name == "ncols") {
        x@tile_dims[[2L]] <- value
        if (x@tile_dims[[1L]] == 0) x@tile_dims[[1L]] <- value
        return(initialize(x))
    }
    if (name == "height" || name == "nrows") {
        x@tile_dims[[1L]] <- value
        if (x@tile_dims[[2L]] == 0) x@tile_dims[[2L]] <- value
        return(initialize(x))
    }
    if (name == "input") {
        x@input <- match.arg(value, c("spatial", "pixel"))
        return(initialize(x))
    }
    # output, rast_dims, extent: update slot only, no reinitialize
    if (name == "output") {
        x@output <- match.arg(value, c("spatial", "pixel"))
        return(x)
    }
    if (name == "rast_dims") {
        checkmate::assert_numeric(value, len = 2L)
        x@rast_dims <- value
        return(x)
    }
    if (name == "extent") {
        x@extent <- .ext_to_num_vec(terra::ext(value))
        return(x)
    }
    callNextMethod()
})

#' @rdname dollar
#' @export
setMethod("$", signature("pointTilePlan"), function(x, name) {
    switch(name,
        coords    = x@coords,
        width     = ,
        ncols     = x@tile_dims[[2L]],
        height    = ,
        nrows     = x@tile_dims[[1L]],
        input     = x@input,
        output    = x@output,
        rast_dims = x@rast_dims,
        extent    = x@extent,
        callNextMethod()
    )
})

# * [ ####

#' @rdname bracket
#' @export
setMethod(
    "[", signature(x = "pointTilePlan", i = "numeric", j = "numeric", drop = "missing"),
    function(x, i, j, ...) {
        if (x@input == "spatial") {
            callNextMethod(x, i, j, tile_fun = .point_tile_bounds, fun = ext, zero = FALSE, ...)
        } else {
            callNextMethod(x, i, j, tile_fun = .point_tile_bounds_px, fun = as.integer, zero = FALSE, ...)
        }
    }
)

# * arith ####

#' @rdname arith
#' @export
setMethod("+", signature("pointTilePlan", "numeric"), function(e1, e2) {
    if (e1@input == "pixel") checkmate::assert_integerish(e2)
    callNextMethod()
})

# * plot ####

#' @rdname plot
#' @export
setMethod("plot", signature("pointTilePlan", "missing"), function(x, ...) {
    parent_method <- getMethod("plot", signature("tilePlan", "missing"))
    if (x@input == "pixel" && length(x@rast_dims) == 2L) {
        parent_method(x = x, flip = TRUE, ...)
        rect(0, -x@rast_dims[[1L]], x@rast_dims[[2L]], 0, border = "red")
    } else {
        parent_method(x = x, ...)
    }
})

# * centroids ####

#' @rdname centroids
#' @export
setMethod("centroids", signature("pointTilePlan"), function(x, ...) {
    if (x@input == "spatial") {
        terra::vect(x@coords, type = "points")
    } else {
        x@coords
    }
})

# * helpers ####

#' @export
.DollarNames.pointTilePlan <- function(x, pattern) {
    c(colnames(x@metadata), "coords", "width", "height", "ncols", "nrows",
      "input", "output", "rast_dims", "extent", "pad")
}

# Compute c(xmin, xmax, ymin, ymax) centred on coords[i,] in spatial units.
# j is always 1 for pointTilePlan and is ignored.
.point_tile_bounds <- function(x, i, j) {
    cx <- x@coords[i, 1L]
    cy <- x@coords[i, 2L]
    hw <- x@tile_dims[[2L]] / 2   # half-width
    hh <- x@tile_dims[[1L]] / 2   # half-height
    c(cx - hw, cx + hw, cy - hh, cy + hh)
}

# Compute c(col_min, col_max, row_min, row_max) centred on integer pixel coords[i,].
# Uses integer floor-division so odd dims produce exact symmetric tiles and even
# dims are biased left/up. j is ignored.
.point_tile_bounds_px <- function(x, i, j) {
    cx <- as.integer(x@coords[i, 1L])
    cy <- as.integer(x@coords[i, 2L])
    w  <- as.integer(x@tile_dims[[2L]])
    h  <- as.integer(x@tile_dims[[1L]])
    col_min <- cx - (w - 1L) %/% 2L
    col_max <- col_min + w - 1L
    row_min <- cy - (h - 1L) %/% 2L
    row_max <- row_min + h - 1L
    c(col_min, col_max, row_min, row_max)
}
