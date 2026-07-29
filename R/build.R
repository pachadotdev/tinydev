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

    outdir <- dirname(pkg)
    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(outdir)
    
    args <- c("CMD", "build")
    if (!build_vignettes) args <- c(args, "--no-build-vignettes")
    if (!build_manual) args <- c(args, "--no-manual")
    args <- c(args, shQuote(pkg))
    
    # Capture R CMD build's own output rather than globbing outdir for the
    # built tarball afterwards: a glob like `dir(outdir, pattern =
    # paste0(pkgname, ".*\\.tar\\.gz"))` is unanchored, so it can match stale
    # tarballs from a previous version left in outdir (returning multiple
    # paths) and even other packages whose name starts with pkgname (e.g.
    # "cpp4r" matching "cpp4rtest_*.tar.gz"). R CMD build's last line of
    # output, `* building 'pkgname_x.y.z.tar.gz'`, unambiguously names the
    # tarball it just produced.
    out <- system2("R", args = args, stdout = TRUE, stderr = TRUE)
    cat(out, sep = "\n")

    built_line <- grep("^\\* building .+\\.tar\\.gz.$", out, value = TRUE)
    if (length(built_line) == 0) {
        stop("tinydev::pkg_build(): R CMD build did not report a built tarball; see output above.", call. = FALSE)
    }
    pkgfile <- file.path(outdir, sub("^\\* building .(.+\\.tar\\.gz).$", "\\1", built_line[length(built_line)]))
    
    pkgfile
}
