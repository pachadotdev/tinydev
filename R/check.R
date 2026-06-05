#' @title Check R package
#' @description Build and check an R package using R CMD check.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @param cran \code{[logical]} Run checks as if on CRAN (passes \code{--as-cran}).
#' @param manual \code{[logical]} Build the PDF manual (requires LaTeX).
#' @param vignettes \code{[logical]} Build vignettes during check.
#' @return Invisibly returns 'TRUE' if the package was built successfully.
#' @export
pkg_check <- function(pkgdir = ".", cran = TRUE, manual = FALSE, vignettes = FALSE) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    
    description_update(pkg)
    pkg_document(pkg)

    pkgname <- read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Package")[[1]]

    tdir <- tempfile()
    dir.create(tdir)
    oldwd <- getwd()
    on.exit({
        setwd(oldwd)
        unlink(tdir, recursive = TRUE)
    })
    setwd(tdir)

    build_args <- c("CMD", "build")
    if (!vignettes) build_args <- c(build_args, "--no-build-vignettes")
    if (!manual) build_args <- c(build_args, "--no-manual")
    build_args <- c(build_args, shQuote(pkg))
    system2("R", args = build_args)

    tarball <- dir(".", pattern = paste0("^", pkgname, ".*\\.tar\\.gz$"), full.names = TRUE)
    if (length(tarball) == 0) stop("build failed: no tarball produced", call. = FALSE)

    check_args <- c("CMD", "check")
    if (cran) check_args <- c(check_args, "--as-cran")
    if (!manual) check_args <- c(check_args, "--no-manual")
    if (!vignettes) check_args <- c(check_args, "--no-build-vignettes")
    check_args <- c(check_args, shQuote(tarball))
    system2("R", args = check_args)

    invisible(TRUE)
}
