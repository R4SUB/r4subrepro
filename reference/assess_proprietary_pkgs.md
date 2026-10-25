# Assess Package Reproducibility Tiering

Extracts the packages referenced by the scripts and sorts them into
tiers by how reproducible their source is for a reviewer, rather than
treating the set as merely known or unknown. FDA review guidance
distinguishes CRAN packages (which a reviewer restores from a dated
snapshot) from non-CRAN GitHub, Git, URL, or local packages (which the
sponsor must bundle) and from undeclared proprietary packages (which
block a review entirely). The tiers are:

## Usage

``` r
assess_proprietary_pkgs(path, ctx = NULL, config = NULL)
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

- **CRAN / known** - in the bundled allowlist, or declared in
  `renv.lock` with a repository source: reproducible from a snapshot.

- **non-CRAN, declared** - declared in `renv.lock` with a GitHub, Git,
  URL, Bioconductor, or local source: reproducible only if the source is
  bundled.

- **proprietary / undeclared** - referenced but neither known nor
  declared anywhere: not reproducible as submitted.

The result is a **pass** when every package is CRAN or known, a
low-severity **warn** when the only non-CRAN packages are declared
(bundle the sources), and a medium-severity **warn** when any package is
undeclared. The check uses a bundled allowlist rather than a live CRAN
query, so it is deterministic and works offline. Returns evidence with
`indicator_id = "R-REPRO-005"`.

## Examples

``` r
d <- file.path(tempdir(), "sub005")
dir.create(d, showWarnings = FALSE)
writeLines("library(dplyr)", file.path(d, "a.R"))
ev <- suppressMessages(assess_proprietary_pkgs(d))
ev$result
#> [1] "pass"
```
