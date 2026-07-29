#' @title Check R package
#' @description Build and check an R package using R CMD check.
#' @param pkgdir The path to the package directory. Defaults to \code{NULL}.
#' @param cran \code{[logical]} Run checks as if on CRAN (passes \code{--as-cran}).
#' @param document \code{[logical]} Generate documentation before checking.
#' @param manual \code{[logical]} Build the PDF manual (requires LaTeX).
#' @param vignettes \code{[logical]} Build vignettes during check.
#' @return Invisibly returns 'TRUE' if the package was built successfully.
#' @export
pkg_check <- function(pkgdir = NULL, cran = TRUE, document = TRUE, manual = TRUE, vignettes = TRUE) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    
    pkg_clean(pkg)

    if (document) {
        pkg_document(pkg)
    }

    # R CMD build/check stage their work in a scratch directory under the
    # *subprocess's own* tempdir(), which is controlled by the TMPDIR env var
    # of that subprocess - not by this session's cwd or tempfile(). On Linux
    # /tmp is often a small, fixed-size tmpfs, so it can run out of space
    # even when the real disk has plenty free. Point TMPDIR at a cache dir
    # on the regular filesystem so the spawned "R CMD build"/"R CMD check"
    # processes stage there instead.
    cache_root <- tools::R_user_dir("tinydev", "cache")
    dir.create(cache_root, showWarnings = FALSE, recursive = TRUE)
    old_tmpdir <- Sys.getenv("TMPDIR", unset = NA)
    Sys.setenv(TMPDIR = cache_root)
    on.exit({
        if (is.na(old_tmpdir)) Sys.unsetenv("TMPDIR") else Sys.setenv(TMPDIR = old_tmpdir)
    }, add = TRUE)

    # R CMD build itself only filters out .Rbuildignore'd paths *after*
    # copying the ENTIRE source tree (including anything ignored) into its
    # own scratch "Rbuild<...>" directory - so a huge ignored folder (e.g. a
    # JS 'dev/' directory with a pnpm/node_modules install full of symlinks)
    # still gets copied in full first, which is what runs '/tmp' out of
    # space. Pre-filter into our own scratch copy instead, so ignored
    # directories are never even touched, then build the tarball from that
    # clean copy rather than the real package directory.
    srcdir <- tempfile(tmpdir = cache_root, pattern = "pkgsrc-")
    pkg_copy_filtered(pkg, srcdir)
    on.exit(unlink(srcdir, recursive = TRUE), add = TRUE)

    # Build into its own fresh, empty output directory rather than via
    # pkg_build() - that helper captures R CMD build's entire stdout/stderr
    # and only prints it once the subprocess exits, so for a package with
    # vignettes and/or a PDF manual (which can take a while) the console
    # shows nothing at all in the meantime, which looks like a hang. Stream
    # output live instead (no stdout/stderr capture), and find the produced
    # tarball by listing the dedicated output dir (guaranteed to contain
    # only what this build just produced) instead of parsing captured
    # output or globbing a shared directory that could hold stale tarballs.
    outdir <- tempfile(tmpdir = cache_root, pattern = "pkgout-")
    dir.create(outdir)
    on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

    oldwd <- getwd()
    on.exit(setwd(oldwd), add = TRUE)
    setwd(outdir)

    build_args <- c("CMD", "build")
    if (!vignettes) build_args <- c(build_args, "--no-build-vignettes")
    if (!manual) build_args <- c(build_args, "--no-manual")
    build_args <- c(build_args, shQuote(srcdir))
    system2("R", args = build_args)

    tarball <- dir(outdir, pattern = "\\.tar\\.gz$", full.names = TRUE)
    if (length(tarball) == 0) stop("build failed: no tarball produced", call. = FALSE)

    tdir <- tempfile(tmpdir = cache_root)
    dir.create(tdir)
    setwd(tdir)
    on.exit(unlink(tdir, recursive = TRUE), add = TRUE)

    check_args <- c("CMD", "check")
    if (cran) check_args <- c(check_args, "--as-cran")
    if (!manual) check_args <- c(check_args, "--no-manual")
    if (!vignettes) check_args <- c(check_args, "--no-build-vignettes")
    check_args <- c(check_args, shQuote(tarball))
    system2("R", args = check_args)

    # remove gcno files
    gcno_files <- list.files(".", pattern = "\\.gcno$", recursive = FALSE, full.names = TRUE)
    if (length(gcno_files) > 0) {
        file.remove(gcno_files)
    }

    invisible(TRUE)
}
