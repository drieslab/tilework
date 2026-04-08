#' @include package_imports.R

# docs ####

#' @name hidden_docs
#' @title Hidden Docs
#' @description
#' Dummy documentation for things that do not need much explanation (like
#' `show` methods)
#' @param object object
#' @keywords internal
NULL

#' @title Get Tile Centroids
#' @name centroids
#' @family tile* methods
#' @description
#' Get the centroids of the tiles. For spatialTilePlan, these will be returned
#' as `SpatVector` centroids. For non-spatial plans like pixelTileGrid, this
#' will be returne as a `matrix`.
#' @param x `tilePlan`
#' @param offset numeric of length 2. x and y values to offset by. Default is
#' c(0, 0).
#' @param fun (internal) post-processing function used to convert centroids to
#' expected output. Such as `vect()` for `spatialTilePlan`
#' @param zero logical. Whether to zero out padding effects. (used by default with
#' `pixelTilePlan`)
#' @param ... additional params to pass.
#' @examples
#' x <- tilePlan()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x) <- 9
#' centroids(x)
NULL

#' @title Get and Set Tile Metadata and Params
#' @name dollar
#' @family tile* methods
#' @description
#' Get and set tile metadata. Some params can also be modified with
#' this operator, for example the `$pad` value or `$pxdims`, `$ncols`, or
#' `$nrows` for `pixelTilePlan`.
#'
#' `$tile` is a default created piece of metadata.
#' @param x `tilePlan`
#' @param name name of item to get or set
#' @param value value to set
#' @examples
#' x <- tilePlan()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x) <- 9
#' x$test <- sprintf("test_value_%d", x$tile)
#' x$test
#' tile_ext <- x[5][[1]]
#' attr(tile_ext, "test")
#' @returns
#' metadata value when using getter or `tile*` object when using the setter
#' function.
NULL

#' @name plot
#' @title Plot a `tilePlan`
#' @family tile* methods
#' @description
#' Plot and preview the tile plan. This is likely to be very slow if there are
#' a lot of tiles (in the neighborhood of >10,000)
#' @param x `tilePlan` to plot
#' @param y not used.
#' @param values character. Metadata item to color tiles as. Default is `"tile"`
#' which produces the tile index.
#' @param color_as_factor logical (default = `FALSE`). Whether to convert `value`
#' to a factor to plot as categorical.
#' @param ... additional params to pass
#' @examples
#' x <- tilePlan()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x) <- 9
#' plot(x)
#'
#' x$new_meta <- rev(head(letters, 9))
#' plot(x, value = "new_meta")
NULL

#' @name dim
#' @title Tile Plan Array Characteristics
#' @aliases nrow ncol length length<-
#' @family tile* methods
#' @description
#' Get dimension characteristics of the `tilePlan` tiling plan. These
#' produce information on how the tiles are arrayed in rows `nrow()`, cols `ncol()`,
#' and total number of tiles `length()`.
#'
#' `length<-()` is a special case and currently only used with `spatialTilePlan`,
#' where it is used to request a minimum number of tiles to generate.
#' @param x `tilePlan` object
#' @param value number of tiles to request
#' @examples
#' x <- tilePlan()
#' ext(x) <- c(0, 100, 0, 100)
#' length(x)
#' length(x) <- 9
#' length(x)
#' dim(x)
#' nrow(x)
#' ncol(x)
#' @returns numeric or `spatialTilePlan` object when using `length<-()`
NULL

