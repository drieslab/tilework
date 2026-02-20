setMethod("show", signature("tileSelection"), function(object) {
    cat(sprintf("<%s>: %s\n", class(object), class(object@tp)))
    cat(sprintf("%d tiles", length(object@indices)))
})

#' @rdname bracket
#' @export
setMethod("[", signature("tileSelection", "numeric", "missing", "missing"), function(x, i, j, ..., drop) {
    x@tp[x@indices[i], ...]
})

#' @rdname bracket
#' @export
setMethod("[", signature("tileSelection", "numeric", "missing", "logical"), function(x, i, j, ..., drop) {
    if (drop) return(x@tp[x@indices[i], ...])
    x@indices <- x@indices[i]
    x
})

setMethod("length", signature("tileSelection"), function(x) length(x@indices))

setMethod("c", signature("tileSelection"), function(x, ...) {
    dots <- list(...)
    y <- dots[[1]]
    if (!inherits(y, "tileSelection")) stop("can only concatenate `tileSelection` with each other\n", call. = FALSE)
    x@indices <- c(x@indices, y@indices)
    remaining <- dots[-1]
    if (length(remaining) == 0L) return(x)
    do.call("c", c(list(x = x), remaining))
})

setMethod("plot", signature("tileSelection", "missing"), function(x, y, border = "red", ...) {
    plot(x@tp, ...)
    for (i in x@indices) {
        e <- x@tp[i][[1L]]
        b <- terra::as.polygons(e)
        terra::plot(b, border = border, add = TRUE)
    }
})

#' @rdname arith
#' @export
setMethod("+", signature("tileSelection", "numeric"), function(e1, e2) {
    e1@tp <- e1@tp + e2
    return(e1)
})

#' @rdname arith
#' @export
setMethod("-", signature("tileSelection", "numeric"), function(e1, e2) {
    e1@tp <- e1@tp - e2
    return(e1)
})
