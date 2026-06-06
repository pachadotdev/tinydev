#' @title Document R package
#' @description Generate documentation for an R package using roxygen2.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns 'TRUE' if the documentation was generated successfully.
#' @export
pkg_document <- function(pkgdir = ".") {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    # description_update(pkg)
    roxygenise(pkg)
    invisible(TRUE)
}
