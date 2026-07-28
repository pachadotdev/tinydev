#' @title Check the C++ compiler
#' @description Compile and load a minimal C++ shared library (a function
#'  equivalent to \code{function(a, b) a + b}) using \code{R CMD SHLIB}, to
#'  confirm that a working C++ compiler is available for building packages
#'  with compiled code (e.g. packages that use 'cpp4r'). Prints the compiler
#'  banner reported by \code{R CMD SHLIB} (e.g.
#'  \code{using C++ compiler: 'g++ (GCC) 15.2.1 20250813'}) and the result of
#'  a test call into the compiled function.
#' @return Invisibly returns a list with \code{compiler} (the compiler
#'  banner reported by \code{R CMD SHLIB}) and \code{result} (the result of
#'  the test C++ call, which should be \code{5}).
#' @examples
#' \donttest{
#' check_cpp_compiler()
#' }
#' @export
check_cpp_compiler <- function() {
    tmpdir <- tempfile("cpp-compiler-check-")
    dir.create(tmpdir)
    oldwd <- getwd()
    on.exit(setwd(oldwd), add = TRUE)
    on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)
    setwd(tmpdir)

    src_file <- "check_cpp_compiler.cpp"
    writeLines(c(
        "#include <R.h>",
        "#include <Rinternals.h>",
        "",
        "extern \"C\" SEXP add_nums(SEXP a, SEXP b) {",
        "    return Rf_ScalarReal(Rf_asReal(a) + Rf_asReal(b));",
        "}"
    ), src_file)

    out <- system2("R", c("CMD", "SHLIB", shQuote(src_file)), stdout = TRUE, stderr = TRUE)
    cat(out, sep = "\n")

    compiler_line <- grep("^using C\\+\\+ compiler:", out, value = TRUE)
    if (length(compiler_line) == 0) {
        stop("check_cpp_compiler(): C++ compilation failed; see output above.", call. = FALSE)
    }

    dll_pat <- if (.Platform$OS.type == "windows") "\\.dll$" else "\\.so$"
    dll <- dir(".", pattern = dll_pat, full.names = TRUE)
    if (length(dll) == 0) {
        stop("check_cpp_compiler(): C++ compilation did not produce a shared library.", call. = FALSE)
    }

    dll_info <- dyn.load(dll[1])
    on.exit(dyn.unload(dll_info[["path"]]), add = TRUE)

    symbol <- getNativeSymbolInfo("add_nums", dll_info)
    result <- .Call(symbol, 2, 3)

    message(compiler_line[1])
    message("add(2, 3) = ", result)

    invisible(list(compiler = compiler_line[1], result = result))
}
