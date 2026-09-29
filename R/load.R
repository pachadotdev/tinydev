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
    # reading the package's own NAMESPACE file and copying just those names
    # into pkg_env, instead of attaching whole packages.
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

            # Name the output after the package itself, matching what R CMD
            # INSTALL would produce. R's dyn.load() auto-invokes the
            # "R_init_<name>" routine using the *DLL's basename* as <name>,
            # not the R_init_ symbol actually defined inside it. Letting
            # SHLIB pick a name from the first source file (e.g. cpp4r.cpp
            # when a vendored cpp4r.cpp sorts before main.cpp) produces a
            # DLL whose basename doesn't match the package, so the real
            # R_init_<pkgname> registration routine is silently never
            # called and .Call() lookups of native symbols fail.
            dll_pat <- if (.Platform$OS.type == "windows") "\\.dll$" else "\\.so$"
            dll_ext <- if (.Platform$OS.type == "windows") ".dll" else ".so"
            dll_name <- paste0(pkgname, dll_ext)
            # Remove any stale .so/.dll left over from a previous build (e.g.
            # one named after a vendored source file such as cpp4r.cpp) so it
            # can never be picked up instead of the freshly built package DLL.
            stale_dll <- setdiff(dir(".", pattern = dll_pat, full.names = TRUE), file.path(".", dll_name))
            if (length(stale_dll) > 0) {
                file.remove(stale_dll)
            }
            system2("R", c("CMD", "SHLIB", "-o", shQuote(dll_name), shQuote(src_files)))
            if (file.exists(dll_name)) {
                loaded <- getLoadedDLLs()
                if (pkgname %in% names(loaded)) {
                    dyn.unload(loaded[[pkgname]][["path"]])
                }
                dll_info <- dyn.load(dll_name)
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

    # Sort: source files that contain setClass() before all others.
    # Without this, setMethod() can be called before the class it references
    # is defined (alphabetical load order puts e.g. dbConnect_PqDriver.R
    # ahead of PqDriver.R), producing "no definition for class" warnings.
    has_setclass <- vapply(r_files, function(f) {
        any(grepl("\\bsetClass\\b", readLines(f, warn = FALSE), perl = TRUE))
    }, logical(1))
    r_files <- c(r_files[has_setclass], r_files[!has_setclass])

    # utils::packageVersion() calls packageDescription() which looks for
    # pkgname/DESCRIPTION in .libPaths(). Provide one from this package's
    # own DESCRIPTION so the version is found even when not installed.
    #
    # NOTE: We deliberately do NOT set .packageName = pkgname in globalenv()
    # here. setClass() uses getPackageName(topenv(parent.frame())) which calls
    # get0(".packageName", envir = globalenv(), inherits = TRUE). If we set
    # .packageName = "rpsql", every setClass() call stores package = "rpsql"
    # in the class representation. Later, new("PqConnection", ...) sees
    # package = "rpsql" and calls loadNamespace("rpsql"), loading the
    # *installed* package alongside the dev .so — two incompatible native
    # libraries loaded simultaneously → bad_weak_ptr crash.
    # With no .packageName set, classes register as package = "" and R never
    # tries to load any external namespace during object construction.
    .tmp_lib <- file.path(tempdir(), paste0("tinydev_", pkgname))
    .tmp_pkg <- file.path(.tmp_lib, pkgname)
    dir.create(.tmp_pkg, recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(pkg, "DESCRIPTION"), file.path(.tmp_pkg, "DESCRIPTION"),
              overwrite = TRUE)
    .old_libpaths <- .libPaths()
    .libPaths(c(.tmp_lib, .old_libpaths))
    on.exit({
        .libPaths(.old_libpaths)
        unlink(.tmp_lib, recursive = TRUE)
    }, add = TRUE)

    # setMethod(f, signature, def) calls topenv(parent.frame()) to find where
    # to look up the generic. Since pkg_env is a plain environment (not a
    # namespace), topenv() walks up to globalenv(). S4 generics from
    # fully-imported packages (e.g. DBI) are in pkg_env but NOT in globalenv(),
    # so setMethod() fails with "no existing definition for function 'f'".
    # Fix: temporarily assign all S4 genericFunctions from pkg_env to globalenv()
    # for the duration of sourcing, then clean up.
    s4_to_restore <- character(0)
    for (.nm in ls(pkg_env, all.names = FALSE)) {
        .obj <- pkg_env[[.nm]]
        if (isS4(.obj) && is(.obj, "genericFunction") &&
            !exists(.nm, envir = globalenv(), inherits = FALSE)) {
            assign(.nm, .obj, envir = globalenv())
            s4_to_restore <- c(s4_to_restore, .nm)
        }
    }
    on.exit(
        if (length(s4_to_restore) > 0)
            rm(list = s4_to_restore, envir = globalenv()),
        add = TRUE
    )

    for (f in r_files) {
        source(f, local = pkg_env)
    }

    # R/sysdata.rda holds internal (non-exported) package data, e.g. objects
    # built by usethis::use_data(..., internal = TRUE). R CMD INSTALL bakes
    # this directly into the package's namespace so its own R code can see
    # it without exporting it; mirror that here so code sourced above that
    # references such objects (evaluated lazily, at call time) resolves them
    # exactly as it would in an installed package.
    sysdata_file <- file.path(pkg, "R", "sysdata.rda")
    if (file.exists(sysdata_file)) {
        load(sysdata_file, envir = pkg_env)
    }

    data_files <- list.files(
        file.path(pkg, "data"),
        pattern = "\\.(rda|RData)$",
        full.names = TRUE
    )
    for (f in data_files) {
        load(f, envir = pkg_env)
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

    # Expose everything (functions, data and native symbols) on the search
    # path, like a real package load / devtools::load_all() does, instead of
    # writing into .GlobalEnv. attach() inserts a separate environment at
    # search()[2], leaving the user's global workspace untouched, which is
    # required by CRAN policy.
    search_name <- paste0("package:", pkgname)
    if (search_name %in% search()) {
        detach(search_name, character.only = TRUE, unload = FALSE)
    }
    attach(as.list(pkg_env), name = search_name, warn.conflicts = FALSE)

    invisible(r_files)
}
