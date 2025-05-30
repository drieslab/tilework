
#' @name tileGroup
#' @title Create a Tile Group
#' @description
#' Organize tiles from a tileIterator into hierarchical groups for batch processing.
#' Groups can represent spatial regions, processing stages, or any logical
#' organization of tiles.
#' @param ti A tileIterator object
#' @param groups Named list where each element contains tile indices for that group
#' @param metadata Optional data.frame with group metadata
#' @examples
#' ti <- tileIterator("spatial")
#' ext(ti) <- c(0, 100, 0, 100)
#' length(ti) <- 9
#'
#' # Create groups
#' tg <- tileGroup(ti, groups = list(
#'   "top" = 1:3,
#'   "middle" = 4:6,
#'   "bottom" = 7:9
#' ))
NULL

#' @rdname tileGroup
#' @export
tileGroup <- function(ti, groups = list()) {
    new("tileGroup", ti = ti, groups = groups)
}

setMethod("initialize", signature("tileGroup"), function(.Object, ...) {
    x <- callNextMethod(.Object, ...)
    # Initialize metadata if empty
    if (nrow(x@metadata) == 0 && length(x@groups) > 0) {
        x@metadata <- data.frame(
            group = names(x@groups) %null% paste0("group_", seq_along(x@groups)),
            n_tiles = lengths(x@groups),
            row.names = NULL
        )
    }
    x
})

setMethod("show", signature("tileGroup"), function(object) {
    cat(sprintf("<%s>: %s\n", class(object), class(object@ti)))
    cat(color_yellow("groups----------------------------------\n"))
    print_list(object@groups, pre = "  ")
})

setMethod("names", signature("tileGroup"), function(x) {
    names(x@groups)
})

setMethod("[", signature("tileGroup", "missing", "missing", "missing"), function(x, ...) {
    x@ti
})

setMethod("[", signature("tileGroup", ".index", "missing", "missing"), function(x, i, ...) {
    do.call("[", c(x@ti, x@groups[[i]]))
})

setMethod("length", signature("tileGroup"), function(x) {
    length(x@groups)
})

# Arithmetic operations - apply buffer to underlying iterator
#' @rdname arith
#' @export
setMethod("+", signature("tileGroup", "numeric"), function(e1, e2) {
    e1@ti <- e1@ti + e2
    return(e1)
})

#' @rdname arith
#' @export
setMethod("-", signature("tileGroup", "numeric"), function(e1, e2) {
    e1@ti <- e1@ti - e2
    return(e1)
})
