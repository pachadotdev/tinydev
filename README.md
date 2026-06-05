# tinydev

*tinydev* is to *devtools* what *tinytest* is to *testthat*.

# How to use tinydev?

Run `tinydev::pkg_template("<PACKAGE_NAME>")`.

Go to the new package directory (e.g., `cd ~/Documents/<PACKAGE_NAME>` from bash or `setwd(~/Documents/<PACKAGE_NAME>)` from R).

## Minimal steps to get a working package

1. Add a package license. I provide templates for all CRAN-supported (see note 1) licenses,
   run `license_apache()` or any of the `license_*()` provided functions.
2. Add your name, email, Orcid, etc. to DESCRIPTION
3. Edit `R/` to add substantive code.

## Quick testing

1. Run `tinydev::pkg_load()` and test your functions to see if it behaves as expected.
2. Convert such tests to proper unit tests in `inst/tinytest`.
3. Test the changes with `tinydev::pkg_test()`.

## Local installation

Run `tinydev::pkg_install()`.

## Submit to CRAN

1. Run a full CRAN-compliant check with `tinydev::pkg_check()`.
2. If all checks pass, build the package tar with `tinydev::pkg_build()`.

# Additional functions

1. `clear()` cleans the console.
2. `pkg_clean()` removes compiled binaries in `src/`.
3. `description_update()` will add missing Imports/Suggests and remove those not needed after editing the package.
4. `rbuildignore_add()` adds files or directories to `.Rbuildignore`.

# Tinytest

[tinytest](https://github.com/markvanderloo/tinytest/blob/master/pkg/README.md) is
an amazing package that simplifies working with clusters a lot as it uses minimal dependencies.

# CRAN-supported licenses

To see an overview, please visit [tl;dr Legal](https://www.tldrlegal.com/) but also check with your institution for funded
projects.

Plain licenses:

* The "GNU Affero General Public License" version 3 (AGPL-3)
* The "Apache License" version 2.0 (Apache-2.0)
* The "Artistic License" version 2.0 (Artistic-2.0)
* The "Creative Commons Zero Universal" license version 1.0 (CC0-1.0)
* The "GNU General Public License" version 2 (GPL-2)
* The "GNU General Public License" version 3 (GPL-3)
* The "GNU Lesser General Public License" version 2.1 (LGPL-2.1) - this one supersedes the The "GNU Library General Public License" version 2 (LGPL-2)
* The "GNU Lesser General Public License" version 3 (LGPL-3)

```R
license_agpl3()
license_apache()
license_artistic()
license_cc0()
license_gpl2()
license_gpl3()
license_lgpl2()
license_lgpl3()
```

Requires year and author:

* The "BSD 2-clause License" (BSD_2_clause)
* The "MIT License" (MIT)

```R
license_bsd2(2026, "Pacha")
license_mit(2026, "Pacha")
```

Requires year and copyright holder.

* The "BSD 3-clause License" (BSD_3_clause)

```R
license_bsd3(2026, "Pacha", "University of Surrey")
```
