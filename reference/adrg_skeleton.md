# Generate an ADRG Draft

Writes a Markdown Analysis Data Reviewer's Guide following the standard
PHUSE / R Consortium ADRG structure (sections 1 to 8 plus an R execution
appendix), pre-filled by statically scanning the submission folder. From
the scan it auto-fills the analysis datasets, the analysis output
programs and their outputs, a program-to-output traceability table of
the inputs each program reads, the proprietary and open-source R
packages split with versions, the R version, and the execution steps. It
also adds a Reproducibility and Verification section (environment, SAS
vs R verification, clean-run evidence) that the base ADRG template
omits. Sections needing human judgement are marked TODO. The draft
contains every section
[`assess_adrg()`](https://r4sub.github.io/r4subrepro/reference/assess_adrg.md)
checks for.

## Usage

``` r
adrg_skeleton(path = ".", out = NULL, config = NULL)
```

## Arguments

- path:

  Path to the submission's analysis code folder.

- out:

  Output file. When `NULL`, writes `ADRG.md` inside `path`.

- config:

  A configuration from
  [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md).

## Value

The path to the written file, invisibly.

## Examples

``` r
d <- file.path(tempdir(), "sub_adrg")
dir.create(d, showWarnings = FALSE)
writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "run.R"))
f <- adrg_skeleton(d)
#> ✔ Wrote ADRG draft to /tmp/RtmpKRiTPf/sub_adrg/ADRG.md
file.exists(f)
#> [1] TRUE
```
