#' @include package_imports.R
#' @include classes.R
#' @include tileIterator.R

#' @title Pixel Tile Iterator
#' @name pixelTileIterator-class
#' @aliases pixelTileIterator
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
#' Each bound will be expanded by the buffer value. Buffer values may only be
#' integer values.
#'
#' @section previewing tiles:
#' `plot()` can be used to check the layout of the tiles.
#'
#' @section metadata:
#' The `pixelTileIterator` object can contain metadata. By default after extent and
#' tiles setup, a column called `"tile"` will be set up that simply records
#' which tile it is.
#'
#' * `$` can be used to view a specific type of metadata
#' * `$<-` can be used to set additional metadata items
#' * `[[i]]` selection will pull specific metadata rows corresponding to the
#' selected tiles.
#' @examples
#' x <- tileIterator("pixel")
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
#' plot(y, alpha = 0.3)
#' rect(0, -100, 100, 0, border = "red")
#' # this is now larger than the original space.
#'
#' # negative buffer
#' z <- x - 5
#' plot(ext(c(0, 100, -100, 0)))
#' rect(0, -100, 100, 0, border = "red")
#' plot(z, add = TRUE)
#'
#' # tile selection
#' x[5]
#' x[1, 2:3]
#'
#' # metadata
#' x$tile
#' x$fname <- sprintf("tile_%03d.tif", x$tile)
#' x[[5]]
#' x[[1:3]]$fname
NULL

setMethod("initialize", signature("pixelTileIterator"), function(.Object, ...) {
    dots <- list(...)

    # direct assignments
    if (!is.null(dots$pxdims)) x@pxdims <- dots$pxdims
    if (!is.null(dots$nrows)) x$nrows <- dots$nrows
    if (!is.null(dots$ncols)) x$ncols <- dots$ncols
    if (!is.null(dots$n)) x@n <- dots$n
    if (!is.null(dots$tiles)) x@tiles <- dots$tiles
    if (!is.null(dots$buffer)) x@buffer <- dots$buffer
    if (!is.null(dots$metadata)) x@metadata <- dots$metadata

    # initialize vals
    if (length(.Object@n) == 0L) {
        .Object@n <- 0
    }
    if (length(.Object@ncols) == 0L) {
        .Object@ncols <- 0
    }
    if (length(.Object@nrows) == 0L) {
        .Object@nrows <- 0
    }

    # return early if pxdims not provided
    if (length(.Object@pxdims) == 0L) {
        return(.Object)
    }
    checkmate::assert_integerish(.Object@pxdims, len = 2L)

    # return early if ncols and nrows are not provided
    if (.Object@nrows == 0 && .Object@ncols == 0) {
        return(.Object)
    } else if (.Object@nrows == 0) {
        .Object@nrows <- .Object@ncols
    } else if (.Object@ncols == 0) {
        .Object@ncols <- .Object@nrows
    }
    checkmate::assert_integerish(.Object@ncols, len = 1L)
    checkmate::assert_integerish(.Object@nrows, len = 1L)

    # generate tile array
    .Object@tiles <- .px_tile_plan(
        pxdims = .Object@pxdims,
        nrows = .Object@nrows,
        ncols = .Object@ncols
    )
    # set n
    .Object@n <- length(.Object)

    # initialize metadata
    if (nrow(.Object@metadata) == 0L || nrow(.Object@metadata) != .Object@n) {
        .Object@metadata <- data.frame(tile = seq_len(.Object@n))
    }

    .Object
})

#' @export
setMethod("$<-", signature("pixelTileIterator", "ANY"), function(x, name, value) {
    if (name == "pxdims") {
        x@pxdims <- value
        return(initialize(x))
    }
    if (name == "ncols") {
        x@ncols <- value
        return(initialize(x))
    }
    if (name == "nrows") {
        x@nrows <- value
        return(initialize(x))
    }
    x@metadata[[name]] <- value
    x
})

#' @export
setMethod("$", signature("pixelTileIterator"), function(x, name) {
    if (name == "pxdims") return(x@pxdims)
    if (name == "ncols") return(x@ncols)
    if (name == "nrows") return(x@nrows)
    x@metadata[[name]]
})

#' @export
setMethod("show", signature("pixelTileIterator"), function(object) {
    cat("Object of class", class(object), "\n")

    plist <- list(
        tiles = length(object),
        pxdim = toString(object@pxdims),
        pxrows = object@nrows,
        pxcol = object@ncols,
        dim = toString(c(dim(object)[[1]], dim(object)[[2]])),
        buffer = object@buffer
    )
    GiottoUtils::print_list(plist)
})

#' @export
setMethod("[", signature(x = "pixelTileIterator", i = "numeric", j = "numeric", drop = "missing"), function(x, i, j) {
    callNextMethod(x, i, j, fun = as.integer, zero = TRUE)
})

#' @export
setMethod("+", signature("pixelTileIterator", "numeric"), function(e1, e2) {
    checkmate::assert_integerish(e2)
    e1@buffer <- e1@buffer + e2
    e1
})

# helpers ####

#' @export
.DollarNames.pixelTileIterator <- function(x, pattern) {
    c(colnames(x@metadata), "ncols", "nrows", "pxdims")
}

.px_tile_plan <- function(pxdims, nrows, ncols) {
    checkmate::assert_integerish(pxdims, len = 2L)
    checkmate::assert_integerish(nrows, len = 1L)
    checkmate::assert_integerish(ncols, len = 1L)
    tilesy <- ceiling(pxdims[[1]] / nrows)
    tilesx <- ceiling(pxdims[[2]] / ncols)

    stops <- c()
    for (i in seq_len(tilesy)) {
        for (j in seq_len(tilesx)) {
            stops <- c(
                stops,
                ncols * (j - 1L) + 1L,
                ncols * j,
                nrows * (i - 1L) + 1L,
                nrows * i
            )
        }
    }
    stops <- as.integer(stops)
    a <- array(stops, dim = c(4, tilesx, tilesy))
    aperm(a, perm = c(3, 2, 1))
}

#' @export
setMethod("plot", signature("pixelTileIterator", "missing"), function(x, ...) {
    callNextMethod(x = x, flip = TRUE, ...)
    rect(0, -x@pxdims[[1L]], x@pxdims[[2]], 0, border = "red")
})
