# Assess Environment Lockfile Presence

Grades how well the submission captures its package environment, because
a reviewer must be able to reinstall the exact software stack. FDA
review guidance stresses that a version-pinned, transitive lockfile
(`renv.lock`) is what makes this possible, and that a plain top-level
dependency list is not enough. Returns R4SUB evidence with
`indicator_id = "R-REPRO-001"`:

## Usage

``` r
assess_env_lockfile(path, ctx = NULL, config = NULL)
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

A validated evidence table (see
[`r4subcore::as_evidence()`](https://r4sub.github.io/r4subcore/reference/as_evidence.html)).

## Details

- **pass** - a version-pinned `renv.lock` (or a `packrat` lockfile) is
  present.

- **warn** - an `renv.lock` with no package versions (a stub), or only a
  `DESCRIPTION` dependency list, which is not version-pinned.

- **fail** - no captured environment at all.

## Examples

``` r
d <- file.path(tempdir(), "sub001")
dir.create(d, showWarnings = FALSE)
writeLines(c('{ "R": { "Version": "4.4.1" },',
             '  "Packages": { "dplyr": { "Package": "dplyr", "Version": "1.1.4" } } }'),
           file.path(d, "renv.lock"))
ev <- suppressMessages(assess_env_lockfile(d))
ev$result
#> [1] "pass"
```
