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
    x@metadata[[name]] <- value
    x
})

#' @export
setMethod("$", signature("tileIterator"), function(x, name) {
    x@metadata[[name]]
})

#' @export
setMethod(
    "plot", signature(x = "tileIterator", y = "missing"),
    function(x, values = "tile", color_as_factor = FALSE, ...) {
        p <- list(...)
        if (length(x@tiles) == 0L) {
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
    nrow(x@tiles)
})

#' @export
setMethod("ncol", signature("tileIterator"), function(x) {
    res <- ncol(x@tiles)
    if (is.na(res)) {
        res <- 0 # catch for when `x@tiles` is not an array
    }
    return(res)
})

#' @export
setMethod("length", signature("tileIterator"), function(x) {
    nrow(x) * ncol(x)
})

#' @export
setMethod("dim", signature("tileIterator"), function(x) {
    c(nrow(x), ncol(x))
})

#' @export
setMethod("[", signature(x = "tileIterator", i = "numeric", j = "missing", drop = "missing"), function(x, i) {
    i <- as.integer(i)
    if (any(i > length(x) | i <= 0)) stop("tileIterator: subscript out of bounds", call. = FALSE)
    ij <- .tile_idx_to_ij(x, i)
    x[ij[[1]], ij[[2]]] # pass to numeric/numeric method
})

#' @export
setMethod(
    "[<-",
    signature(x = "tileIterator", i = "numeric", j = "missing", value = "numeric"),
    function(x, i, j, ..., value) {
        i <- as.integer(i)
        if (any(i > length(x) | i <= 0)) stop("tileIterator: subscript out of bounds", call. = FALSE)
        ij <- .tile_idx_to_ij(x, i)
        x@tiles[ij[[1]], ij[[2]], ] <- .ext_to_num_vec(value)
        x
    }
)

#' @export
setMethod("[", signature(x = "tileIterator", i = "numeric", j = "numeric", drop = "missing"),
          function(x, i, j, fun = function(x) x, zero = FALSE, drop) {
    x@tiles <- .do_tile_buffer(x@tiles, x@buffer)
    if (zero) x@tiles <- .tile_buffer_zero(x@tiles, x@buffer)
    mapply(function(i, j) {
        n <- ((i - 1) * ncol(x)) + j
        meta <- as.list(x@metadata)
        e <- fun(x@tiles[i, j, ])
        for (metadata in names(meta)) {
            attr(e, metadata) <- meta[[metadata]][n]
        }
        e
    }, i, j, SIMPLIFY = FALSE)
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
    colnames(x@metadata)
}

# x the extent array
# buffer is the value to buffer the tiles by. Can be positive or negative
.do_tile_buffer <- function(x, buffer = 0) {
    x[, , 1L] <- x[, , 1L] - buffer
    x[, , 2L] <- x[, , 2L] + buffer
    x[, , 3L] <- x[, , 3L] - buffer
    x[, , 4L] <- x[, , 4L] + buffer
    x
}

# zero out the buffer increase
.tile_buffer_zero <- function(x, buffer = 0) {
    x[, , 1L] <- x[, , 1L] + buffer
    x[, , 2L] <- x[, , 2L] + buffer
    x[, , 3L] <- x[, , 3L] + buffer
    x[, , 4L] <- x[, , 4L] + buffer
    x
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

.tile_idx_to_ij <- function(x, i) {
    i_idx <- floor(i / ncol(x)) + 1L
    no_resid <- i %% ncol(x) == 0L
    i_idx[no_resid] <- i_idx[no_resid] - 1L
    j_idx <- i %% ncol(x)
    j_idx[j_idx == 0L] <- ncol(x)
    list(i_idx, j_idx)
}


