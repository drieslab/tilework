
#' @name tileGroup
#' @title Create a Tile Group
#' @description
#' Organize tiles from a tilePlan into hierarchical groups for batch processing.
#' Groups can represent spatial regions, processing stages, or any logical
#' organization of tiles.
#' @param tp A tilePlan object
#' @param groups Named list where each element contains tile indices for that group
#' @param metadata Optional data.frame with group metadata
#' @examples
#' tp <- tilePlan("spatial")
#' ext(tp) <- c(0, 100, 0, 100)
#' length(tp) <- 9
#'
#' # Create groups
#' tg <- tileGroup(tp, groups = list(
#'   "top" = 1:3,
#'   "middle" = 4:6,
#'   "bottom" = 7:9
#' ))
NULL

#' @rdname tileGroup
#' @export
tileGroup <- function(tp, groups = list()) {
    new("tileGroup", tp = tp, groups = groups)
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
    cat(sprintf("<%s>: %s\n", class(object), class(object@tp)))
    cat(color_yellow("groups----------------------------------\n"))
    print_list(object@groups, pre = "  ")
})

setMethod("names", signature("tileGroup"), function(x) {
    names(x@groups)
})

setMethod("[", signature("tileGroup", "missing", "missing", "missing"), function(x, ...) {
    x@tp
})

setMethod("[", signature("tileGroup", ".index", "missing", "missing"), function(x, i, ...) {
    do.call("[", c(x@tp, x@groups[[i]]))
})

setMethod("length", signature("tileGroup"), function(x) {
    length(x@groups)
})

# Arithmetic operations - apply buffer to underlying iterator
#' @rdname arith
#' @export
setMethod("+", signature("tileGroup", "numeric"), function(e1, e2) {
    e1@tp <- e1@tp + e2
    return(e1)
})

#' @rdname arith
#' @export
setMethod("-", signature("tileGroup", "numeric"), function(e1, e2) {
    e1@tp <- e1@tp - e2
    return(e1)
})