#' @name bracket
#' @aliases `[`
#' @title Extract Bounds from Tile Object
#' @family tile* methods
#' @description
#' Get a set of tile bounds from a `tile*` object. Values are always returned as
#' a `list`, even when length one to reduce surprises with `lapply()` usage.
#' @param x `tile*` object
#' @param i numeric vector index if `j` is not given. Row index if `j` is also
#' present. Works like `matrix-like` indexing.
#' @param j numeric. Column index
#' @param tile_fun (internal) function used to define tile bounds based on the
#' iterator object and ij indices.
#' @param fun (internal) post-processing function used to convert bounds to
#' expected output. Such as `ext()` for `spatialTilePlan`
#' @param zero logical. Whether to zero out padding effects. (used by default with
#' `pixelTilePlan`)
#' @param expand_grid logical (internal) whether to use `expand.grid()` on ij
#' indices.
#' @param ... addtional params to pass (not used).
#' @param drop not used.
#' @examples
#' spat <- tilePlan("spatial")
#' ext(spat) <- c(0, 1000, 0, 1000)
#' length(spat) <- 9
#' spat[1]
#' spat[1, 2:3]
#' spat[]
#'
#' px <- tilePlan("pixel")
#' px$pxdims <- c(1000, 1000)
#' px$ncols <- 200
#' px$nrows <- 200
#' px[1]
#' px[2, 2:3]
#' px[]
#' @returns `list` of `numeric` or `SpatExtent` depending on underlying `tilePlan`
NULL

#' @name double_bracket
#' @aliases `[[`
#' @title Get and set metadata
#' @family tile* methods
#' @description
#' `[[` can be used to get the table of metadata for a specific tile.
#' @param x `tilePlan`
#' @param i `integer-like`. tile vector index
#' @param j `character`. Name of metadata information to get
#' @param value `ANY` value to set
#' @param ... not used.
#' @examples
#' spat <- tilePlan("spatial")
#' ext(spat) <- c(0, 1000, 0, 1000)
#' length(spat) <- 9
#' spat[[1]]
#' @seealso [dollar]
#' @returns `data.frame`
NULL

#' @rdname centroids
#' @export
setMethod("centroids", signature("tilePlan"), function(x, fun = function(x) x, offset = c(0, 0), zero = FALSE, ...) {
    .ij_centroid(x, fun = fun, offset = offset, zero = zero, ...)
})

#' @name arith
#' @title Tile Pads
#' @family tile* methods
#' @description
#' Tile padding extends the bounds of the tile beyond the region that
#' they are initially planned for by an equal amount on all 4 sides. This can
#' help with things like spatial contiguity, so that artificial borders are
#' less obvious.
#'
#' Padding can be added either via [`$pad`][dollar] or `+` and `-` operators.
#' The + and - operators specifically modify the padding value based on the
#' arithmetic ops. This is similar to their usage in [terra::Arith-methods]
#'
#' `$stride<-` is an alternative way to set padding via the stride between
#' tile starts: `pad = (tile_dim - stride) / 2`. Requires `tile_dims` to be
#' set (i.e. not `freeTilePlan`). `$stride` returns the effective stride given
#' the current pad.
#'
#' @section spatial and pixel differences:
#'
#' * Padding for spatial tile plans is added without any further changes.
#' * Padding for pixel tile plans are automatically zeroed out against the top
#' left
#' @param e1 `tilePlan`
#' @param e2 `numeric` to add to padding value
#' @examples
#' spat <- tilePlan("spatial")
#' ext(spat) <- c(0, 1000, 0, 1000)
#' length(spat) <- 9
#' plot(spat)
#' spat[1:3]
#' spat <- spat + 10
#' plot(spat)
#' spat[1:3]
#'
#' px <- tilePlan("pixel")
#' px$pxdims <- c(1000, 1000)
#' px$ncols <- 100
#' px$nrows <- 100
#' plot(px)
#' px[1:3]
#' px <- px + 5
#' plot(px)
#' px[1:3]
#' @returns `tilePlan`
NULL

#' @name ext
#' @title Get and Set Spatial Extent
#' @aliases ext<-
#' @family tile* methods
#' @description
#' Get and set a spatial extent.
#' @param x `tilePlan`
#' @param ... addtional params to pass (none implemented)
#' @param value `numeric` of length 4 or `SpatExtent` defining spatial extent.
#' @returns tilePlan if `ext<-()` and `SpatExtent` if `ext()`
NULL

