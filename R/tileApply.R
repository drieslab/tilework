#' @include generics.R
#' @include tilePlan.R
#' @include pixelTilePlan.R
#' @include spatialTilePlan.R
#' @include tileGroup.R

# docs ####

#' @name extending_giottotile
#' @title Extending GiottoTile
#' @description
#' GiottoTile provides an extensible framework for:
#'
#' * [tile planning][tilePlan-class]
#' * [tile selection][tileGroup-class]
#' * [batch iteration][tileIterator-class]
#' * [parallelized data processing][tileApply]
#'
#' @section Data flow:
#'
#' The framework accesses and processes data according to the following flow:
#'
#' 1. `tileApply(x, tiles, ...)` # operate across tiles
#' 2. `getTile(x, tiles, ..., get_params)` # get data for tiles
#'    1. `bounds <- tiles[...]` # generate bounds info
#'    2. `getBoundedData(x, bounds, get_params)` # data extraction
#'
#' Expanded roles:
#' * [tileApply()]-  handles the function parallelization strategy and logic.
#' * [getTile()] - deals with any interactions between the data type and the tile
#'  indexing. Operations that should be performed before extraction of the
#'  actual data by tile bounds should happen at this level.
#' * [getBoundedData()] - performs the low-level data extraction from the data
#'  source, provided with a set of bounds information (commonly a `SpatExtent` or
#'  `numeric` of `c(xmin, xmax, ymin, ymax)`)
#'
#' @section Adding new data type support:
#'
#' {GiottoTile} functionalities can be extended to work with  other data
#' types/backends by creating a [getBoundedData()] method for the data type.
#' Optional additional steps:
#'
#' * Method for [tileApply()] should also be added if there are pre-run
#' validation/data collection steps needed.
#' * Method for [getTile()] should be added if there are operations that affect
#' data/tile interactions.
#' @examples
#' if (FALSE) {
#'     # Extending for a custom data type:
#'     setMethod(
#'         "getBoundedData", signature("MyDataType", "SpatExtent"),
#'         function(x, bound) {
#'             # Your data extraction logic here
#'             my_extract_function(x, bound)
#'         }
#'     )
#' }
NULL

