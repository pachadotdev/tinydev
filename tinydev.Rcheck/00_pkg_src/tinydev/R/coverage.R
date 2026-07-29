#' @title Check R package coverage
#' @description Check how much of an R package is tests by unit tests, vignettes and/or examples.
#' @param pkgdir The path to the package directory. Defaults to \code{NULL}.
#' @param type The type of coverage to calculate. One of "tests", "examples", "vignettes", or "all". Defaults to "all".
#' @param quiet If \code{TRUE}, suppress output from the underlying \code{covr::package_coverage()} function. Defaults to \code{TRUE}.
#' @return A list with the package's coverage details, as returned by \code{covr::coverage_to_list()}.
#' @export
pkg_coverage <- function(pkgdir = NULL, quiet = TRUE, type = "all") {
    coverage <- package_coverage(path = pkgdir, quiet = quiet, type = type)
    coverage_to_list(coverage)
}
