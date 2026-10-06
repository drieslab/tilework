#' @include generics.R

# docs ####

#' @name getBoundedData
#' @title Get Data Within Bounds
#' @family tile processing
#' @description
#' Subset or otherwise make available only the data that is within the provided
#' bounds. Accepted bounds types depends on the data.
#'
#' A related lower-level function is [getTile()] which handles data/`tile*`
#' interactions and bound info collection. `getTile()` calls this generic
#' for its data selection capabilities.
#'
#' @section Bounds types:
#'
#' Depending on the method, different bound types are used. Current expected
#' patterns are:
#' - `numeric` of length 4 (xmin, xmax, ymin, ymax)
#' - `SpatExtent`
#'
#' @section `SpatRaster` snapping:
#'
#' `getBoundedData()` is implemented for `SpatRaster`, `SpatExtent` using
#' [terra::window()]. This uses terra's default snapping behavior (equivalent to
#' `snap = "near"` in [terra::crop()]), with no way to set another strategy.
#'
#' **For more precise boundary control:**
#' - Use pixel-based indexing via the `SpatRaster`, `numeric` method
#' - Use `pixelTilePlan()` for exact pixel-level tiling
#' - Add padding with `tiles + pad_value` to ensure spatial context
#' - Use [terra::crop()] directly if you need `snap = "out"` or `snap = "in"`
#'
#' @section Boundary Inclusivity:
#'
#' Adjacent tiles share exact boundaries. Since \{tilework\} does not know the
#' format or representation of the underlying data, it does not enforce whether
#' those boundaries are inclusive or exclusive. It is up to the
#' `getBoundedData()` implementation to decide how features on shared edges are
#' handled.
#'
#' The existing \{terra\} methods do not implement inclusive/exclusive boundary
#' control because raster pixel snapping and padding make exact boundary
#' behavior largely irrelevant for that format. For point or tabular data,
#' features on a shared boundary may appear in multiple tiles unless the
#' implementation applies its own filtering (e.g. `>=` vs `>` comparisons).
#' The tile's grid position can be passed via `get_params` from [getTile()] to
#' inform which edges are interior.
#'
#' @param x data
#' @param bound bounds to filter with
#' @param extend logical (default = `FALSE`) whether to extend tile data to reach
#' expected tile dimensions
#' @param fill numeric. if `extend = TRUE`, what value to fill with
#' @examples
#' f <- system.file("ex/elev.tif", package = "terra")
#' r <- terra::rast(f)
#'
#' pixel_selection <- getBoundedData(r, c(10, 50, 30, 40))
#' plot(pixel_selection)
#'
#' extent_selection <- getBoundedData(r, ext(6, 6.5, 49.7, 50))
#' plot(extent_selection)
#'
#' @seealso [getTile()]
NULL

#' @rdname getBoundedData
#' @export
setMethod(
    "getBoundedData", signature("SpatRaster", "numeric"),
    function(x, bound, extend = FALSE, fill = NA) {
        b <- c(
            max(bound[[1L]], 1L),
            min(bound[[2L]], ncol(x)),
            max(bound[[3L]], 1L),
            min(bound[[4L]], nrow(x))
        )
      
        # get px tile from x as r
        r <- x[b[[3L]]:b[[4L]], b[[1L]]:b[[2L]], drop = FALSE]
      
        if (!extend) {
            return(r)
        }
      
        bdiff <- c(
            b[[1L]] - bound[[1L]],
            bound[[2L]] - b[[2L]],
            b[[3L]] - bound[[3L]],
            bound[[4L]] - b[[4L]]
        )

        if (all(bdiff == c(0L, 0L, 0L, 0L))) return(r)

        # `bdiff` extend order: left, right, bottom, top
        r <- terra::extend(r, bdiff, fill = fill)
        r
    }
)

#' @rdname getBoundedData
#' @export
setMethod(
    "getBoundedData", signature("SpatRaster", "SpatExtent"),
    function(x, bound, extend = FALSE, fill = NA) {
        terra::window(x) <- bound
        if (!extend) {
           return(x)
        }
      
        x <- terra::extend(x, bound, fill = fill)
        x
    }
)

#' @rdname getBoundedData
#' @export
setMethod(
    "getBoundedData", signature("SpatVectorProxy", "SpatExtent"),
    function(x, bound) {
        terra::query(x, extent = bound)
    }
)
