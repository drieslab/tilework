#' @include package_imports.R
#' @include classes.R
#' @include tilePlan.R
#' @include generics.R

# freeTilePlan ####

# * docs ####

#' @name freeTilePlan-class
#' @title Free Tile Plan
#' @description
#' Tile plan defined by explicit per-tile bounds with no required uniformity
#' in size or spacing. Unlike grid-based plans, the bounds matrix is the
#' canonical representation — tile positions are not computed from a formula.
#'
#' The primary use case is adaptive spatial decomposition of vector/point
#' data, where high-density regions require small tiles and sparse regions
#' can use large tiles. See [quadtreePlan()] for the iterative construction
#' workflow.
#'
#' @section Setup:
#' * `freeTilePlan()` creates an empty instance.
#' * `$bounds<-` sets the n x 4 bounds matrix (`xmin, xmax, ymin, ymax`).
#'   Setting bounds triggers reinitialization of `@n`, `@dims`, and
#'   `@metadata`.
#' * `$pad` / `+` / `-` add spatial padding as with other plans.
#'
#' @section Notes:
#' * `@tile_dims` is intentionally not populated. Operations that require
#'   uniform tile dimensions (e.g. `extend = TRUE` in [getTile()]) are not
#'   supported.
#' * `nrow()` returns `n`, `ncol()` returns `1`, `length()` returns `n`.
#' * `plot()` works via the existing spatial extent preview.
#'
#' @examples
#' tp <- freeTilePlan()
#' tp$bounds <- rbind(
#'     c(0,  50,  0,  50),
#'     c(50, 100, 0,  50),
#'     c(0,  50,  50, 100),
#'     c(50, 100, 50, 100)
#' )
#' length(tp)
#' tp[2]
#' plot(tp)
NULL


# * initialize ####

setMethod("initialize", signature("freeTilePlan"), function(.Object, ...) {
    .Object <- callNextMethod(.Object, ...)

    if (length(.Object@n) == 0L)    .Object@n    <- 0L
    if (length(.Object@dims) == 0L) .Object@dims <- c(0L, 1L)
    if (length(.Object@pad) == 0L)  .Object@pad  <- 0

    # return early if bounds not provided
    if (nrow(.Object@bounds) == 0L) return(.Object)

    checkmate::assert_matrix(.Object@bounds, ncols = 4L, mode = "numeric")

    n <- nrow(.Object@bounds)
    .Object@n    <- as.numeric(n)
    .Object@dims <- c(as.integer(n), 1L)

    if (nrow(.Object@metadata) == 0L || nrow(.Object@metadata) != n) {
        .Object@metadata <- data.frame(tile = seq_len(n))
    }

    .Object
})


# * show ####

#' @rdname hidden_docs
#' @export
setMethod("show", signature("freeTilePlan"), function(object) {
    cat("Object of class", class(object), "\n")
    if (nrow(object@bounds) == 0L) {
        cat("<empty>\n")
        return(invisible())
    }
    plist <- list(
        n       = length(object),
        xrange  = sprintf("[%g, %g]", min(object@bounds[, 1L]),
                                      max(object@bounds[, 2L])),
        yrange  = sprintf("[%g, %g]", min(object@bounds[, 3L]),
                                      max(object@bounds[, 4L])),
        pad     = object@pad
    )
    .print_list(plist)
})


# * $ and $<- ####

#' @rdname dollar
#' @export
setMethod("$<-", signature("freeTilePlan", "ANY"), function(x, name, value) {
    if (name == "bounds") {
        if (!is.matrix(value)) value <- as.matrix(value)
        x@bounds <- value
        return(initialize(x))
    }
    callNextMethod()
})

#' @rdname dollar
#' @export
setMethod("$", signature("freeTilePlan"), function(x, name) {
    if (name == "bounds") return(x@bounds)
    callNextMethod()
})

#' @export
.DollarNames.freeTilePlan <- function(x, pattern) {
    c(colnames(x@metadata), "bounds", "pad")
}


# * [ ####

#' @rdname bracket
#' @export
setMethod(
    "[", signature(x = "freeTilePlan", i = "numeric", j = "numeric",
                   drop = "missing"),
    function(x, i, j, ...) {
        callNextMethod(x, i, j, tile_fun = .free_tile_bounds,
                       fun = ext, zero = FALSE, ...)
    }
)


# * plot ####

