# TODO: fix later, this is adding more problems than solutions

# #' @title Update DESCRIPTION Imports and Suggests fields
# #' @description Scan R code in the package directories to identify used packages
# #'  and update the 'Imports' and 'Suggests' fields in the DESCRIPTION file.
# #'  Packages found in 'dir.r' go to Imports; packages found only in 'dir.v' or
# #'  'dir.t' go to Suggests. Detects 'pkg::fun()', '@importFrom pkg fun',
# #'  'library(pkg)', and 'require(pkg)' patterns.
# #' @param pkgdir The path to the package directory. Defaults to the current directory.
# #' @param dir.r Directory with R scripts (Imports). Defaults to 'R'.
# #' @param dir.v Vignettes directory (Suggests). Set to '' to skip.
# #' @param dir.t Tests directory (Suggests). Set to '' to skip.
# #' @param extra_suggests Character vector of extra packages to add to Suggests.
# #' @param pkg_ignore Character vector of package names to exclude from both fields.
# #' @return Invisibly returns 'TRUE' if the package was built successfully.
# #' @export
# description_update <- function(
#     pkgdir = ".",
#     dir.r = "R",
#     dir.v = "vignettes",
#     dir.t = "tests",
#     extra_suggests = NULL,
#     pkg_ignore = NULL
# ) {
#     pkg <- normalizePath(pkgdir, winslash = "/")
#     stop_if_not_package(pkg)
#     desc_file <- file.path(pkg, "DESCRIPTION")

#     base_pkgs <- c(
#         "base", "compiler", "datasets", "graphics", "grDevices",
#         "grid", "methods", "parallel", "splines", "stats", "stats4",
#         "tcltk", "tools", "utils"
#     )

#     pkg_name <- read.dcf(desc_file, fields = "Package")[[1]]

#     scan_pkgs <- function(dirs) {
#         file_pat <- "\\.[Rr]$|\\.[Rr]md$|\\.qmd$"
#         files <- unlist(lapply(dirs, function(d) {
#             d_full <- file.path(pkg, d)
#             if (!nzchar(d) || !dir.exists(d_full)) return(character())
#             list.files(d_full, pattern = file_pat, full.names = TRUE, recursive = TRUE)
#         }))
#         if (length(files) == 0L) return(character())

#         lines <- unlist(lapply(files, readLines, warn = FALSE))

#         # @importFrom pkg — roxygen comment lines only
#         # Only match @importFrom when it is an actual roxygen tag (at start of comment content),
#         # not when the text "@importFrom pkg fun" appears inside prose or quoted examples.
#         roxy_tags <- lines[grepl("^\\s*#'\\s*@importFrom\\s", lines)]
#         import_from <- character()
#         if (length(roxy_tags) > 0L) {
#             m <- gregexpr("(?<=@importFrom\\s)[a-zA-Z][a-zA-Z0-9.]*", roxy_tags, perl = TRUE)
#             import_from <- unique(unlist(regmatches(roxy_tags, m)))
#         }

#         # strip all comments before extracting code patterns
#         code <- gsub("#.*$", "", lines)

#         # pkg::fun
#         m2 <- gregexpr("[a-zA-Z][a-zA-Z0-9.]*(?=::)", code, perl = TRUE)
#         ns_pkgs <- unique(unlist(regmatches(code, m2)))

#         # library(pkg) / library("pkg") / library('pkg')
#         lib_m <- gregexpr(
#             "(?<=\\blibrary\\()[\"']?([a-zA-Z][a-zA-Z0-9.]*)[\"']?(?=\\s*[,)])",
#             code, perl = TRUE
#         )
#         lib_pkgs <- gsub("[\"']", "", unique(unlist(regmatches(code, lib_m))))

#         # require(pkg) / require("pkg") / require('pkg')
#         req_m <- gregexpr(
#             "(?<=\\brequire\\()[\"']?([a-zA-Z][a-zA-Z0-9.]*)[\"']?(?=\\s*[,)])",
#             code, perl = TRUE
#         )
#         req_pkgs <- gsub("[\"']", "", unique(unlist(regmatches(code, req_m))))

#         unique(c(ns_pkgs, import_from, lib_pkgs, req_pkgs))
#     }

#     imports_raw  <- scan_pkgs(dir.r)
#     suggests_raw <- scan_pkgs(c(dir.v, dir.t))

#     filter_pkgs <- function(pkgs, exclude = character()) {
#         pkgs <- pkgs[nzchar(pkgs)]
#         pkgs <- pkgs[!pkgs %in% base_pkgs]
#         pkgs <- pkgs[!pkgs %in% pkg_ignore]
#         pkgs <- pkgs[pkgs != pkg_name]
#         pkgs <- pkgs[!pkgs %in% exclude]
#         sort(unique(pkgs))
#     }

#     imports  <- filter_pkgs(imports_raw)
#     suggests <- filter_pkgs(suggests_raw, exclude = imports)

#     if (!is.null(extra_suggests)) {
#         suggests <- sort(unique(c(suggests, extra_suggests[!extra_suggests %in% imports])))
#     }

#     # Use desc package to read/write — preserves format, version pins, Depends, LinkingTo
#     d <- desc::description$new(desc_file)
#     existing <- d$get_deps()

#     get_version <- function(pkg_vec, type) {
#         vapply(pkg_vec, function(p) {
#             v <- existing$version[existing$package == p & existing$type == type]
#             if (length(v) == 0L) "*" else v[[1L]]
#         }, character(1L))
#     }

#     imports_df <- if (length(imports) > 0L) {
#         data.frame(type = "Imports",  package = imports,  version = get_version(imports,  "Imports"),  stringsAsFactors = FALSE)
#     } else {
#         data.frame(type = character(), package = character(), version = character(), stringsAsFactors = FALSE)
#     }

#     suggests_df <- if (length(suggests) > 0L) {
#         data.frame(type = "Suggests", package = suggests, version = get_version(suggests, "Suggests"), stringsAsFactors = FALSE)
#     } else {
#         data.frame(type = character(), package = character(), version = character(), stringsAsFactors = FALSE)
#     }

#     keep <- existing[!existing$type %in% c("Imports", "Suggests"), ]
#     new_deps <- rbind(keep, imports_df, suggests_df)

#     d$del_deps()
#     d$set_deps(new_deps)
#     d$normalize()
#     d$write(file = desc_file)

#     invisible(TRUE)
# }
