# Assess Compiled-Code Toolchain

Checks whether the submission compiles native code and, if so, whether
it documents the compiler toolchain a reviewer needs to build it. FDA
reviewers run R on Windows with Rtools; CRAN packages install as
prebuilt Windows binaries and need no toolchain, but a submission that
ships C, C++, or Fortran source, a `src/` folder, a `Makevars` build
script, or an inline compilation call (`Rcpp::sourceCpp()`,
`cppFunction()`, `R CMD SHLIB`) must be built from source, which fails
on a reviewer's machine without the matching Rtools. Returns evidence
with `indicator_id = "R-REPRO-012"`:

## Usage

``` r
assess_compiled_toolchain(path, ctx = NULL, config = NULL)
```

## Arguments

- path:

  Path to the submission's analysis code folder.

- ctx:

  A run context from
  [`r4subcore::r4sub_run_context()`](https://r4sub.github.io/r4subcore/reference/r4sub_run_context.html).
  When `NULL` a default context is created from the folder name.

- config:

  A configuration from
  [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md).
  When `NULL` the default configuration is used.

## Value

A validated evidence table.

## Details

- **pass** - no native compilation (CRAN binaries suffice), or
  compilation is present and the Rtools toolchain is documented.

- **warn** - the submission compiles native code but does not document
  the Rtools toolchain needed to build it on Windows.

## Examples

``` r
d <- file.path(tempdir(), "sub012")
dir.create(d, showWarnings = FALSE)
writeLines("x <- dplyr::filter(mtcars, mpg > 20)", file.path(d, "a.R"))
ev <- suppressMessages(assess_compiled_toolchain(d))
ev$result
#> [1] "pass"
```
