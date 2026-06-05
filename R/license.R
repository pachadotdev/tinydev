copy_license <- function(pkgdir, lic) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    file.copy(lic, file.path(pkg, "LICENSE.txt"), overwrite = TRUE)
    rbuildignore_add("^LICENSE\\.txt$")
    try(file.remove("LICENSE"), silent = TRUE) # remove old LICENSE if exists
    invisible(TRUE)
}

clause_license <- function(pkgdir, lic, year, copyright_holder, organization = NULL) {
    pkg <- normalizePath(pkgdir, winslash = "/")
    stop_if_not_package(pkg)
    lic <- readLines(lic)
    lic <- gsub("<YEAR>", year, lic)
    lic <- gsub("<COPYRIGHT HOLDER>", copyright_holder, lic)
    writeLines(lic, file.path(pkg, "LICENSE.txt"))
    stub <- c(paste0("YEAR: ", year), paste0("COPYRIGHT HOLDER: ", copyright_holder))
    if (!is.null(organization)) stub <- c(stub, paste0("ORGANIZATION: ", organization))
    writeLines(stub, file.path(pkg, "LICENSE"))
    rbuildignore_add("^LICENSE\\.txt$")
    invisible(TRUE)
}

add_license_to_desc <- function(spec) {
    desc_set("License", spec)
    invisible(TRUE)
}

#' @title AGPL-3.0 License
#' @description Add AGPL-3.0 license to a package.
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @return Invisibly returns 'TRUE' if license was added successfully.
#' @rdname license
#' @export
license_agpl <- function(pkgdir = ".") {
    lic <- system.file("licenses/AGPL-3_0.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("AGPL-3")
}

#' @title Apache 2.0 License
#' @description Add Apache 2.0 license to a package.
#' @rdname license
#' @export
license_apache <- function(pkgdir = ".") {
    lic <- system.file("licenses/Apache-2_0.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("Apache License 2.0")
}

#' @title Artistic 2.0 License
#' @description Add Artistic 2.0 license to a package.
#' @rdname license
#' @export
license_artistic <- function(pkgdir = ".") {
    lic <- system.file("licenses/Artistic-2_0.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("Artistic-2.0")
}

#' @title CC0 1.0 License
#' @description Add CC0 1.0 license to a package
#' @rdname license
#' @export
license_cc0 <- function(pkgdir = ".") {
    lic <- system.file("licenses/CC0-1_0.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("CC0")
}

#' @title GPL 2 License
#' @description Add GPL 2 license to a package
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @rdname license
#' @export
license_gpl2 <- function(pkgdir = ".") {
    lic <- system.file("licenses/GPL-2.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("GPL-2")
}

#' @title GPL 3 Clause License
#' @description Add GPL 3 license to a package
#' @rdname license
#' @export
license_gpl3 <- function(pkgdir = ".") {
    lic <- system.file("licenses/GPL-3.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("GPL-3")
}

#' @title LGPL 2 License
#' @description Add LGPL 2 license to a package
#' @param pkgdir The path to the package directory. Defaults to the current directory.
#' @rdname license
#' @export
license_lgpl2 <- function(pkgdir = ".") {
    lic <- system.file("licenses/LGPL-2_1.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("LGPL-2.1")
}

#' @title LGPL 3 License
#' @description Add LGPL 3 license to a package
#' @rdname license
#' @export
license_lgpl3 <- function(pkgdir = ".") {
    lic <- system.file("licenses/LGPL-3.txt", package = "tinydev")
    copy_license(pkgdir, lic)
    add_license_to_desc("LGPL-3")
}

#' @title BSD 2 Clause License
#' @description Add BSD 2 license to a package plus 'LICENSE' file
#' @param year Year (e.g., 2026)
#' @param copyright_holder Copyright holder (e.g, "package XYZ authors")
#' @rdname license
#' @export
license_bsd2 <- function(pkgdir = ".", year = NULL, copyright_holder = NULL) {
    # specify as:
    # License: BSD_2_clause + file LICENSE
    stopifnot(!is.null(year), !is.null(copyright_holder))
    lic <- system.file("licenses/BSD_2.txt", package = "tinydev")
    clause_license(pkgdir, lic, year, copyright_holder, NULL)
    add_license_to_desc("BSD_2_clause + file LICENSE")
}

#' @title BSD 3 Clause License
#' @description Add BSD 3 license to a package plus 'LICENSE' file
#' @param organization Organization (e.g., "University of Surrey")
#' @rdname license
#' @export
license_bsd3 <- function(pkgdir = ".", year = NULL, copyright_holder = NULL, organization = NULL) {
    # specify as:
    # License: BSD_3_clause + file LICENSE
    stopifnot(!is.null(year), !is.null(copyright_holder))
    lic <- system.file("licenses/BSD_3.txt", package = "tinydev")
    clause_license(pkgdir, lic, year, copyright_holder, organization)
    add_license_to_desc("BSD_3_clause + file LICENSE")
}

#' @title MIT License
#' @description Add MIT license to a package plus 'LICENSE' file
#' @rdname license
#' @export
license_mit <- function(pkgdir = ".", year = NULL, copyright_holder = NULL) {
    # specify as:
    # License: MIT + file LICENSE
    stopifnot(!is.null(year), !is.null(copyright_holder))
    lic <- system.file("licenses/MIT.txt", package = "tinydev")
    clause_license(lic, year, copyright_holder)
    add_license_to_desc("MIT + file LICENSE")
}