#' @name tilePlan
#' @title Create a Tiling Plan
#' @family tile plans
#' @param type character. One of `"spatial"`, `"pixel"`. Type of plan to create.
#' @param ... additional params to pass to `new()` call.
#' @examples
#' tilePlan("spatial")
#' tilePlan("pixel")
#' @seealso [spatialTilePlan] and [pixelTilePlan] classes
NULL


# factory ####

#' @rdname tilePlan
#' @export
tilePlan <- function(type = c("spatial", "pixel"), ...) {
    type <- match.arg(type, choices = c("spatial", "pixel"))
    switch(type,
        "spatial" = new("spatialTilePlan", ...),
        "pixel" = new("pixelTilePlan", ...)
    )
}

#' @rdname pointTilePlan-class
#' @param input character. Coordinate space of coords, dims, and padding:
#'   `"spatial"` for CRS units, `"pixel"` for pixel indices.
#' @param output character. Bound type returned by [getTile()]. Defaults to
#'   `input`. Cross-mode conversion requires a `SpatRaster` at [getTile()] time
#'   (or `@rast_dims`/`@extent` set on the plan for standalone use).
#' @export
pointTilePlan <- function(input = c("spatial", "pixel"),
                          output = input,
                          ...) {
    input  <- match.arg(input)
    output <- match.arg(output, c("spatial", "pixel"))
    new("pointTilePlan", input = input, output = output, ...)
}

#' @rdname dollar
#' @export
setMethod("$<-", signature("tilePlan", "ANY"), function(x, name, value) {
    if (name == "pad") {
        x@pad <- value
        return(initialize(x))
    }
    if (name == "stride") {
        checkmate::assert_numeric(value, min.len = 1L, max.len = 2L)
        if (length(x@tile_dims) == 0L)
            stop("$stride requires tile_dims to be set", call. = FALSE)
        dims <- rep_len(x@tile_dims, 2L)
        stride <- rep_len(value, 2L)
        x@pad <- mean((dims - stride) / 2)
        return(initialize(x))
    }
    x@metadata[[name]] <- value
    x
})

#' @rdname dollar
#' @export
setMethod("$", signature("tilePlan"), function(x, name) {
    if (name == "pad") {
        return(x@pad)
    }
    if (name == "stride") {
        if (length(x@tile_dims) == 0L) return(NULL)
        return(x@tile_dims - 2 * x@pad)
    }
    x@metadata[[name]]
})

#' @rdname plot
#' @export
setMethod(
    "plot", signature(x = "tilePlan", y = "missing"),
    function(x, values = "tile", color_as_factor = FALSE, ...) {
        p <- list(...)
        if (length(x) == 0L) {
            stop("No tiles to plot.\nTry requesting tiles with `length()`")
        }
        values <- x@metadata[[values]]
        if (isTRUE(color_as_factor)) values <- as.factor(values)
        p$values <- values
        p$extent_list <- x[]

        if (x@pad > 0) {
            p$alpha <- p$alpha %||% 0.3
        }

        do.call(.preview_chunk_plan, args = p)
    }
)

#' @rdname dim
#' @export
setMethod("nrow", signature("tilePlan"), function(x) {
    x@dims[[1L]]
})

#' @rdname dim
#' @export
setMethod("ncol", signature("tilePlan"), function(x) {
    x@dims[[2L]]
})

#' @rdname dim
#' @export
setMethod("length", signature("tilePlan"), function(x) {
    as.integer(prod(x@dims))
})

