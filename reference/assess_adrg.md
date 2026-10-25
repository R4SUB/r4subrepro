# Assess the Analysis Data Reviewer's Guide (ADRG)

Checks that the submission includes an Analysis Data Reviewer's Guide
and, when the document is a readable text format, that it covers the
sections a reviewer needs: an executive summary, study data standards,
analysis datasets, conformance, programs, R packages, directory
structure, execution instructions, reproducibility/verification, and
troubleshooting. The reproducibility guidance and real hybrid SAS/R
submissions describe the ADRG as the reviewer's map to the analysis.
Returns evidence with `indicator_id = "R-REPRO-010"`.

## Usage

``` r
assess_adrg(path, ctx = NULL, config = NULL)
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

Binary documents (`.pdf`, `.docx`) are recognised as present but their
sections are not inspected, so they pass with a note. Use
[`adrg_skeleton()`](https://r4sub.github.io/r4subrepro/reference/adrg_skeleton.md)
to generate a Markdown ADRG draft that this check can read in full.

## Examples

``` r
d <- file.path(tempdir(), "sub010")
dir.create(d, showWarnings = FALSE)
suppressMessages(adrg_skeleton(d))
ev <- suppressMessages(assess_adrg(d))
ev$result
#> [1] "pass"
```
