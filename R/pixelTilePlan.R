#' @include package_imports.R
#' @include classes.R
#' @include tilePlan.R

#' @title Pixel Tile Plan
#' @name pixelTilePlan-class
#' @aliases pixelTilePlan
#' @description
#' Utility class for defining pixel-exact tiles of images in a format that is
#' easy to setup and manipulate using `$` and `$<-` generics.
#'
#' @section Getting tile pixel indices:
#' `[i]` and `[i, j]` indexing can be used to select tiles, similarly to a
#' matrix. `[]` without any indexing will return the entire set of indices
#' as a list. Indices are returned as lists of integer vectors of length 4,
#' with values xmin, xmax, ymin, ymax. Extracted vectors of indices will
#' have metadata attached via `attr()`. See metadata section below.
#'
#' @section padding:
#' `+`/`-` can be used to add or subtract padding to each of the tiles.
#' Each bound will be expanded by the pad value. Pad values may only be
#' integer values.
#'
#' @section previewing tiles:
#' `plot()` can be used to check the layout of the tiles.
#'
#' @section metadata:
#' The `pixelTilePlan` object can contain metadata. By default after extent and
#' tiles setup, a column called `"tile"` will be set up that simply records
#' which tile it is.
#'
#' * `$` and `$<-` can be used to get and set specific metadata, the `"pxdims"`
#'   which are the pixel dimensions of the image to iterate across, `"ncols"`
#'   and `"nrows"` which are the px dims of a tile, and the `"pad"` value.
#' * `[[i]]` selection will pull specific metadata rows corresponding to the
#' selected tiles.
#' @examples
#' x <- tilePlan("pixel")
#' x$pxdims <- c(100, 100) # 100 px rows x 100 px cols to iterate across
#' x$ncols <- 20 # 20 px
#'
#' length(x) # check how many tiles there are
#' dim(x)
#' nrow(x)
#' ncol(x)
#'
#' # previewing
#' plot(x)
#'
#' # tile padding
#' y <- x + 3
#' plot(y, alpha = 0.3) # red border shows the image space
#' # this is now larger than the original space.
#'
#' # negative padding
#' z <- x - 5
#' plot(ext(c(0, 100, -100, 0)))
#' plot(z, add = TRUE)
#'
#' # tile selection
#' x[5]
#' x[2, 2:3]
#'
#' # metadata
#' x$tile
#' x$fname <- sprintf("tile_%03d.tif", x$tile)
#' x[[5]]
#' x[[1:3]]$fname
NULL

setMethod("initialize", signature("pixelTilePlan"), function(.Object, ...) {
    dots <- list(...)

    # direct assignments
    if (!is.null(dots$pxdims)) .Object@pxdims <- dots$pxdims
    if (!is.null(dots$dims)) .Object@dims <- dots$dims
    if (!is.null(dots$tile_dims)) .Object@tile_dims <- dots$tile_dims
    if (!is.null(dots$n)) .Object@n <- dots$n
    if (!is.null(dots$tiles)) .Object@tiles <- dots$tiles
    if (!is.null(dots$pad)) .Object@pad <- dots$pad
    if (!is.null(dots$metadata)) .Object@metadata <- dots$metadata

    # initialize vals
    if (length(.Object@n) == 0L) {
        .Object@n <- 0L
    }
    if (length(.Object@dims) == 0L) {
        .Object@dims <- c(0L, 0L)
    }
    if (length(.Object@tile_dims) == 0L) {
        .Object@tile_dims <- c(0L, 0L)
    }

    # return early if pxdims not provided
    if (length(.Object@pxdims) == 0L) {
        return(.Object)
    }
    checkmate::assert_integerish(.Object@pxdims, len = 2L)

    # return early if ncols and nrows are not provided
    if (all(.Object@tile_dims == c(0, 0))) {
        return(.Object)
    } else if (.Object@tile_dims[[1L]] == 0) {
        .Object@tile_dims[[1L]] <- .Object@tile_dims[[2L]]
    } else if (.Object@tile_dims[[2L]] == 0) {
        .Object@tile_dims[[2L]] <- .Object@tile_dims[[1L]]
    }
    checkmate::assert_integerish(.Object@tile_dims, len = 2L)

    # set dims
    .Object@dims <- as.integer(c(
        ceiling(.Object@pxdims[[1L]] / .Object@tile_dims[[1L]]),
        ceiling(.Object@pxdims[[2L]] / .Object@tile_dims[[2L]])
    ))

    # set n
    .Object@n <- length(.Object)

    # initialize metadata
    if (nrow(.Object@metadata) == 0L || nrow(.Object@metadata) != .Object@n) {
        .Object@metadata <- data.frame(tile = seq_len(.Object@n))
    }

    .Object
})

