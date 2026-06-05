#' @title Build R package
#' @description Build an R package into a tar.gz file. The built file will be
#'  created one level up from the package directory.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns 'TRUE' if the package was built successfully.
#' @export
pkg_build <- function(pkgdir = ".") {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    
    description_update(pkg)
    pkg_document(pkg)

    pkgname <- read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Package")
    outdir <- dirname(pkg)
    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(outdir)
    system2("R", args = c("CMD", "build", "--no-build-vignettes", "--no-manual", shQuote(pkg)))
    pkgfile <- dir(outdir, pattern = paste0(pkgname, ".*\\.tar\\.gz"), full.names = TRUE)
    
    invisible(TRUE)
}
