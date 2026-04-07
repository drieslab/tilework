#' @name tileGroup
#' @title Create a Tile Group
#' @family tile orchestration
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
#' length(tp) <- 16
#'
#' # Create groups
#' tg <- tileGroup(tp, groups = list(
#'     "g1" = 1:4, # vector indexing
#'     "g2" = list(2, 1:4), # ij indexing
#'     "g3" = list(2:4, 1:2) # selection overlaps are allowed
#'     # (not all tiles need to be selected)
#' ))
#'
#' # length() returns number of groups
#' length(tg)
#'
#' # Get group bounds:
#' tg[, "g1"] # first 4
#' tg[, "g2"] # next 4
#' tg[, "g3"] # specific 6
#' # not recommended for large groups
#'
#' tg[c(3, 1), "g3"] # get nth item in group
#'
#' # Set active group for shorthand indexing
#' tg$active <- "g1"
#'
#' # length() is based on group length when active is set
#' length(tg)
#'
#' tg[2] # Position 2 from g1
#'
#' # iterator can be created when active group is set
#' iter <- tileIterator(tg, batch_size = 2)
#' iter$next_batch()
#' iter$next_batch()
#' iter$next_batch() # no more items
#'
#' tg$active <- NULL # Clear active group by setting NULL
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
            group = names(x@groups) %||% paste0("group_", seq_along(x@groups)),
            n_tiles = lengths(x@groups),
            row.names = NULL
        )
    }
    x
})

setMethod("show", signature("tileGroup"), function(object) {
    cat(sprintf("<%s>: %s\n", class(object), class(object@tp)))
    if (.has_active(object)) {
        cat("active:", object@active, "\n")
    }
    cat(.color_yellow("groups-------------------------\n"))
    plist <- lapply(object@groups, function(g) {
        len <- .g_length(g)
        sprintf("%d tiles", len)
    })
    .print_list(plist, pre = "  ")
})

#' @rdname dollar
#' @export
setMethod("$<-", signature("tileGroup", "ANY"), function(x, name, value) {
    if (name == "active") {
        checkmate::assert_character(value, len = 1L, null.ok = TRUE)
        if (is.null(value)) {
            x@active <- character()
        } # reset
        else {
            x@active <- value
        }
        return(x)
    }
    x@metadata[[name]] <- value
    x
})

#' @rdname dollar
#' @export
setMethod("$", signature("tileGroup"), function(x, name) {
    if (name == "active") {
        return(x@active)
    }
    x@metadata[[name]]
})

setMethod("names", signature("tileGroup"), function(x) {
    names(x@groups)
})

#' @rdname bracket
#' @export
setMethod("[", signature("tileGroup", "missing", "missing", "missing"), function(x, ...) {
    x@tp
})

#' @rdname bracket
#' @export
setMethod("[", signature("tileGroup", ".index", "missing", "missing"), function(x, i, ...) {
    if (!.has_active(x)) {
        stop("tileGroup: i only indexing can only be used with `$active` group set.\n", call. = FALSE)
    }
    x[i, x@active]
})

#' @rdname bracket
#' @export
setMethod("[", signature("tileGroup", "missing", ".index", "missing"), function(x, j, ...) {
    if (length(j) > 1L) stop("[tileGroup] only one j can be used at a time", call. = FALSE)
    grp_idx <- x@groups[[j]]
    if (is.null(grp_idx)) stop("[tileGroup] j = ", j, " does not exist", call. = FALSE)
    if (.is_ij_group(grp_idx)) {
        x@tp[i = grp_idx[[1L]], j = grp_idx[[2L]]]
    } else {
        x@tp[i = grp_idx]
    }
})

#' @rdname bracket
#' @export
setMethod("[", signature("tileGroup", "numeric", ".index", "missing"), function(x, i, j, ...) {
    if (length(j) > 1L) stop("[tileGroup] only one j can be used at a time", call. = FALSE)
    g <- x@groups[[j]] # select group of interest
    if (is.null(g)) stop("[tileGroup] j = ", j, " does not exist", call. = FALSE)
    if (!.is_ij_group(g)) {
        # rely on default indexing for vector
        if (any(length(g) < i | i < 0)) stop("[tileGroup] subscript out of bounds", call. = FALSE)
        idx <- g[i]
        return(x@tp[idx])
    }
    # for ij, expand indices to pairlist then pull indices of interest
    ij <- .g_index(g, i)
    x@tp[i = ij[[1L]], j = ij[[2L]], expand_grid = FALSE]
})

setMethod("length", signature("tileGroup"), function(x) {
    if (length(x@active) > 0) {
        g <- x@groups[[x@active]]
        if (.is_ij_group(g)) {
            l <- length(g[[1L]]) * length(g[[2L]])
        } else {
            l <- length(g)
        }
        return(l)
    }
    length(x@groups)
})

setMethod("lengths", signature("tileGroup"), function(x, use.names = TRUE) {
    l <- vector(mode = "integer", length = length(x@groups))
    for (i in seq_along(x@groups)) {
        g <- x@groups[[i]]
        if (.is_ij_group(g)) {
            l[[i]] <- length(g[[1L]]) * length(g[[2L]])
        } else {
            l[[i]] <- length(g)
        }
    }
    if (use.names) {
        names(l) <- names(x@groups)
    }
    l
})

# Arithmetic operations - apply padding to underlying `tilePlan`
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

# helpers ####

#' @export
.DollarNames.tileGroup <- function(x, pattern) {
    c("active", colnames(x@metadata))
}

.has_active <- function(x) {
    length(x@active) > 0L
}

# test if an entry in @groups is likely ij indexing instead of vector
.is_ij_group <- function(x) {
    inherits(x, "list") && length(x) == 2L
}

.g_length <- function(x) {
    if (.is_ij_group(x)) {
        return(.ij_length(x))
    }
    length(x) # vector length
}

.ij_length <- function(x) {
    length(x[[1L]]) * length(x[[2L]])
}

# pull a single index in a group entry. (ij indexing only)
.g_index <- function(grp_idx, pos) {
    i_vals <- grp_idx[[1L]]
    j_vals <- grp_idx[[2L]]
    n_cols <- length(j_vals)
    n_rows <- length(i_vals)
    total_tiles <- n_rows * n_cols

    if (any(pos > total_tiles) || any(pos < 1)) {
        stop("[tileGroup] i = ", max(pos), " exceeds group size of ", total_tiles, call. = FALSE)
    }

    # Convert linear position to ij coordinates within the group
    # Using standard row-major ordering (same as tilePlan)
    pos_zero <- pos - 1L # Convert to 0-based
    row_idx <- pos_zero %/% n_cols + 1L # Which row in the group
    col_idx <- pos_zero %% n_cols + 1L # Which col in the group

    # Map back to actual tilePlan coordinates
    actual_i <- i_vals[row_idx]
    actual_j <- j_vals[col_idx]

    list(actual_i, actual_j)
}
