#' @title Add a pattern to .Rbuildignore
#' @description Add a pattern to the .Rbuildignore file in the current directory.
#'  If the file does not exist, it will be created. If the pattern already exists in the file, it will not be added again.
#' @param pattern Pattern to add (e.g., "LICENSE.txt" or "^LICENSE\\.txt$").
#' @return Invisibly returns 'TRUE' if the pattern was added successfully or already exists in the file.
#' @export
rbuildignore_add <- function(pattern = NULL) {
    stop_if_not_package(getwd())
    if (!file.exists(".Rbuildignore")) file.create(".Rbuildignore")
    lines <- readLines(".Rbuildignore", warn = FALSE)
    if (!pattern %in% lines) write(pattern, ".Rbuildignore", append = TRUE)
    invisible(TRUE)
}

#' @title Copy package sources while respecting .Rbuildignore
#' @description Copy only the files of a package that would NOT be excluded by
#'  its '.Rbuildignore' file into a destination directory. Directories that
#'  match an ignore pattern are never recursed into (and so never listed),
#'  which avoids the cost of walking huge ignored trees (e.g. a 'dev/' folder
#'  with a JS 'node_modules' install) before handing the source off to
#'  'R CMD build'/'R CMD check'.
#' @param pkgdir The path to the package directory.
#' @param dest The destination directory to copy the filtered sources into.
#'  Created if it does not already exist.
#' @return Invisibly returns the destination path.
#' @keywords internal
pkg_copy_filtered <- function(pkgdir, dest) {
    pkg <- normalizePath(pkgdir, winslash = "/")

    ignore_file <- file.path(pkg, ".Rbuildignore")
    patterns <- character(0)
    if (file.exists(ignore_file)) {
        patterns <- readLines(ignore_file, warn = FALSE)
        patterns <- patterns[nzchar(patterns)]
    }

    is_ignored <- function(relpath) {
        if (length(patterns) == 0) return(FALSE)
        for (p in patterns) {
            ok <- tryCatch(grepl(p, relpath), error = function(e) FALSE)
            if (isTRUE(ok)) return(TRUE)
        }
        FALSE
    }

    dir.create(dest, recursive = TRUE, showWarnings = FALSE)

    walk <- function(reldir) {
        srcdir <- if (nzchar(reldir)) file.path(pkg, reldir) else pkg
        entries <- list.files(srcdir, all.files = FALSE, no.. = TRUE)
        for (e in entries) {
            relpath <- if (nzchar(reldir)) file.path(reldir, e) else e
            if (is_ignored(relpath)) next
            srcpath <- file.path(pkg, relpath)
            if (dir.exists(srcpath)) {
                dir.create(file.path(dest, relpath), recursive = TRUE, showWarnings = FALSE)
                walk(relpath)
            } else {
                dstpath <- file.path(dest, relpath)
                dir.create(dirname(dstpath), recursive = TRUE, showWarnings = FALSE)
                file.copy(srcpath, dstpath, copy.date = TRUE)
            }
        }
    }
    walk("")

    invisible(dest)
}
