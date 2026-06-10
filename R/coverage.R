#' @title Check R package coverage
#' @description Check how much of an R package is tests by unit tests, vignettes and/or examples.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @param type The type of coverage to calculate. One of "tests", "examples", "vignettes", or "all". Defaults to "all".
#' @param quiet If \code{TRUE}, suppress output from the underlying \code{covr::package_coverage()} function. Defaults to \code{TRUE}.
#' @return Invisibly returns 'TRUE' if the package was built successfully.
#' @export
pkg_coverage <- function(pkgdir = ".", quiet = TRUE, type = "all") {
    coverage <- package_coverage(path = pkgdir, quiet = quiet, type = type)
    # pct <- round(percent_coverage(coverage), 2)
    # message("\nCoverage: ", pct, "%")
    print(coverage_to_list(coverage))
    invisible(TRUE)
}
