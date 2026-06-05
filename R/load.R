#' @title Load package into the current R session
#' @description Load all R code and compiled shared libraries from a package directory.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns a character vector of loaded R files.
#' @export
pkg_load <- function(pkgdir = ".") {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    pkgname <- read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Package")[[1]]
    message("Loading ", pkgname)

    # Compile shared library if src/ exists
    src_dir <- file.path(pkg, "src")
    if (dir.exists(src_dir)) {
        src_files <- list.files(
            src_dir,
            pattern = "\\.(c|cc|cpp|f|f90|f95)$",
            full.names = FALSE
        )
        if (length(src_files) > 0) {
            oldwd <- getwd()
            on.exit(setwd(oldwd), add = TRUE)
            setwd(src_dir)
            system2("R", c("CMD", "SHLIB", shQuote(src_files)))
            dll_pat <- if (.Platform$OS.type == "windows") "\\.dll$" else "\\.so$"
            dll <- dir(".", pattern = dll_pat, full.names = TRUE)
            if (length(dll) > 0) {
                loaded <- getLoadedDLLs()
                if (pkgname %in% names(loaded)) {
                    dyn.unload(loaded[[pkgname]][["path"]])
                }
                dyn.load(dll[1])
            }
        }
    }

    r_files <- list.files(
        file.path(pkg, "R"),
        pattern = "\\.[Rr]$",
        full.names = TRUE
    )
    for (f in r_files) {
        source(f, local = FALSE)
    }
    invisible(r_files)
}
