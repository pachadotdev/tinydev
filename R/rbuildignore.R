#' @title Add a pattern to .Rbuildignore
#' @description Add a pattern to the .Rbuildignore file in the current directory.
#'  If the file does not exist, it will be created. If the pattern already exists in the file, it will not be added again.
#' @param pattern Pattern to add (e.g., "LICENSE.txt" or "^LICENSE\\.txt$").
#' @return Invisibly returns 'TRUE' if the pattern was added successfully or already exists in the file.
#' @export
rbuildignore_add <- function(pattern = NULL) {
    stop_if_not_package(getwd())
    if (!file.exists(".Rbuildignore")) file.create(".Rbuildignore")
    lines <- readLines(".Rbuildignore", warn = FALSE)
    if (!pattern %in% lines) write(pattern, ".Rbuildignore", append = TRUE)
    invisible(TRUE)
}
