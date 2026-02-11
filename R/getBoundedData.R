#' @include generics.R

# docs ####

#' @name getBoundedData
#' @title Get Data Within Bounds
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
#' @param tiles `tile*` object. Only needed if `extend = TRUE` for the contained
#' tiledims and padding information.
#' @export
setMethod(
    "getBoundedData", signature("SpatRaster", "numeric"),
    function(x, bound, tiles, extend = FALSE, fill = NA) {
        # get px tile from x as r
        r <- x[bound[[3]]:min(nrow(x), bound[[4]]), # rows (y)
            bound[[1]]:min(ncol(x), bound[[2]]), # cols (x)
            drop = FALSE
        ]
        if (!extend) {
            return(r)
        } # return early if not extend

        # handle extend and masking
        pad <- 2 * tiles@pad # since padding is added on both sides
        expected_dim <- c(tiles@tile_dims[[1L]] + pad, tiles@tile_dims[[2L]] + pad)
        if (nrow(r) != expected_dim[[1L]] ||
            ncol(r) != expected_dim[[2L]]) {
            if (extend) {
                bottom_rows <- expected_dim[[1L]] - nrow(r)
                right_cols <- expected_dim[[2L]] - ncol(r)
                r <- terra::extend(r,
                    # left, right, bottom, top
                    c(0, right_cols, bottom_rows, 0),
                    fill = fill
                )
            }
        }
        r
    }
)

#' @rdname getBoundedData
#' @export
setMethod(
    "getBoundedData", signature("SpatRaster", "SpatExtent"),
    function(x, bound) {
        terra::window(x) <- bound
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