#' @rdname plot
#' @export
setMethod("plot", signature("freeTilePlan", "missing"), function(x, ...) {
    getMethod("plot", signature("tilePlan", "missing"))(x = x, ...)
})


# * centroids ####

#' @rdname centroids
#' @export
setMethod("centroids", signature("freeTilePlan"), function(x, ...) {
    cx <- (x@bounds[, 1L] + x@bounds[, 2L]) / 2
    cy <- (x@bounds[, 3L] + x@bounds[, 4L]) / 2
    terra::vect(cbind(cx, cy), type = "points")
})


# factory ####

#' @name freeTilePlan
#' @title Create a Fluid Tile Plan
#' @description
#' Create an empty `freeTilePlan`. Populate bounds via `$bounds<-` or use
#' [quadtreePlan()] to generate adaptive bounds automatically.
#' @param ... additional params passed to `new()`.
#' @seealso [quadtreePlan()], [freeTilePlan-class]
#' @export
freeTilePlan <- function(...) {
    new("freeTilePlan", ...)
}


# redispatch ####

#' @rdname redispatch_tileapply
#' @export
setMethod(
    "redispatch_tileapply", signature("SpatRaster", "freeTilePlan"),
    function(sig, tiles, ...) {
        f <- terra::sources(sig)
        f <- unique(f)
        .guard_disk_terra_raster(f)
        e <- .ext_to_num_vec(ext(sig))
        callNextMethod(f, tiles,
            default_get_params = list(
                prefer = "raster",
                ext    = e
            ),
            ...
        )
    }
)


# quadtreePlan ####

#' @name quadtreePlan
#' @title Adaptive Quadtree Tile Plan
#' @description
#' Iteratively subdivides a spatial extent into a `freeTilePlan` by running
#' `FUN` on each tile and splitting any tile whose value exceeds `threshold`.
#' Uses `tileApply()` internally so each pass can be parallelised via
#' [future::plan()].
#'
#' `FUN` must return a single numeric scalar per tile — typically a point
#' count, density, or variance measure. Tiles are split into four equal
#' quadrants until all tiles are either below `threshold` or smaller than
#' `min_tile_size`.
#'
#' @param x input data (e.g. `SpatVector` or file path).
#' @param tiles starting `tilePlan`. Defines the initial coarse grid.
#' @param FUN function. Applied to each tile; must return a single numeric.
#' @param threshold numeric. Tiles with `FUN(tile) > threshold` are subdivided.
#' @param min_tile_size numeric. Minimum tile side length (in CRS units).
#'   Tiles below this size are kept as leaves regardless of density.
#' @param max_depth integer (default `10L`). Maximum subdivision depth.
#' @param ... additional params passed to `tileApply()`.
#' @returns A `freeTilePlan` with an `n_records` metadata column containing
#'   the last `FUN` value for each leaf tile.
#' @examples
#' # dummy data
#' pts <- terra::vect(cbind(x = rnorm(1000, 0, 100), y = rnorm(1000, 0, 100)))
#' pts <- rbind(pts, terra::shift(pts, dx = 1000, dy = 1000))
#' plot(pts)
#' # data must exist on disk
#' f <- tempfile(fileext = "shp")
#' terra::writeVector(pts, f)
#' pts <- terra::vect(f, proxy = TRUE)
#'
#' # coarse starting grid
#' tp <- tilePlan("spatial")
#' ext(tp) <- ext(pts)
#' length(tp) <- 4L
#'
#' fp <- quadtreePlan(
#'     x            = pts,
#'     tiles        = tp,
#'     FUN          = function(x) length(x),  # point count per tile
#'     threshold    = 500L,
#'     min_tile_size = 1
#' )
#' plot(fp)
#' # plot with items per tile
#' plot(fp, values = "n_records")
#' @export
quadtreePlan <- function(x, tiles, FUN, threshold, min_tile_size = NULL,
                          max_depth = 10L, ...) {
    checkmate::assert_number(threshold)
    checkmate::assert_number(min_tile_size, null.ok = TRUE)
    checkmate::assert_integerish(max_depth, len = 1L, lower = 1L)

    # collect starting extents
    pending <- tiles[]
    leaves  <- list()
    leaf_measures <- numeric(0L)
    depth   <- 0L

    while (length(pending) > 0L && depth < max_depth) {
        depth <- depth + 1L

        # build a freeTilePlan for this pass
        bounds_mat <- do.call(rbind, lapply(pending, .ext_to_num_vec))
        fp <- freeTilePlan()
        fp$bounds <- bounds_mat

        # measure each tile
        measures <- unlist(tileApply(x, tiles = fp, FUN = FUN, ...))

        next_pending <- list()
        for (i in seq_along(pending)) {
            e <- pending[[i]]
            too_small <- !is.null(min_tile_size) &&
                min(.tile_ext_dims(e)) <= min_tile_size

            if (measures[[i]] <= threshold || too_small) {
                leaves <- c(leaves, list(e))
                leaf_measures <- c(leaf_measures, measures[[i]])
            } else {
                next_pending <- c(next_pending, .subdivide_extent(e))
            }
        }
        pending <- next_pending
    }

    # remaining pending hit max_depth — measure once more then keep as leaves
    if (length(pending) > 0L) {
        bounds_mat <- do.call(rbind, lapply(pending, .ext_to_num_vec))
        fp <- freeTilePlan()
        fp$bounds <- bounds_mat
        pending_measures <- unlist(tileApply(x, tiles = fp, FUN = FUN, ...))
        leaves <- c(leaves, pending)
        leaf_measures <- c(leaf_measures, pending_measures)
    }

    bounds_mat <- do.call(rbind, lapply(leaves, .ext_to_num_vec))

    # merge neighboring leaf tiles whose combined count stays <= threshold
    merged <- .merge_rect_tiles(bounds_mat, leaf_measures, threshold)

    fp <- freeTilePlan()
    fp$bounds <- merged$bounds
    fp$n_records <- merged$measures
    fp
}