#' @rdname dim
#' @export
setMethod("dim", signature("tilePlan"), function(x) {
    c(nrow(x), ncol(x))
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tilePlan", i = "numeric", j = "missing", drop = "missing"), function(x, i, ..., drop) {
    i <- as.integer(i)
    if (any(is.na(i))) stop("[tilePlan] i index may not be NA", call. = FALSE)
    if (nargs() - length(list(...)) == 3L) {
        # row case
        if (any(i > nrow(x) | i <= 0)) stop("[tilePlan] subscript out of bounds", call. = FALSE)
        return(x[i, j = seq_len(ncol(x)), expand_grid = TRUE, ...]) # pass to numeric/numeric method
    }
    # flat case
    if (any(i > length(x) | i <= 0)) stop("[tilePlan] subscript out of bounds", call. = FALSE)
    ij <- .tile_idx_to_ij(x, i)
    x[ij[[1L]], ij[[2L]], expand_grid = FALSE, ...] # pass to numeric/numeric method
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tilePlan", i = "missing", j = "numeric", drop = "missing"), function(x, i, j, ..., drop) {
    j <- as.integer(j)
    x[i = seq_len(nrow(x)), j, expand_grid = TRUE, ...]
})

#' @rdname bracket
#' @export
setMethod(
    "[", signature(x = "tilePlan", i = "numeric", j = "numeric", drop = "missing"),
    function(x, i, j, tile_fun = .spat_tile_bounds, fun = function(x) x, zero = FALSE, expand_grid = TRUE, drop) {
        .extract_ij_tile(x, i, j,
            expand_grid = expand_grid,
            tile_fun = tile_fun,
            fun = fun,
            zero = zero
        )
    }
)

#' @rdname bracket
#' @usage
#' ## S4 method for signature 'tilePlan,missing,missing,missing'
#' x[]
#' @export
setMethod("[", signature(x = "tilePlan", i = "missing", j = "missing", drop = "missing"), function(x, i, j) {
    x[seq_len(length(x))] # pass to numeric/missing method
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tilePlan", i = "numeric", j = "missing", drop = "logical"), function(x, i, ..., drop) {
    checkmate::assert_integerish(i)
    dots <- list(...)
    if ("expand_grid" %in% names(dots)) {
        stop("[tilePlan] expand_grid param not allowed when j is missing")
    }
    if (length(dots) > 0) {
        warning("[tilePlan] ... params are not passed when drop = FALSE")
    }
    if (nargs() - length(dots) == 4) {
        # row case
        j <- seq_len(ncol(x))
        if (drop) return(x[i, j = j, expand_grid = TRUE, ...])
        return(x[i, j, expand_grid = TRUE, drop = FALSE])
    }
    # flat case
    if (drop) return(x[i, ...])
    if (any(i > length(x) | i <= 0)) stop("[tilePlan] subscript out of bounds\n", call. = FALSE)
    new("tileSelection", tp = x, indices = as.integer(i))
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tilePlan", i = "missing", j = "numeric", drop = "logical"), function(x, i, j, ..., drop) {
    if (drop) return(x[, j = j, ...])
    dots <- list(...)
    if ("expand_grid" %in% names(dots)) {
        stop("[tilePlan] expand_grid param not allowed when i is missing")
    }
    if (length(dots) > 0) {
        warning("[tilePlan] ... params are not passed when drop = FALSE")
    }
    checkmate::assert_integerish(j)
    x[i = seq_len(nrow(x)), j, expand_grid = TRUE, drop = FALSE]
})

#' @rdname bracket
#' @export
setMethod(
    "[", signature(x = "tilePlan", i = "numeric", j = "numeric", drop = "logical"),
    function(x, i, j, expand_grid = TRUE, ..., drop) {
        if (drop) return(x[i, j, expand_grid = expand_grid, ...])
        dots <- list(...)
        if (length(dots) > 0) {
            warning("[tilePlan] ... params are not passed when drop = FALSE")
        }
        checkmate::assert_integerish(i)
        checkmate::assert_integerish(j)
        if (isTRUE(expand_grid)) {
            var_tab <- expand.grid(j, i) # j/i switch is intentional
            i <- var_tab$Var2
            j <- var_tab$Var1
        }
        i_final <- .ij_to_tile_idx(x, i, j)
        x[i_final, drop = FALSE]
    }
)

#' @rdname bracket
#' @export
setMethod("[", signature(x = "tilePlan", i = "missing", j = "missing", drop = "logical"), function(x, i, j, drop) {
    if (drop) return(x[])
    x[seq_len(length(x)), drop = FALSE] # pass to numeric/missing method
})

