#' @name tilework_management
#' @title tilework management
#' @family parallel settings
#' @description
#' A set of utilities to control the location and naming of automated tilework
#' outputs. These are mostly to do with logging information right now.
NULL

#' @rdname tilework_management
#' @returns `getTileworkLogDir` the logging directory to use
#' @export
getTileworkLogDir <- function() {
    getOption("tilework.log_dir", tempdir())
}
#' @rdname tilework_management
#' @param path directory path to use
#' @returns `setTileworkLogDir` returns the previous logging directory invisibly
#' @export
setTileworkLogDir <- function(path) {
    old <- getOption("tilework.log_dir", tempdir())
    options("tilework.log_dir" = path)
    invisible(old)
}
#' @rdname tilework_management
#' @param advance logical (default = FALSE). Whether to consume this job ID
#' @returns `getTileworkJobID` returns the next job ID to use. If
#' `advance = FALSE` this call will be treated as a peek and will not consume
#' the ID.
#' @export
getTileworkJobID <- function(advance = FALSE) {
    checkmate::assert_flag(advance)
    id <- getOption("tilework.next_job_id")
    if (is.null(id)) {
        options("tilework.next_job_id" = .random_id())
        return(getTileworkJobID(advance = advance))
    }
    if (advance) options("tilework.next_job_id" = .random_id())
    id
}

# Create an active file connection object to the logfile to
# write to. Opens it in mode "a+" which allows both appending and reading.
.log_conn <- function(log_dir = getTileworkLogDir(), job_id) {
    checkmate::assert_character(job_id)
    pid <- Sys.getpid()
    node <- Sys.info()[["nodename"]]
    f <- file.path(log_dir, job_id, sprintf("LOG_node=%s_pid=%s.txt", node, pid))
    if (!checkmate::test_file_exists(f)) {
        f <- .log_create(path = f) |>
            normalizePath()
    }
    file(f, open = "a+") # open in 'a'ppend and reading (+) mode
}

.log_create <- function(path) {
    checkmate::assert_character(path)
    dname <- dirname(path)
    if (!dir.exists(dname)) dir.create(dname, recursive = TRUE)

    file.create(path)
    path <- normalizePath(path)
    invisible(path)
}

# write to an open log file connection
.log_write <- function(
    conn = NULL, ..., prefix = "", collapse = " ",
    console = FALSE, auto_close = FALSE, dry_run = FALSE) {
    if (!inherits(conn, c("connection"))) {
        stop("conn should be an open file connection")
    }
    x <- list(...)
    checkmate::assert_flag(console)
    checkmate::assert_flag(auto_close)

    if (auto_close) on.exit(close(conn), add = TRUE)

    log_entry <- paste(x, collapse = collapse)
    log_entry <- sprintf("%s[%s] %s", prefix, .timestamp(), log_entry)
    if (dry_run || console) cat(log_entry, "\n")
    if (dry_run) return(invisible())
    writeLines(log_entry, con = conn, sep = "\n")
}

# determine verbosity
.verbosity <- function(.v = NULL, .vopt = getOption("tilework.verbose", TRUE)) {
    if (!is.null(.v)) .vopt <- .v
    if (is.logical(.vopt)) return(.vopt) # return early if T/F
    if (is.character(.vopt)) {
        .vopt <- tolower(.vopt)
        # default to F if unknown input
        if (!identical(.vopt, "debug")) return(FALSE)
        return(.vopt) # return "debug"
    }
    # catch
    stop(call. = FALSE, "verbosity setting must be either logical or \"debug\"")
}

.str_reformat <- function(..., .prefix = " ", .initial = "") {
    width <- min(100, getOption("width"))
    paste(...) |>
        strwrap(width = width, prefix = .prefix, initial = .initial) |>
        paste(collapse = "\n")
}

# verbosity controlled messages
.vmsg <- function(..., .v = NULL, .initial = "", .prefix = " ") {
    v <- .verbosity(.v)
    # end early if no print
    if (isFALSE(v)) return(invisible())
    message(.str_reformat(..., .initial = .initial, .prefix = .prefix))
}

# debug messages
# plist can be a list(...) to grab the names of passed arg names
.dmsg <- function(..., .v = NULL, .initial = "", .prefix = " ", plist = NULL) {
    v <- .verbosity(.v)
    if (!identical(v, "debug")) return(invisible())

    msg_parts <- list(...)

    if (length(plist) > 0L) {
        param_names <- toString(names(plist))
        msg_parts <- c(msg_parts, "Dot params:", param_names)
    }

    # Use do.call to unpack list as separate arguments to .str_reformat
    msg_parts <- c(msg_parts, list(.initial = .initial, .prefix = .prefix))
    do.call(.str_reformat, msg_parts) |>
        message()
}
