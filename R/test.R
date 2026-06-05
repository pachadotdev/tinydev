#' @title Run tests
#' @description Run tests for an R package using tinytest. Tests should be placed
#'  in the 'inst/tinytest' directory of the package.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns 'TRUE' if tests were run successfully.
#' @export
pkg_test <- function(pkgdir = ".") {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    testdir <- file.path(pkg, "inst/tinytest")
    if (!dir.exists(testdir)) {
        stop("no test directory found at: ", testdir, call. = FALSE)
    }
    run_test_dir(testdir)
    invisible(TRUE)
}