#' @name redispatch_tileapply
#' @title *Developer API* Redispatch for `tileApply()`
#' @description
#' Utility generic for modifying `tileApply()` calls for streamlining extension
#' with new datatypes and forcing datatype-specific handling to be added in the
#' expected order.
#'
#' **Why**
#'
#' - `tileApply` is a framework function for parallelized computing across tiled
#' data. It allows dispatch on up to 3 signatures (`x`, `y`, and `tile`),
#' allowing flexibility, but at the cost of normally having to deal with
#' combinatorial explosion of methods when extending with a new `x` and `y`
#' datatype. Especially the case when considering compatibility with existing
#' types and specific handling for different `tile` types.
#'
#' - Setting specific methods using the following example dispatch
#' chain is ambiguous, with it being unclear whether 1 or 2 is first and whether
#' both will be reached before 3.
#'
#'     1. `(ANY, myclass, mytiles)`
#'     2. `(myclass, ANY, mytiles)`
#'     3. `(ANY, ANY, mytiles)`
#'
#' `redispatch_tileapply()` solves the above problems by modifying `tileApply()`
#' calls based on the classes of `x` and `y`, appropriate to the provided
#' `tile*` type.
#'
#' This is done by passing `x` or `y` as input `sig` alongside the `tiles` and
#' dispatching on the combination, and properly routing changes when they are
#' `x` or `y` param specific based on the `param_xy`.
#'
#' After a `sig` is processed, it is coerced to the [token-class] class signifying
#' that it is ready for processing and the call is passed back to `tileApply()`
#' which can either proceed with eval or pass back to `redispatch_tileapply` if
#' `y` is also provided.
#'
#' Only when `x` (for single input tileApply()) or `x` and `y` are all of class
#' `token`, does the `tileApply()` call fully evaluate.
#'
#' **The default `ANY`, `ANY` method performs no modifications to the input data
#' or the call.**
#'
#' @section Logic flow between `tileApply()` and `redispatch_tileapply()`:
#'
#' **`x` only case:**
#'
#' 1. `tileApply(ANY, missing, ANY, ...)`
#' 2. `redispatch_tileapply(mydata, mytiles, param_xy = "x", ...)`
#' 3. `redispatch_tileapply(ANY, ANY, param_xy = "x", ...)`
#' 3. `tileApply(token, missing, ANY, ...)`
#' 4. evaluation
#'
#' **`x` and `y` case:**
#'
#' 1. `tileApply(ANY, ANY, ANY)`
#' 2. `redispatch_tileapply(mydata1, mytiles, param_xy = "x")`
#' 3. `redispatch_tileapply(ANY, ANY, param_xy = "x", ...)`
#' 4. `tileApply(token, ANY, ANY)`
#' 5. `redispatch_tileapply(mydata2, mytiles, param_xy = "y")`
#' 6. `redispatch_tileapply(ANY, ANY, param_xy = "y", ...)`
#' 7. `tileApply(token, token, plan)`
#' 8. evaluation
#'
#' **This allows:**
#'
#' * Data type-specific preprocessing, checks, and additional params to be
#' injected into the `tileApply()` call without having to interact with the core
#' `tileApply()` logic for tilewise data selection and parallelization
#' * Avoid duplicating data type-specific handling code for each of the following
#' `tileApply()` signature types:
#'
#'   * `(mydata, missing, tiles)`
#'   * `(mydata, ANY, tiles)`
#'   * `(token, mydata, tiles)`
#'
#' Instead, extending developers only have to provide code for a single
#' `redispatch_tileapply(myclass, tiles)` signature, and
#' `tileApply()` <-> `redispatch_tileapply()` calls will iteratively apply the
#' appropriate preprocessing and x or y routed params.
#'
#' The `x` and `y` routing and `token` coercion are also handled by the
#' `redispatch_tileapply(ANY, ANY)` method.
#'
#' @param sig data type to modify the `tileApply()` call based on.
#' @param tiles tile* object
#' @param param_xy character. Either "x" or "y" which param it is to modify
#'   dispatch on
#' @param default_get_params internal use: list of default `getTile()`
#'   parameters to use with this `sig`, passed from an upstream (likely more
#'   specific) `redispatch_tileapply()` method.
#'
#'   Depending on `param_xy`, this list of defaults will be merged with
#'   `get_params_x` or `get_params_y` in `...`
#'
#'   Duplicate entries in `default_get_params` will be ignored in favor
#'   of `get_params_x` or `get_params_y` contents.
#' @param default_callback internal use: Default callback function passed from an
#'   upstream (likely more specific) `redispatch_tileapply()` method to use
#'   as `callback_x` or `callback_y` if none has been provided.
#' @param verbose verbosity. `TRUE`, `FALSE` or `"debug"` for more info on
#'   stack tracing.
#' @param ... additional params to pass
NULL


#' @name tileApply
#' @title Apply Functions Across Spatial Tiles
#' @description
#' **For more useful params info and examples, see the Tile Processing Methods
#' section.**
#'
#' Apply a function across spatial tiles to speed up processing and manage
#' memory usage for large data operations. This is a landing page for the
#' generic. `tileApply()` dispatches to different processing methods based on
#' the tile type.
#'
#' `character` inputs to `x` and `y` are assumed to be \{terra\} readable.
#' `SpatRaster` and `SpatVector` must first be written to file. If provided,
#' they are traced to their filepaths with [terra::sources()] and then processed
#' via their filepaths for memory efficiency.
#'
#' For other data types, see [extending_giottotile]
#'
#' @section Tile Processing Methods:
#' - **Basic tiling**: See [tileApply-plan] for `spatialTilePlan` and `pixelTilePlan`
#' - **Group processing**: See [tileApply-group] for `tileGroup` hierarchical processing
#' - **Iterator processing**: See [tileApply-iterator] for `tileIterator` streaming/batch processing
#'
#' @param x input data 1
#' @param y input data 2 (optional)
#' @param tiles tile* object (`tilePlan`, `tileGroup`, or `tileIterator`)
#' @param verbose verbosity. `TRUE`, `FALSE` or `"debug"` for more info on
#'   stack tracing.
#' @param ... additional arguments passed to specific methods (one of which is
#' the `FUN` function applied across the tiles.)
#'
#' @seealso [tileApply-plan], [tileApply-group], [tileApply-iterator]
#' @examples
#' # See specific help pages for detailed examples:
#' # ?`tileApply-plan`     # Basic spatial/pixel tiling
#' # ?`tileApply-group`    # Hierarchical tile groups
#' # ?`tileApply-iterator` # Streaming batch processing
NULL

