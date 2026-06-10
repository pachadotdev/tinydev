#' @title Run tests
#' @description Run tests for an R package using tinytest. Tests should be placed
#'  in the 'inst/tinytest' directory of the package. Any R files in that directory
#'  not starting with 'test' (e.g. 'helper.R') are sourced into the global
#'  environment before running the tests, making their definitions available to
#'  all test files.
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
    helpers <- dir(testdir, pattern = "^(?!test)[^.]+\\.[rR]$", full.names = TRUE)
    for (h in helpers) {
        source(h, local = FALSE)
    }
    run_test_dir(testdir)
    invisible(TRUE)
}
