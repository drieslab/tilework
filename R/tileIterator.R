#' @include package_imports.R

# docs ####

#' @name hidden_docs
#' @title Hidden Docs
#' @description
#' Dummy documentation for things that do not need much explanation (like
#' `show` methods)
#' @param object object
NULL

#' @title Get and Set Iterator Metadata and Params
#' @name dollar
#' @description
#' Get and set iterator tile metadata. Some params can also be modified with
#' this operator, for example the `$buffer` value or `$pxdims`, `$ncols`, or
#' `$nrows` for `pixelTileIterator`.
#'
#' `$tile` is a default created piece of metadata.
#' @param x `tileIterator`
#' @param name name of item to get or set
#' @param value value to set
#' @examples
#' x <- tileIterator()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x) <- 9
#' x$test <- sprintf("test_value_%d", x$tile)
#' x$test
#' tile_ext <- x[5][[1]]
#' attr(tile_ext, "test")
#' @returns
#' metadata value when using getter or iterator object when using the setter
#' function.
NULL

#' @name plot
#' @title PLot a `tileIterator`
#' @description
#' Plot and preview the iteration scheme.
#' @param x `tileIterator` to plot
#' @param y not used.
#' @param values character. Metadata item to color tiles as. Default is `"tile"`
#' which produces the tile index.
#' @param color_as_factor logical (default = `FALSE`). Whether to convert `value`
#' to a factor to plot as categorical.
#' @param ... additional params to pass
#' @examples
#' x <- tileIterator()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x) <- 9
#' plot(x)
#'
#' x$new_meta <- rev(head(letters, 9))
#' plot(x, value = "new_meta")
NULL

#' @name dim
#' @title Tile Iterator Array Characteristics
#' @aliases nrow ncol length length<-
#' @description
#' Get dimension characteristics of the `tileIterator` tiling plan. These
#' produce information on how the tiles are arrayed in rows `nrow()`, cols `ncol()`,
#' and total number of tiles `length()`.
#'
#' `length<-()` is a special case and currently only used with `spatialTileIterator`,
#' where it is used to request a minimum number of tiles to generate.
#' @param x `tileIterator` object
#' @param value number of tiles to request
#' @examples
#' x <- tileIterator()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x)
#' length(x) <- 9
#' length(x)
#' dim(x)
#' nrow(x)
#' ncol(x)
#' @returns numeric or iterator object when using `length<-()`
NULL

#' @name bracket
#' @title Extract Bounds from Iterator
#' @description
#' Get a set of tile bounds from `tileIterator`. Values are always returned as
#' a `list`, even when length one to reduce surprises with `lapply()` usage.
#' @param x `tileIterator`
#' @param i numeric vector index if `j` is not given. Row index if `j` is also
#' present. Works like `matrix-like` indexing.
#' @param j numeric. Column index
#' @param tile_fun (internal) function used to define tile bounds based on the
#' iterator object and ij indices.
#' @param fun (internal) post-processing function used to convert bounds to
#' expected output. Such as `ext()` for `spatialTileIterator`
#' @param zero logical. Whether to zero out buffer effects. (used by default with
#' `pixelTileIterator`)
#' @param expand_grid logical (internal) whether to use `expand.grid()` on ij
#' indices.
#' @param ... addtional params to pass (not used).
#' @param drop not used.
#' @examples
#' spat <- tileIterator("spatial")
#' ext(spat) <- c(0, 1000, 0, 1000)
#' length(spat) <- 9
#' spat[1]
#' spat[1,2:3]
#' spat[]
#'
#' px <- tileIterator("pixel")
#' px$pxdims <- c(1000, 1000)
#' px$ncols <- 200
#' px$nrows <- 200
#' px[1]
#' px[2, 2:3]
#' px[]
#' @returns `list` of `numeric` or `SpatExtent`
NULL

#' @name double_bracket
#' @title Get and set metadata
#' @description
#' `[[` can be used to get the table of metadata for a specific tile.
#' @param x `tileIterator`
#' @param i tile vector index
#' @param j not used.
#' @param ... not used.
#' @examples
#' spat <- tileIterator("spatial")
#' ext(spat) <- c(0, 1000, 0, 1000)
#' length(spat) <- 9
#' spat[[1]]
#' @seealso [dollar]
#' @returns `data.frame`
NULL

