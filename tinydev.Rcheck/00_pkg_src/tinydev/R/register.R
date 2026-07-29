#' @title Register 'C++' Functions
#' @description Register 'C++' functions in an R package that uses 'cpp4r'.
#' @param pkgdir The path to the package directory. Defaults to \code{NULL}.
#' @return Invisibly returns 'TRUE' if the documentation was generated successfully.
#' @export
pkg_register <- function(pkgdir = NULL) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    if (!requireNamespace("cpp4r", quietly = TRUE)) { return(NULL) }
    cpp4r::register(pkgdir)
    invisible(TRUE)
}
