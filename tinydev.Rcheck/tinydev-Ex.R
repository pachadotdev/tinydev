pkgname <- "tinydev"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
library('tinydev')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("check_cpp_compiler")
### * check_cpp_compiler

flush(stderr()); flush(stdout())

### Name: check_cpp_compiler
### Title: Check the C++ compiler
### Aliases: check_cpp_compiler

### ** Examples




cleanEx()
nameEx("pkg_template")
### * pkg_template

flush(stderr()); flush(stdout())

### Name: pkg_template
### Title: Start a new project with the cpp4r package template
### Aliases: pkg_template

### ** Examples

# create a new directory
dir <- tempdir()
dir.create(dir)

# copy the package template into the directory
pkg_template(dir, "mynewpkg")



### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