#' @name arith
#' @title Tile Buffers
#' @description
#' Tile buffers or padding extend the bounds of the tile beyond the region that
#' they are initially planned for by an equal amount on all 4 sides. This can
#' help with things like spatial contiguity, so that artificial borders are
#' less obvious.
#'
#' Buffers can be added either via [`$buffer`][dollar] or `+` and `-` operators.
#' The + and - operators specifically modify the buffer value based on the
#' arithmetic ops. This is similar to their usage in [terra::Arith-methods]
#'
#' @section spatial and pixel differences:
#'
#' * Buffers for spatial iterators are added without any further changes.
#' * Buffers for pixel iterators are automatically zeroed out against the top
#' left
#' @param e1 `tileIterator`
#' @param e2 `numeric` to add to buffer
#' @examples
#' spat <- tileIterator("spatial")
#' ext(spat) <- c(0, 1000, 0, 1000)
#' length(spat) <- 9
#' plot(spat)
#' spat[1:3]
#' spat <- spat + 10
#' plot(spat)
#' spat[1:3]
#'
#' px <- tileIterator("pixel")
#' px$pxdims <- c(1000, 1000)
#' px$ncols <- 100
#' px$nrows <- 100
#' plot(px)
#' px[1:3]
#' px <- px + 5
#' plot(px)
#' px[1:3]
#' @returns `tileIterator`
NULL

#' @name ext
#' @title Get and Set Spatial Extent
#' @aliases ext<-
#' @description
#' Get and set a spatial extent.
#' @param x `tileIterator`
#' @param ... addtional params to pass (none implemented)
#' @param value `numeric` of length 4 or `SpatExtent` defining spatial extent.
#' @returns tileIterator if `ext<-()` and `SpatExtent` if `ext()`
NULL

#' @name tileIterator
#' @title Create a Tile Iterator
#' @param type character. One of "spatial", "pixel". Type of iterator to create.
#' @param ... additional params to pass to `new()` call.
#' @examples
#' tileIterator("spatial")
#' tileIterator("pixel")
#' @seealso [spatialTileIterator] and [pixelTileIterator] classes
NULL


# factory ####

#' @rdname tileIterator
#' @export
tileIterator <- function(type = c("spatial", "pixel"), ...) {
    type <- match.arg(type, choices = c("spatial", "pixel"))
    switch(type,
           "spatial" = new("spatialTileIterator", ...),
           "pixel" = new("pixelTileIterator", ...)
    )
}

#' @rdname dollar
#' @export
setMethod("$<-", signature("tileIterator", "ANY"), function(x, name, value) {
    if (name == "buffer") {
        x@buffer <- value
        return(initialize(x))
    }
    x@metadata[[name]] <- value
    x
})

#' @rdname dollar
#' @export
setMethod("$", signature("tileIterator"), function(x, name) {
    if (name == "buffer") return(x@buffer)
    x@metadata[[name]]
})

#' @rdname plot
#' @export
setMethod(
    "plot", signature(x = "tileIterator", y = "missing"),
    function(x, values = "tile", color_as_factor = FALSE, ...) {
        p <- list(...)
        if (length(x) == 0L) {
            stop("No tiles to plot.\nTry requesting tiles with `length()`")
        }
        values <- x@metadata[[values]]
        if (isTRUE(color_as_factor)) values <- as.factor(values)
        p$values <- values
        p$extent_list <- x[]

        if (x@buffer > 0) {
            p$alpha  <- p$alpha %null% 0.3
        }

        do.call(.preview_chunk_plan, args = p)
    }
)

#' @rdname dim
#' @export
setMethod("nrow", signature("tileIterator"), function(x) {
    x@dims[[1L]]
})

#' @rdname dim
#' @export
setMethod("ncol", signature("tileIterator"), function(x) {
    x@dims[[2L]]
})

#' @rdname dim
#' @export
setMethod("length", signature("tileIterator"), function(x) {
    prod(x@dims)
})

