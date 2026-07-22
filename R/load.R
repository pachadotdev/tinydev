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

    # Intermediate environment: routines and R code go here first so that
    # backtick .Call(`_pkg_foo_`) lookups work via lexical scope rather than
    # requiring symbols to live directly in globalenv().
    pkg_env <- new.env(parent = globalenv())

    # Load Imports before sourcing/running any package code below, exactly
    # like a real package load does (a namespace's imports are resolved
    # before its code is evaluated and its .onLoad hook runs). Doing this
    # first means functions from Imports are already available if .onLoad
    # calls into them (e.g. registering a cache backend).
    #
    # Every package under DESCRIPTION's Imports gets its namespace loaded
    # via requireNamespace() (so its own .onLoad runs and any S3 methods it
    # registers - e.g. data.table's merge.data.table - become available for
    # dispatch), but it is deliberately *not* attached to the search() path
    # via library(). Attaching every import would put ALL of that package's
    # exports ahead of base:: in scope for the sourced code, so an import
    # that happens to export a same-named function as a base generic (e.g.
    # config::merge(), a plain 2-argument helper, vs. the base::merge() S3
    # generic used throughout most packages) can silently shadow it, turning
    # generic dispatch into a call to the wrong function entirely and
    # breaking things in ways that only show up as a confusing "unused
    # arguments" error. A real NAMESPACE only ever brings in the exact names
    # listed in its import()/importFrom() directives, so we mirror that by
    # reading the package's own (roxygen2-generated) NAMESPACE file and
    # copying just those names into pkg_env, instead of attaching whole
    # packages.
    imports_raw <- read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Imports")[[1]]
    if (!is.na(imports_raw)) {
        import_pkgs <- trimws(strsplit(imports_raw, ",")[[1]])
        # Strip optional version constraints, e.g. "rlang (>= 1.0.0)" -> "rlang"
        import_pkgs <- sub("\\s*\\(.*\\)$", "", import_pkgs)
        for (imp in import_pkgs) {
            requireNamespace(imp, quietly = TRUE)
        }
    }

    namespace_file <- file.path(pkg, "NAMESPACE")
    if (file.exists(namespace_file)) {
        ns_lines <- readLines(namespace_file, warn = FALSE)
        ns_lines <- trimws(ns_lines)
        ns_lines <- ns_lines[nzchar(ns_lines) & !startsWith(ns_lines, "#")]

        # import(pkg): blanket import of every name the package exports
        import_calls <- regmatches(ns_lines, regexec("^import\\(([^)]+)\\)$", ns_lines))
        for (m in import_calls) {
            if (length(m) == 2) {
                imp_pkg <- trimws(m[2])
                for (nm in getNamespaceExports(imp_pkg)) {
                    pkg_env[[nm]] <- get(nm, envir = asNamespace(imp_pkg))
                }
            }
        }

        # importFrom(pkg, name1, name2, ...): only the listed names
        importfrom_calls <- regmatches(ns_lines, regexec("^importFrom\\(([^,]+),(.+)\\)$", ns_lines))
        for (m in importfrom_calls) {
            if (length(m) == 3) {
                imp_pkg <- trimws(m[2])
                nms <- trimws(strsplit(m[3], ",")[[1]])
                nms <- gsub("^`|`$", "", nms)
                for (nm in nms) {
                    pkg_env[[nm]] <- get(nm, envir = asNamespace(imp_pkg))
                }
            }
        }
    }

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
            
            # Get LinkingTo dependencies for compiler flags
            desc_fields <- read.dcf(file.path(pkg, "DESCRIPTION"))
            linking_to <- desc_fields[, "LinkingTo"]
            linking_pkgs <- if (!is.na(linking_to)) {
                trimws(strsplit(linking_to, ",")[[1]])
            } else {
                character(0)
            }
            
            # Build PKG_CPPFLAGS for dependencies
            pkg_cppflags <- NULL
            if (length(linking_pkgs) > 0) {
                include_dirs <- character(0)
                for (dep_pkg in linking_pkgs) {
                    # First try to find in workspace (sibling folders in parent directory)
                    parent_dir <- dirname(pkg)
                    workspace_pkg_path <- file.path(parent_dir, dep_pkg)
                    workspace_include <- file.path(workspace_pkg_path, "inst", "include")
                    
                    if (dir.exists(workspace_include)) {
                        include_dirs <- c(include_dirs, workspace_include)
                    } else {
                        # Fall back to installed package
                        dep_lib <- system.file("include", package = dep_pkg)
                        if (dep_lib != "") {
                            include_dirs <- c(include_dirs, dep_lib)
                        }
                    }
                }
                if (length(include_dirs) > 0) {
                    pkg_cppflags <- paste0("-I", include_dirs, collapse = " ")
                }
            }
            
            # Inject include paths into src/Makevars if it exists (a Makevars
            # simple assignment overrides environment variables in GNU Make, so
            # Sys.setenv("PKG_CPPFLAGS") would be silently discarded).
            makevars_path <- file.path(src_dir, "Makevars")
            if (!is.null(pkg_cppflags) && file.exists(makevars_path)) {
                original_lines <- readLines(makevars_path, warn = FALSE)
                on.exit(writeLines(original_lines, makevars_path), add = TRUE)
                idx <- grep("^\\s*PKG_CPPFLAGS\\s*=", original_lines)
                if (length(idx) > 0) {
                    original_lines[idx[1]] <- sub(
                        "(^\\s*PKG_CPPFLAGS\\s*=)(.*)",
                        paste0("\\1\\2 ", pkg_cppflags),
                        original_lines[idx[1]]
                    )
                } else {
                    original_lines <- c(original_lines, paste("PKG_CPPFLAGS =", pkg_cppflags))
                }
                writeLines(original_lines, makevars_path)
            } else if (!is.null(pkg_cppflags)) {
                old_env <- Sys.getenv("PKG_CPPFLAGS")
                Sys.setenv(PKG_CPPFLAGS = pkg_cppflags)
                on.exit(Sys.setenv(PKG_CPPFLAGS = old_env), add = TRUE)
            }

            system2("R", c("CMD", "SHLIB", shQuote(src_files)))
            dll_pat <- if (.Platform$OS.type == "windows") "\\.dll$" else "\\.so$"
            dll <- dir(".", pattern = dll_pat, full.names = TRUE)
            if (length(dll) > 0) {
                loaded <- getLoadedDLLs()
                if (pkgname %in% names(loaded)) {
                    dyn.unload(loaded[[pkgname]][["path"]])
                }
                dll_info <- dyn.load(dll[1])
                # Register native symbols in pkg_env so that backtick
                # .Call(`_pkg_foo_`) syntax works without a real namespace
                # (mirrors what useDynLib(..., .registration=TRUE) does).
                # R files are sourced into pkg_env below, so functions find
                # these symbols via their lexical scope.
                routines <- getDLLRegisteredRoutines(dll_info)
                for (type in c(".Call", ".External")) {
                    for (routine in routines[[type]]) {
                        pkg_env[[routine$name]] <- routine
                    }
                }
            }
        }
    }

    r_files <- list.files(
        file.path(pkg, "R"),
        pattern = "\\.[Rr]$",
        full.names = TRUE
    )
    for (f in r_files) {
        source(f, local = pkg_env)
    }
    # Expose everything (functions + native symbols) to globalenv so callers
    # see the same result as devtools::load_all(). list2env() does not
    # trigger the R CMD CHECK NOTE that assign(..., envir = globalenv()) does.
    list2env(as.list(pkg_env), envir = globalenv())

    data_files <- list.files(
        file.path(pkg, "data"),
        pattern = "\\.(rda|RData)$",
        full.names = TRUE
    )
    for (f in data_files) {
        load(f, envir = globalenv())
    }

    # Run the package's load hooks, like a real package load does once its
    # namespace is populated and its Imports are attached. Sourcing the R
    # files only *defines* .onLoad/.onAttach, it never calls them, so any
    # setup a package relies on happening at load time (e.g. tabler's
    # tablerOptions(cache = ...) pattern) would otherwise silently never run
    # under pkg_load().
    libname <- dirname(pkg)
    if (exists(".onLoad", envir = pkg_env, inherits = FALSE)) {
        pkg_env$.onLoad(libname, pkgname)
    }
    if (exists(".onAttach", envir = pkg_env, inherits = FALSE)) {
        pkg_env$.onAttach(libname, pkgname)
    }

    invisible(r_files)
}