# methods ####

#' @rdname tileApply
#' @keywords internal
#' @export
setMethod("tileApply", signature("ANY", "missing", "ANY"), function(x, tiles, verbose = NULL, ...) {
    .dmsg(.v = verbose, "[tileApply] x only. Start redispatch x...",
          plist = list(...))
    redispatch_tileapply(x, tiles, param_xy = "x", verbose = verbose, ...)
})

#' @rdname tileApply
#' @keywords internal
#' @export
setMethod("tileApply", signature("ANY", "ANY", "ANY"), function(x, y, tiles, verbose = NULL, ...) {
    .dmsg(.v = verbose, "[tileApply] x and y. Start redispatch x...",
          plist = list(...))
    redispatch_tileapply(x, tiles, y = y, param_xy = "x", verbose = verbose, ...)
})

#' @rdname tileApply
#' @keywords internal
#' @export
setMethod("tileApply", signature("token", "ANY", "ANY"), function(x, y, tiles, verbose = NULL, ...) {
    .dmsg(.v = verbose, "[tileApply] x done. Start redispatch y...",
          plist = list(...))
    redispatch_tileapply(y, tiles, param_xy = "y", x = x, verbose = verbose, ...)
})


# preprocess ####

setAs("ANY", "token", function(from) {
    new("token", data = from)
})

#' @rdname token-class
#' @usage
#' # Flag as being ready for processing
#' x <- as(letters, "token")
#'
#' # Retrieve wrapped data
#' x[]
#' @export
setMethod("[", signature("token", "missing", "missing", "missing"), function(x, ...) {
    x@data
})

#' @rdname redispatch_tileapply
#' @export
setMethod("redispatch_tileapply", signature("ANY", "ANY"), function(
        sig, tiles,
        default_get_params = list(),
        param_xy,
        verbose = NULL,
        ...) {
    checkmate::assert_list(default_get_params)
    param_xy <- match.arg(param_xy, c("x", "y"))
    .dmsg(.v = verbose, "[redispatch] step done. Route as", param_xy, "...")
    # default is no change
    sig <- as(sig, "token")
    # args list
    a <- list(tiles = tiles, verbose = verbose, ...)

    if (param_xy == "x") {
        .dmsg(.v = verbose, .initial = "  ", plist = list(...))
        a$get_params_x <- c(a$get_params_x, default_get_params)
        ns <- names(a$get_params_x)
        a$get_params_x <- a$get_params_x[!duplicated(ns)]
        do.call(tileApply, c(list(x = sig), a))
    } else {
        .dmsg(.v = verbose, .initial = "  ", plist = list(...))
        a$get_params_y <- c(a$get_params_y, default_get_params)
        ns <- names(a$get_params_y)
        a$get_params_y <- a$get_params_y[!duplicated(ns)]
        do.call(tileApply, c(list(y = sig), a))
    }
})


# helpers ####

# x: terra::sources() output
.guard_disk_terra <- function(x, what) {
    if (!any(x == "")) {
        return(invisible())
    }
    stop(call. = FALSE, c("[tileApply] no filepath found for ", what,
        ".\n Please first write to disk."))
}

.guard_disk_terra_raster <- function(x) {
    .guard_disk_terra(x, "raster info")
}

.guard_disk_terra_vector <- function(x) {
    .guard_disk_terra(x, "vector info")
}
