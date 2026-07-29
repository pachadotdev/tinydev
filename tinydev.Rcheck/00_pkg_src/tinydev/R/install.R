#' @title Install R package
#' @description Install an R package from a directory
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns 'TRUE' if the package was installed successfully.
#' @export
pkg_install <- function(pkgdir = ".") {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    # description_update(pkg)
    exit_code <- system2("R", args = c("CMD", "INSTALL", shQuote(pkg)))
    invisible(TRUE)
}
