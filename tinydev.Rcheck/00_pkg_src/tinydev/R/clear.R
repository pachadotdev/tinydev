#' @title Clear the console
#' @description Clear the console screen. It works in interactive R sessions.
#' @return Invisibly returns 'TRUE'.
#' @export
clear <- function() {
    if (interactive()) {
        if (.Platform$OS.type == "windows") {
            shell("cls")
        } else {
            cat("\033[2J\033[H")
        }
    }
    invisible(TRUE)
}
