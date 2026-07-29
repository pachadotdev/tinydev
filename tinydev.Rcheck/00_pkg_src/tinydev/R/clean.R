#' @title Clean R package binaries
#' @description Remove compiled binaries from the 'src/' directory of an R package.
#'  Only applies to packages with compiled C/C++ code and will remove files with
#'  extensions '.o', '.so', and '.dll'.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns 'TRUE' if binaries were removed successfully.
#' @export
pkg_clean <- function(pkgdir = ".") {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)

    finp <- list.files(file.path(pkg, "src"), full.names = TRUE, pattern = "\\.(o|so|dll)$")
    if (length(finp) > 0) {
        file.remove(finp)
    }
    
    invisible(TRUE)
}