# helpers ####

.free_tile_bounds <- function(x, i, j) {
    # j is always 1 (dims = c(n, 1)); ignored
    x@bounds[i, ]
}

.subdivide_extent <- function(e) {
    xmin <- terra::xmin(e); xmax <- terra::xmax(e)
    ymin <- terra::ymin(e); ymax <- terra::ymax(e)
    xmid <- (xmin + xmax) / 2
    ymid <- (ymin + ymax) / 2
    list(
        terra::ext(xmin, xmid, ymid, ymax),
        terra::ext(xmid, xmax, ymid, ymax),
        terra::ext(xmin, xmid, ymin, ymid),
        terra::ext(xmid, xmax, ymin, ymid)
    )
}

.tile_ext_dims <- function(e) {
    c(terra::xmax(e) - terra::xmin(e),
      terra::ymax(e) - terra::ymin(e))
}

# Greedily merge pairs of tiles that share a full edge and whose combined
# measure stays <= threshold. Repeats until no further merges are possible.
# bounds_mat: n x 4 (xmin, xmax, ymin, ymax); measures: length-n numeric.
.merge_rect_tiles <- function(bounds_mat, measures, threshold) {
    repeat {
        n <- nrow(bounds_mat)
        merged <- FALSE
        for (i in seq_len(n - 1L)) {
            for (j in seq(i + 1L, n)) {
                if (measures[i] + measures[j] > threshold) next
                b <- .try_merge_bounds(bounds_mat[i, ], bounds_mat[j, ])
                if (is.null(b)) next
                bounds_mat[i, ]   <- b
                measures[i]       <- measures[i] + measures[j]
                bounds_mat        <- bounds_mat[-j, , drop = FALSE]
                measures          <- measures[-j]
                merged <- TRUE
                break
            }
            if (merged) break
        }
        if (!merged) break
    }
    list(bounds = bounds_mat, measures = measures)
}

# Returns the merged bounding vector if a and b share a complete edge and
# together form a rectangle, otherwise NULL.
# a, b: c(xmin, xmax, ymin, ymax)
.try_merge_bounds <- function(a, b) {
    tol <- .Machine$double.eps^0.5
    # horizontal neighbours: same y range, touching x edges
    if (abs(a[3L] - b[3L]) < tol && abs(a[4L] - b[4L]) < tol) {
        if (abs(a[2L] - b[1L]) < tol) return(c(a[1L], b[2L], a[3L], a[4L]))
        if (abs(b[2L] - a[1L]) < tol) return(c(b[1L], a[2L], a[3L], a[4L]))
    }
    # vertical neighbours: same x range, touching y edges
    if (abs(a[1L] - b[1L]) < tol && abs(a[2L] - b[2L]) < tol) {
        if (abs(a[4L] - b[3L]) < tol) return(c(a[1L], a[2L], a[3L], b[4L]))
        if (abs(b[4L] - a[3L]) < tol) return(c(a[1L], a[2L], b[3L], a[4L]))
    }
    NULL
}
