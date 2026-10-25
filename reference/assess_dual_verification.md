# Assess Independent (Dual) Verification

Checks whether the submission declares independent verification of its
results, such as an SAS versus R comparison, QC double programming, or a
concordance report. The reproducibility guidance and real hybrid SAS/R
submissions treat independent verification of R results as first class:
it is how a reviewer is shown that the R output can be trusted. Returns
evidence with `indicator_id = "R-REPRO-009"`.

## Usage

``` r
assess_dual_verification(path, ctx = NULL, config = NULL)
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

This is a static check for the presence of verification evidence. To
compare two result tables directly, use
[`assess_sas_r_concordance()`](https://r4sub.github.io/r4subrepro/reference/assess_sas_r_concordance.md).

## Examples

``` r
d <- file.path(tempdir(), "sub009")
dir.create(d, showWarnings = FALSE)
writeLines("compare", file.path(d, "qc_compare_sas_r.txt"))
ev <- suppressMessages(assess_dual_verification(d))
ev$result
#> [1] "pass"
```
