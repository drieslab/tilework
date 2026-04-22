#' @include classes.R
#' @include tilePlan.R

#' @name intersect
#' @title Find tiles intersecting a spatial region
#' @description
#' Return a `tileSelection` of tiles whose padded bounds intersect the query
#' region `y`. Tile indices are available via `$tile` on the result.
#'
#' Accepts any object coercible via `ext()` for an axis-aligned query, or a
#' `SpatVector` polygon for an exact query (e.g. a back-projected parallelogram
#' from a rotated affine crop).
#'
#' For `SpatVector` input, an AABB pre-cull is applied first, then exact
#' polygon-rectangle intersection is tested on candidates via `terra::relate()`.
#'
#' `spatialTilePlan` uses an analytic grid formula for the AABB case (O(1)
#' range computation). `freeTilePlan` uses a vectorized bounds check. All
#' other `tilePlan` subclasses fall back to building polygons via `as.polygons()`.
#' @param x `tilePlan`-inheriting object
#' @param y spatial query -- any object coercible via `ext()`, or a `SpatVector`
#'   polygon
#' @returns `tileSelection`. Use `$tile` to access tile indices.
#' @family tile* methods
#' @examples
#' # spatialTilePlan -- axis-aligned query
#' tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 16)
#' e <- ext(20, 60, 20, 60)
#' sel <- intersect(tp, e)
#' sel$tile          # indices of intersecting tiles
#' length(sel)       # number of tiles hit
#' plot(sel)
#' plot(e, add = T, border = "cyan")
#'
#' # with padding -- tiles near the border are included
#' tp_pad <- tp + 5
#' sel_pad <- intersect(tp_pad, terra::ext(20, 60, 20, 60))
#' length(sel_pad) >= length(sel)  # TRUE: padding pulls in border tiles
#'
#' # freeTilePlan -- quadtree bounds
#' fp <- freeTilePlan()
#' fp$bounds <- rbind(
#'     c(0,  50,  0,  50),
#'     c(50, 100, 0,  50),
#'     c(0,  50,  50, 100),
#'     c(50, 100, 50, 100)
#' )
#' intersect(fp, terra::ext(40, 60, 40, 60))$tile  # all 4 tiles touch the centre
#'
#' # SpatVector polygon query (e.g. back-projected rotated crop)
#' corners <- rbind(c(30, 10), c(70, 10), c(90, 50), c(10, 50), c(30, 10))
#' poly <- terra::vect(corners, type = "polygons")
#' sel_poly <- intersect(tp, poly)
#' sel_poly$tile
#' plot(sel_poly)
#' plot(poly, add = T, border = "cyan")
NULL


# helpers ####

# Exact polygon-rectangle intersection on a pre-built candidate SpatVector.
# Returns tileSelection of hits.
.intersect_poly_exact <- function(x, tile_sv, y, candidates) {
    hits <- as.logical(terra::relate(tile_sv, y, relation = "intersects"))
    x[candidates[hits], drop = FALSE]
}


# tilePlan base -- general fallback via as.polygons ####

#' @rdname intersect
#' @export
setMethod("intersect", signature("tilePlan", "ANY"), function(x, y) {
    if (length(x) == 0L) return(x[integer(0L), drop = FALSE])
    tile_sv <- as.polygons(x)
    query_sv <- if (inherits(y, "SpatVector")) y else terra::as.polygons(ext(y))
    .intersect_poly_exact(x, tile_sv, query_sv, seq_len(length(x)))
})


# freeTilePlan ####

#' @rdname intersect
#' @export
setMethod("intersect", signature("freeTilePlan", "ANY"), function(x, y) {
    if (nrow(x@bounds) == 0L) return(x[integer(0L), drop = FALSE])
    if (inherits(y, "SpatVector")) {
        candidates <- intersect(x, ext(y))@indices
        if (length(candidates) == 0L) return(x[integer(0L), drop = FALSE])
        p <- x@pad; b <- x@bounds[candidates, , drop = FALSE]
        bounds <- cbind(b[, 1L] - p, b[, 2L] + p, b[, 3L] - p, b[, 4L] + p)
        tile_sv <- .tile_bounds_to_sv(bounds, ids = candidates)
        return(.intersect_poly_exact(x, tile_sv, y, candidates))
    }
    q <- .ext_to_num_vec(ext(y))
    p <- x@pad; b <- x@bounds
    idx <- which(
        b[, 1L] - p <= q[[2L]] &
        b[, 2L] + p >= q[[1L]] &
        b[, 3L] - p <= q[[4L]] &
        b[, 4L] + p >= q[[3L]]
    )
    x[idx, drop = FALSE]
})


# spatialTilePlan ####

#' @rdname intersect
#' @export
setMethod("intersect", signature("spatialTilePlan", "ANY"), function(x, y) {
    if (length(x) == 0L) return(x[integer(0L), drop = FALSE])
    if (inherits(y, "SpatVector")) {
        candidates <- intersect(x, ext(y))@indices
        if (length(candidates) == 0L) return(x[integer(0L), drop = FALSE])
        ij <- .tile_idx_to_ij(x, candidates)
        i_idx <- ij[[1L]]; j_idx <- ij[[2L]]
        w <- x@tile_dims[[2L]]; h <- x@tile_dims[[1L]]
        p <- x@pad; e <- x@extent
        bounds <- cbind(
            e[[1L]] + (j_idx - 1L) * w - p,
            e[[1L]] +  j_idx       * w + p,
            e[[3L]] + (i_idx - 1L) * h - p,
            e[[3L]] +  i_idx       * h + p
        )
        tile_sv <- .tile_bounds_to_sv(bounds, ids = candidates)
        return(.intersect_poly_exact(x, tile_sv, y, candidates))
    }
    q <- .ext_to_num_vec(ext(y))
    e <- x@extent
    w <- x@tile_dims[[2L]]; h <- x@tile_dims[[1L]]
    p <- x@pad
    j_min <- max(1L, ceiling((q[[1L]] - e[[1L]] - p) / w))
    j_max <- min(ncol(x), floor((q[[2L]] - e[[1L]] + p) / w) + 1L)
    i_min <- max(1L, ceiling((q[[3L]] - e[[3L]] - p) / h))
    i_max <- min(nrow(x), floor((q[[4L]] - e[[3L]] + p) / h) + 1L)
    if (j_min > j_max || i_min > i_max) return(x[integer(0L), drop = FALSE])
    idx <- as.integer(.ij_to_tile_idx(x,
        i = rep(seq.int(i_min, i_max), each = j_max - j_min + 1L),
        j = rep(seq.int(j_min, j_max), i_max - i_min + 1L)
    ))
    x[idx, drop = FALSE]
})