#' @rdname dollar
#' @export
setMethod("$<-", signature("pixelTilePlan", "ANY"), function(x, name, value) {
    if (name == "pxdims") {
        x@pxdims <- value
        return(initialize(x))
    }
    if (name == "ncols") {
        x@tile_dims[[2L]] <- value
        return(initialize(x))
    }
    if (name == "nrows") {
        x@tile_dims[[1L]] <- value
        return(initialize(x))
    }
    callNextMethod()
})

#' @rdname dollar
#' @export
setMethod("$", signature("pixelTilePlan"), function(x, name) {
    if (name == "pxdims") return(x@pxdims)
    if (name == "ncols") return(x@tile_dims[[2L]])
    if (name == "nrows") return(x@tile_dims[[1L]])
    callNextMethod()
})

#' @rdname hidden_docs
#' @export
setMethod("show", signature("pixelTilePlan"), function(object) {
    cat("Object of class", class(object), "\n")

    plist <- list(
        tiles = length(object),
        pxdim = toString(object@pxdims),
        pxrows = object@tile_dims[[1L]],
        pxcol = object@tile_dims[[2L]],
        dim = toString(c(dim(object)[[1]], dim(object)[[2]])),
        pad = object@pad
    )
    GiottoUtils::print_list(plist)
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "pixelTilePlan", i = "numeric", j = "numeric", drop = "missing"), function(x, i, j, ...) {
    callNextMethod(x, i, j, tile_fun = .px_tile_bounds, fun = as.integer, zero = TRUE, ...)
})

#' @rdname arith
#' @export
setMethod("+", signature("pixelTilePlan", "numeric"), function(e1, e2) {
    checkmate::assert_integerish(e2)
    e1@pad <- e1@pad + e2
    e1
})

#' @rdname plot
#' @export
setMethod("plot", signature("pixelTilePlan", "missing"), function(x, ...) {
    parent_method <- getMethod("plot", signature("tilePlan", "missing"))
    parent_method(x = x, flip = TRUE, ...)
    rect(0, -x@pxdims[[1L]], x@pxdims[[2]], 0, border = "red")
})

#' @rdname centroids
#' @export
setMethod("centroids", signature("pixelTilePlan"), function(x, fun = function(x) x, zero = TRUE, ...) {
    a <- GiottoUtils::get_args_list(...)
    a$offset = c(0, 0)
    do.call(callNextMethod, a)
})


# helpers ####

#' @export
.DollarNames.pixelTilePlan <- function(x, pattern) {
    c(colnames(x@metadata), "ncols", "nrows", "pxdims", "pad")
}

# x: tilePlan or matrix-like
# i: row index
# j: col index
.px_tile_bounds <- function(x, i, j) {
    tile_dims <- x@tile_dims
    checkmate::assert_integerish(i, len = 1L)
    checkmate::assert_integerish(j, len = 1L)
    c(
        tile_dims[[2]] * (j - 1L) + 1L,
        tile_dims[[2]] * j,
        tile_dims[[1]] * (i - 1L) + 1L,
        tile_dims[[1]] * i
    )
}
