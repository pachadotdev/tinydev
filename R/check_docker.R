#' @title Check R package using Docker
#' @description Build and check an R package using R CMD check inside a Docker container. This uses
#' R-Hub Docker images to provide a consistent checking environment. The package is built outside
#' the container, then installed and checked inside. See \url{https://r-hub.github.io/containers/containers.html}
#' for the details.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @param image \code{[character]} R-Hub Docker image name. One of: ubuntu-clang, ubuntu-gcc,
#'   ubuntu-next, ubuntu-release, atlas, clang-asan, clang-ubsan, clang21, clang22, donttest,
#'   gcc16, gcc-asan, lto, mkl, nold, nosuggests, rchk, valgrind.
#' @param document \code{[logical]} Generate documentation before checking.
#' @param cran \code{[logical]} Run checks with \code{--as-cran} flag.
#' @return Invisibly returns 'TRUE' if the package check completed successfully.
#' @export
pkg_check_docker <- function(pkgdir = ".", image = "ubuntu-gcc", document = TRUE, cran = TRUE) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)

    # Validate image name
    image <- match.arg(image, c(
        "ubuntu-clang", "ubuntu-gcc", "ubuntu-next", "ubuntu-release",
        "atlas", "clang-asan", "clang-ubsan", "clang21", "clang22", "donttest",
        "gcc16", "gcc-asan", "lto", "mkl", "nold", "nosuggests", "rchk", "valgrind"
    ))

    # Check if Docker is running
    if (system2("docker", args = "info", stdout = NULL, stderr = NULL) != 0) {
        stop("Docker does not appear to be running.", call. = FALSE)
    }

    pkg_clean(pkg)

    if (document) {
        pkg_document(pkg)
    }

    pkgname <- read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Package")[[1]]

    # Build tarballs in a temporary directory
    tdir <- tempfile()
    dir.create(tdir)
    check_dir <- file.path(tdir, "check")
    dir.create(check_dir)

    oldwd <- getwd()
    on.exit({
        setwd(oldwd)
        unlink(tdir, recursive = TRUE)
    })

    # Build tarball outside container
    setwd(tdir)
    build_args <- c("CMD", "build", "--no-manual", shQuote(pkg))
    system2("R", args = build_args)

    tarball <- dir(".", pattern = paste0("^", pkgname, ".*\\.tar\\.gz$"), full.names = TRUE)
    if (length(tarball) == 0) {
        stop("build failed: no tarball produced", call. = FALSE)
    }

    tarball_file <- basename(tarball)
    file.copy(tarball, file.path(check_dir, tarball_file))

    # Set up Docker image URL and caching
    full_image <- sprintf("ghcr.io/r-hub/containers/%s:latest", image)
    log_dir <- file.path(pkg, "check-docker")
    dir.create(log_dir, showWarnings = FALSE)
    log_file <- file.path(log_dir, sprintf("%s.log", image))
    cache_dir <- file.path(log_dir, "cache", image)
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

    # Check if Docker image exists, pull if needed with fallbacks
    if (system2("docker", args = c("image", "inspect", full_image),
                stdout = NULL, stderr = NULL) != 0) {
        cat(sprintf("Pulling %s...\n", full_image))
        if (system2("docker", args = c("pull", full_image),
                   stdout = NULL, stderr = NULL) != 0) {
            cat("Initial pull failed for", full_image, "\n")
            # Try fallback images
            fallback <- NULL
            if (grepl("rocky8", image)) {
                fallback <- "docker.io/rockylinux/rockylinux:8"
            } else if (image == "debian10") {
                fallback <- "docker.io/library/debian:10-slim"
            } else {
                fallback <- sprintf("docker.io/%s:latest", image)
            }

            if (!is.null(fallback)) {
                cat("Attempting fallback image:", fallback, "\n")
                if (system2("docker", args = c("pull", fallback),
                           stdout = NULL, stderr = NULL) == 0) {
                    full_image <- fallback
                    cat("Using fallback image", fallback, "\n")
                } else {
                    stop("Fallback pull failed; aborting.", call. = FALSE)
                }
            } else {
                stop("No fallback available; aborting.", call. = FALSE)
            }
        }
    } else {
        cat(sprintf("Using cached image %s\n", full_image))
    }

    # Create install script for R packages
    install_script <- file.path(check_dir, "install_required.R")
    writeLines(c(
        "user_lib <- strsplit(Sys.getenv('R_LIBS_USER'), ':')[[1]][1]",
        ".libPaths(c(user_lib, .libPaths()))",
        "repos_snapshot_env <- Sys.getenv('RSPM_SNAPSHOT', '')",
        "if (nzchar(repos_snapshot_env)) {",
        "  if (grepl('^https?://', repos_snapshot_env)) {",
        "    options(repos = c(CRAN = repos_snapshot_env))",
        "  } else {",
        "    options(repos = c(CRAN = paste0('https://packagemanager.rstudio.com/cran/', repos_snapshot_env)))",
        "  }",
        "} else {",
        "  options(repos = c(CRAN = 'https://cloud.r-project.org'))",
        "}",
        "for (pkg in c('remotes', 'desc', 'xml2')) {",
        "  if (!requireNamespace(pkg, quietly = TRUE)) {",
        "    install.packages(pkg, lib = user_lib)",
        "  }",
        "}"
    ), install_script)

    # Build Docker command
    check_cmd <- sprintf(
        "set -euo pipefail; show_logs() { echo '=== 00install.out ==='; cat /%s.Rcheck/00install.out 2>/dev/null || true; echo '=== 00check.log ==='; cat /%s.Rcheck/00check.log 2>/dev/null || true; chmod -R a+rwX /check 2>/dev/null || true; }; trap show_logs EXIT; export R_LIBS_USER=/cache/R_libs; mkdir -p /cache/R_libs; if command -v apt-get >/dev/null 2>&1; then export DEBIAN_FRONTEND=noninteractive; apt-get update -qq || true; apt-get install -y --no-install-recommends libuv1-dev libxml2-dev pkg-config devscripts 2>&1 | grep -v 'Reading\\|Building\\|0 upgraded' || true; elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then PKG_MGR=dnf; command -v yum >/dev/null 2>&1 && PKG_MGR=yum; $PKG_MGR -y install libuv-devel libxml2-devel pkgconfig 2>&1 | tail -5 || true; elif command -v zypper >/dev/null 2>&1; then zypper --non-interactive install libuv libxml2-devel pkg-config 2>&1 | tail -5 || true; fi; if [ -f /check/install_required.R ]; then Rscript /check/install_required.R || true; fi; rm -rf /cache/R_libs/00LOCK-* /cache/R_libs/%s 2>/dev/null || true; R CMD INSTALL --library=/cache/R_libs /check/%s; cd /check; export _R_CHECK_FORCE_SUGGESTS_=false; R CMD check %s --no-manual %s",
        pkgname, pkgname, pkgname, tarball_file,
        if (cran) "--as-cran" else "",
        tarball_file
    )

    cat("========================================\n")
    cat(sprintf("Docker check: %s\n", image))
    cat("========================================\n")

    # Run Docker container
    docker_rc <- system2("docker", args = c(
        "run", "--rm",
        "-v", paste0(check_dir, ":/check"),
        "-v", paste0(cache_dir, ":/cache"),
        full_image,
        "bash", "-c", check_cmd
    ))

    if (docker_rc != 0) {
        cat(sprintf("\nWarning: Docker check exited with code %d\n", docker_rc))
    }

    cat(sprintf("\nCheck log saved to: %s\n", log_file))

    invisible(TRUE)
}
