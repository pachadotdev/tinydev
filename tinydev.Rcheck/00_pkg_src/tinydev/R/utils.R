#' @title Utility functions for tinydev
#' @description Internal utility functions for tinydev package.
#' @name tinydev-utils
#' @keywords internal
stop_if_not_package <- function(path) {
    # pkg should have DESCRIPTION + R/ dir.
    finp <- list.files(path)
    stopifnot(any("DESCRIPTION" %in% finp))
    stopifnot(any("R" %in% finp))
    invisible(TRUE)
}
