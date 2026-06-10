#' @title Build R package
#' @description Build an R package into a tar.gz file. The built file will be
#'  created one level up from the package directory.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @param document \code{[logical]} Generate documentation before checking.
#' @param build_vignettes \code{[logical]} Build vignettes. Defaults to TRUE.
#' @param build_manual \code{[logical]} Build manual. Defaults to TRUE.
#' @return Prints the path to the built tar.gz file if successful.
#' @export
pkg_build <- function(pkgdir = ".", document = TRUE, build_vignettes = TRUE, build_manual = TRUE) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    
    # description_update(pkg)
    if (document) {
        pkg_document(pkg)
    }

    pkgname <- read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Package")
    outdir <- dirname(pkg)
    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(outdir)
    
    args <- c("CMD", "build")
    if (!build_vignettes) args <- c(args, "--no-build-vignettes")
    if (!build_manual) args <- c(args, "--no-manual")
    args <- c(args, shQuote(pkg))
    
    system2("R", args = args, stdout = NULL, stderr = NULL)
    pkgfile <- dir(outdir, pattern = paste0(pkgname, ".*\\.tar\\.gz"), full.names = TRUE)
    
    pkgfile
}