#' @rdname dim
#' @export
setMethod("dim", signature("tileIterator"), function(x) {
    c(nrow(x), ncol(x))
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tileIterator", i = "numeric", j = "missing", drop = "missing"), function(x, i, ..., drop) {
    i <- as.integer(i)
    if (any(i > length(x) | i <= 0)) stop("tileIterator: subscript out of bounds", call. = FALSE)
    ij <- .tile_idx_to_ij(x, i)
    x[ij[[1L]], ij[[2L]], expand_grid = FALSE, ...] # pass to numeric/numeric method
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tileIterator", i = "numeric", j = "numeric", drop = "missing"),
          function(x, i, j, tile_fun = .spat_tile_bounds, fun = function(x) x, zero = FALSE, expand_grid = TRUE, drop) {
    .extract_ij_tile(x, i, j,
        expand_grid = expand_grid,
        tile_fun = tile_fun,
        fun = fun,
        zero = zero
    )
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tileIterator", i = "missing", j = "missing", drop = "missing"), function(x, i, j) {
    x[seq_len(length(x))] # pass to numeric/missing method
})

#' @rdname double_bracket
#' @export
setMethod("[[", signature("tileIterator", i = "numeric", j = "missing"), function(x, i, j, ...) {
    x@metadata[i, , drop = FALSE]
})

#' @rdname arith
#' @export
setMethod("+", signature("tileIterator", "numeric"), function(e1, e2) {
    e1@buffer <- e1@buffer + e2
    e1
})

#' @rdname arith
#' @export
setMethod("-", signature("tileIterator", "numeric"), function(e1, e2) {
    e1 + -e2
})

# helpers ####

.DollarNames.tileIterator <- function(x, pattern) {
    c(colnames(x@metadata), "buffer")
}

# x the extent array
# buffer is the value to buffer the tiles by. Can be positive or negative
.do_tile_buffer <- function(x, buffer = 0) {
    x[[1L]] <- x[[1L]] - buffer
    x[[2L]] <- x[[2L]] + buffer
    x[[3L]] <- x[[3L]] - buffer
    x[[4L]] <- x[[4L]] + buffer
    x
}

# zero out the buffer increase
.tile_buffer_zero <- function(x, buffer = 0) {
    x[[1L]] <- x[[1L]] + buffer
    x[[2L]] <- x[[2L]] + buffer
    x[[3L]] <- x[[3L]] + buffer
    x[[4L]] <- x[[4L]] + buffer
    x
}

.spat_tile_bounds <- function(x, i, j) {
    tile_dims <- x@tile_dims
    e <- ext(x)
    offset <- c(terra::ymin(e), terra::xmin(e))
    checkmate::assert_integerish(i, len = 1L)
    checkmate::assert_integerish(j, len = 1L)
    c(
        tile_dims[[2L]] * (j - 1L) + offset[[2L]],
        tile_dims[[2L]] * j + offset[[2L]],
        tile_dims[[1L]] * (i - 1L) + offset[[1L]],
        tile_dims[[1L]] * i + offset[[1L]]
    )
}

#' @name .preview_chunk_plan
#' @title Plot a preview of the chunk plan
#' @description
#' Plots the output from \code{\link{.chunk_plan}} as a set of polygons to preview.
#' Can be useful for debugging. Invisibly returns the planned chunks as a SpatVector
#' of polygons
#' @param extent_list list of extents from \code{.chunk_plan}
#' @keywords internal
#' @noRd
.preview_chunk_plan <- function(extent_list, values, mode = c("poly", "bound"), flip = FALSE, ...) {
    checkmate::assert_logical(flip)
    extent_list <- lapply(extent_list, ext)
    mode <- match.arg(mode, choices = c("poly", "bound"))

    if (flip) {
        extent_list <- lapply(extent_list, function(e) {
            d <- (2 * terra::ymin(e)) + range(e)[["y"]]
            terra::shift(e, dy = -d)
        })
    }

    switch(mode,
        "poly" = {
            poly_list <- sapply(extent_list, terra::as.polygons)
            poly_bind <- do.call(rbind, poly_list)
            terra::plot(poly_bind, values = values, col = hcl.colors(100), ...)
            return(invisible(poly_bind))
        },
        "bound" = {
            xlim <- c(extent_list[[1]]$xmin, extent_list[[length(extent_list)]]$xmax)
            ylim <- c(extent_list[[1]]$ymin, extent_list[[length(extent_list)]]$ymax)
            # initiate plot
            plot(x = NULL, y = NULL, asp = 1L, xlim = xlim, ylim = ylim, ...)
            # plot extent bounds
            for (e in extent_list) {
                rect(e$xmin, e$ymin, e$xmax, e$ymax)
            }
            return(invisible())
        }
    )
}

# x: tileIterator or matrix-like
# i: row index
# j: col index
# expand_grid: logical. Whether to run expand.grid on i and j input. Good for
#   i,j inputs, but should not be used when the ij inputs are paired already.
# tile_fun: function. Function to calculate the tile bounds from:
#   - x
#   - tile i, j
#
# fun: function. Function to run on the output bounds as post-processing
#   (e.g. ext())
# zero: logical. Whether to zero out buffer effects.
.extract_ij_tile <- function(x, i, j,
    expand_grid = TRUE,
    tile_fun = .spat_tile_bounds,
    fun = function(x) x,
    zero = FALSE) {
    if (isTRUE(expand_grid)) {
        var_tab <- expand.grid(i, j)
        i <- var_tab$Var1
        j <- var_tab$Var2
    }

    .mapply(function(i, j) {
        e <- tile_fun(x, i, j)
        e <- .do_tile_buffer(e, x@buffer)
        if (isTRUE(zero)) e <- .tile_buffer_zero(e, x@buffer)
        e <- fun(e)
        # attach metadata
        n <- .ij_to_tile_idx(x, i, j)
        meta <- as.list(x@metadata)
        for (metadata in names(meta)) {
            attr(e, metadata) <- meta[[metadata]][n]
        }
        e
    }, list(i, j), MoreArgs = NULL)
}


