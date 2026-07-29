#' @title Document R Package Functions
#' @description Generate documentation for an R package using tinyroxygen.
#' @param pkgdir The path to the package directory. Defaults to \code{NULL}.
#' @return Invisibly returns 'TRUE' if the documentation was generated successfully.
#' @export
pkg_document <- function(pkgdir = NULL) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    # description_update(pkg)
    tinyroxygen::roxygenize(pkg)
    invisible(TRUE)
}
