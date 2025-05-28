#' @include package_imports.R

#' @name tileIterator
#' @title Create a Tile Iterator
#' @param type character. One of "spatial", "pixel". Type of iterator to create.
#' @param ... additional params to pass to `new()` call.
#' @examples
#' tileIterator("spatial")
#' tileIterator("pixel")
#' @seealso [spatialTileIterator] and [pixelTileIterator] classes
#' @export
tileIterator <- function(type = c("spatial", "pixel"), ...) {
    type <- match.arg(type, choices = c("spatial", "pixel"))
    switch(type,
           "spatial" = new("spatialTileIterator", ...),
           "pixel" = new("pixelTileIterator", ...)
    )
}

#' @export
setMethod("$<-", signature("tileIterator", "ANY"), function(x, name, value) {
    if (name == "buffer") {
        x@buffer <- value
        return(initialize(x))
    }
    x@metadata[[name]] <- value
    x
})

#' @export
setMethod("$", signature("tileIterator"), function(x, name) {
    if (name == "buffer") return(x@buffer)
    x@metadata[[name]]
})

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

#' @export
setMethod("nrow", signature("tileIterator"), function(x) {
    x@dims[[1L]]
})

#' @export
setMethod("ncol", signature("tileIterator"), function(x) {
    x@dims[[2L]]
})

#' @export
setMethod("length", signature("tileIterator"), function(x) {
    prod(x@dims)
})

#' @export
setMethod("dim", signature("tileIterator"), function(x) {
    c(nrow(x), ncol(x))
})

#' @export
setMethod("[", signature(x = "tileIterator", i = "numeric", j = "missing", drop = "missing"), function(x, i, ..., drop) {
    i <- as.integer(i)
    if (any(i > length(x) | i <= 0)) stop("tileIterator: subscript out of bounds", call. = FALSE)
    ij <- .tile_idx_to_ij(x, i)
    x[ij[[1L]], ij[[2L]], expand_grid = FALSE, ...] # pass to numeric/numeric method
})

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



#' @export
setMethod("[", signature(x = "tileIterator", i = "missing", j = "missing", drop = "missing"), function(x) {
    x[seq_len(length(x))] # pass to numeric/missing method
})

#' @export
setMethod("[[", signature("tileIterator", i = "numeric", j = "missing"), function(x, i, j, ...) {
    x@metadata[i, ]
})

#' @export
setMethod("+", signature("tileIterator", "numeric"), function(e1, e2) {
    e1@buffer <- e1@buffer + e2
    e1
})

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