#' @rdname double_bracket
#' @export
setMethod("[[", signature("tilePlan", i = "numeric", j = "missing"), function(x, i, j, ...) {
    x@metadata[i, , drop = FALSE]
})

#' @rdname double_bracket
#' @export
setMethod("[[", signature("tilePlan", i = "missing", j = "missing"), function(x, i, j, ...) {
    x@metadata
})

#' @rdname double_bracket
#' @export
setMethod("[[", signature("tilePlan", i = "missing", j = "character"), function(x, i, j, ...) {
    x@metadata[, j, drop = FALSE]
})

#' @rdname double_bracket
#' @export
setMethod("[[", signature("tilePlan", i = "numeric", j = "character"), function(x, i, j, ...) {
    x@metadata[i, j, drop = FALSE]
})

#' @rdname double_bracket
#' @export
setMethod("[[<-", signature("tilePlan", i = "numeric", j = "character", value = "ANY"), function(x, i, j, ..., value) {
    x@metadata[i, j] <- value
    x
})

#' @rdname double_bracket
#' @export
setMethod("[[<-", signature("tilePlan", i = "missing", j = "character", value = "ANY"), function(x, i, j, ..., value) {
    x@metadata[, j] <- value
    x
})

#' @rdname arith
#' @export
setMethod("+", signature("tilePlan", "numeric"), function(e1, e2) {
    e1@pad <- e1@pad + e2
    e1
})

#' @rdname arith
#' @export
setMethod("-", signature("tilePlan", "numeric"), function(e1, e2) {
    e1 + -e2
})

# helpers ####

.DollarNames.tilePlan <- function(x, pattern) {
    c(colnames(x@metadata), "pad", "stride")
}

# x: the extent array
# pad: is the value to pad the tiles by. Can be positive or negative
.do_tile_pad <- function(x, pad = 0) {
    x[[1L]] <- x[[1L]] - pad
    x[[2L]] <- x[[2L]] + pad
    x[[3L]] <- x[[3L]] - pad
    x[[4L]] <- x[[4L]] + pad
    x
}

# zero out the pad increase
.tile_pad_zero <- function(x, pad = 0) {
    x[[1L]] <- x[[1L]] + pad
    x[[2L]] <- x[[2L]] + pad
    x[[3L]] <- x[[3L]] + pad
    x[[4L]] <- x[[4L]] + pad
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

# x: tilePlan or matrix-like
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
# zero: logical. Whether to zero out padding effects.
.extract_ij_tile <- function(
        x, i, j,
        expand_grid = TRUE,
        tile_fun = .spat_tile_bounds,
        fun = function(x) x,
        zero = FALSE) {
    if (any(is.na(i))) stop("[tilePlan] i index may not be NA", call. = FALSE)
    if (any(is.na(j))) stop("[tilePlan] j index may not be NA", call. = FALSE)

    if (isTRUE(expand_grid)) {
        var_tab <- expand.grid(j, i) # j/i switch is intentional
        i <- var_tab$Var2
        j <- var_tab$Var1
    }

    .mapply(function(i, j) {
        e <- tile_fun(x, i, j)
        e <- .do_tile_pad(e, x@pad)
        if (isTRUE(zero)) e <- .tile_pad_zero(e, x@pad)
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

.ij_centroid <- function(x, fun = function(x) x, offset = c(0, 0), zero = FALSE) {
    d <- dim(x)[1:2]
    ij <- expand.grid(1:d[[2L]], 1:d[[1L]])
    i <- ij$Var2
    j <- ij$Var1
    tile_dims <- x@tile_dims
    res <- c(
        tile_dims[[2L]] * (j - 0.5) + offset[[2L]],
        tile_dims[[1L]] * (i - 0.5) + offset[[1L]]
    )
    if (zero) res <- res + x@pad
    res <- matrix(res, ncol = 2, byrow = FALSE)
    res <- fun(res)
    res
}
