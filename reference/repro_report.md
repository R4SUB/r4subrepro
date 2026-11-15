# Export a Machine-Readable Reproducibility Report

Renders the evidence from
[`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md)
and the scores from
[`reproducibility_summary()`](https://r4sub.github.io/r4subrepro/reference/reproducibility_summary.md)
into a portable report, as either a JSON string (via 'jsonlite') or a
Markdown summary string. This is a reporting layer only: it reads the
existing evidence and scores without changing any indicator logic,
thresholds, weights, or results. The report is **decision-support** to
help prepare a submission; it is not an official submission artifact and
does not represent regulatory review.

## Usage

``` r
repro_report(x, format = c("json", "markdown"), file = NULL, config = NULL)
```

## Arguments

- x:

  Either a validated evidence table from
  [`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md)
  (or an individual assessment function), or a `repro_result` from
  [`reproducibility_summary()`](https://r4sub.github.io/r4subrepro/reference/reproducibility_summary.md).
  When an evidence table is passed, it is scored with
  [`reproducibility_summary()`](https://r4sub.github.io/r4subrepro/reference/reproducibility_summary.md)
  using `config`.

- format:

  Output format: `"json"` (default) or `"markdown"`.

- file:

  Optional path to write the rendered report to. When supplied, the
  report is written there and the path is returned invisibly; otherwise
  the rendered string is returned.

- config:

  A configuration from
  [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md),
  used only when `x` is an evidence table that must be scored. When
  `NULL` the default configuration is used.

## Value

A single character string with the rendered report, or, when `file` is
supplied, the path to the written file (invisibly).

## Details

The JSON document carries a `report_type`, a `schema_version`, the
generation time, the disclaimer, the source package and version, the
study id, the weighted overall score (as a fraction and a percentage),
the pass/warn/fail counts, and an `indicators` array with one object per
indicator (`indicator_id`, `indicator_name`, `result`, `severity`,
`score`, `metric_value`, `metric_unit`, `message`, `location`). The
Markdown rendering presents the same evidence as a header block, the
overall score, and a table of indicators.

## See also

[`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md),
[`reproducibility_summary()`](https://r4sub.github.io/r4subrepro/reference/reproducibility_summary.md)

## Examples

``` r
d <- file.path(tempdir(), "sub_report")
dir.create(d, showWarnings = FALSE)
writeLines(c('{ "R": { "Version": "4.4.1" },',
             '  "Packages": { "dplyr": { "Package": "dplyr", "Version": "1.1.4" } } }'),
           file.path(d, "renv.lock"))
writeLines("source('a.R')", file.path(d, "run.R"))
writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
ev <- suppressMessages(assess_reproducibility(d))

# JSON string (machine-readable)
cat(repro_report(ev, format = "json"))
#> {
#>   "report_type": "r4subrepro reproducibility report",
#>   "schema_version": "1",
#>   "generated": "2026-11-15T07:30:30+0000",
#>   "disclaimer": "Decision-support only: this report summarises automated indicator evidence to help prepare a submission. It is not an official submission artifact and does not represent regulatory review or approval.",
#>   "source": {
#>     "name": "r4subrepro",
#>     "version": "0.4.1"
#>   },
#>   "study_id": "sub_report",
#>   "overall_score": 0.8352,
#>   "overall_score_pct": 83.5,
#>   "counts": {
#>     "indicators": 11,
#>     "pass": 8,
#>     "warn": 2,
#>     "fail": 1
#>   },
#>   "indicators": [
#>     {
#>       "indicator_id": "R-REPRO-001",
#>       "indicator_name": "Environment Lockfile Present",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 1,
#>       "metric_unit": "present",
#>       "message": "Version-pinned lockfile found: renv.lock",
#>       "location": "/tmp/RtmpXgcl4F/sub_report/renv.lock"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-002",
#>       "indicator_name": "Path Hygiene",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 0,
#>       "metric_unit": "hits",
#>       "message": "No absolute or OS-specific paths found in scripts",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-003",
#>       "indicator_name": "Single Entry Point",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 1,
#>       "metric_unit": "present",
#>       "message": "Entry point found: run.R",
#>       "location": "run.R"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-004",
#>       "indicator_name": "Hidden Setup Assumptions",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 1,
#>       "metric_unit": "score",
#>       "message": "No hidden setup assumptions detected",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-005",
#>       "indicator_name": "Package Reproducibility Tiering",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 0,
#>       "metric_unit": "packages",
#>       "message": "All referenced packages are CRAN or known-reproducible",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-006",
#>       "indicator_name": "Clean Run Evidence",
#>       "result": "warn",
#>       "severity": "low",
#>       "score": 0.5,
#>       "metric_value": 0,
#>       "metric_unit": "present",
#>       "message": "No sessionInfo capture or run log found",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-007",
#>       "indicator_name": "Script Complexity",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 0,
#>       "metric_unit": "depth",
#>       "message": "Deepest nesting is 0 (limit 6)",
#>       "location": "a.R"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-009",
#>       "indicator_name": "Dual Verification",
#>       "result": "warn",
#>       "severity": "medium",
#>       "score": 0.5,
#>       "metric_value": 0,
#>       "metric_unit": "artifacts",
#>       "message": "No independent verification evidence (e.g. SAS vs R comparison or QC report) declared",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-010",
#>       "indicator_name": "Analysis Data Reviewer's Guide",
#>       "result": "fail",
#>       "severity": "medium",
#>       "score": 0,
#>       "metric_value": 0,
#>       "metric_unit": "sections",
#>       "message": "No ADRG (Analysis Data Reviewer's Guide) document found",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-011",
#>       "indicator_name": "Windows Reviewability",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 0,
#>       "metric_unit": "hits",
#>       "message": "No Windows-portability risks detected in scripts",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     },
#>     {
#>       "indicator_id": "R-REPRO-012",
#>       "indicator_name": "Compiled-Code Toolchain",
#>       "result": "pass",
#>       "severity": "info",
#>       "score": 1,
#>       "metric_value": 0,
#>       "metric_unit": "signals",
#>       "message": "No native compilation; CRAN packages install as prebuilt Windows binaries, so no Rtools toolchain is required",
#>       "location": "/tmp/RtmpXgcl4F/sub_report"
#>     }
#>   ]
#> }

# Markdown summary string
cat(repro_report(ev, format = "markdown"))
#> # R4SUB Reproducibility Report
#> 
#> - Study: sub_report
#> - Indicators assessed: 11
#> - Generated: 2026-11-15T07:30:30+0000
#> - Source: r4subrepro 0.4.1
#> 
#> > Decision-support only: this report summarises automated indicator evidence to help prepare a submission. It is not an official submission artifact and does not represent regulatory review or approval.
#> 
#> ## Overall
#> 
#> Overall reproducibility score: 83.5% (8 pass, 2 warn, 1 fail)
#> 
#> ## Indicators
#> 
#> | Indicator | Name | Result | Severity | Score | Detail |
#> | --- | --- | --- | --- | --- | --- |
#> | R-REPRO-001 | Environment Lockfile Present | pass | info | 1 | Version-pinned lockfile found: renv.lock |
#> | R-REPRO-002 | Path Hygiene | pass | info | 1 | No absolute or OS-specific paths found in scripts |
#> | R-REPRO-003 | Single Entry Point | pass | info | 1 | Entry point found: run.R |
#> | R-REPRO-004 | Hidden Setup Assumptions | pass | info | 1 | No hidden setup assumptions detected |
#> | R-REPRO-005 | Package Reproducibility Tiering | pass | info | 1 | All referenced packages are CRAN or known-reproducible |
#> | R-REPRO-006 | Clean Run Evidence | warn | low | 0.5 | No sessionInfo capture or run log found |
#> | R-REPRO-007 | Script Complexity | pass | info | 1 | Deepest nesting is 0 (limit 6) |
#> | R-REPRO-009 | Dual Verification | warn | medium | 0.5 | No independent verification evidence (e.g. SAS vs R comparison or QC report) declared |
#> | R-REPRO-010 | Analysis Data Reviewer's Guide | fail | medium | 0 | No ADRG (Analysis Data Reviewer's Guide) document found |
#> | R-REPRO-011 | Windows Reviewability | pass | info | 1 | No Windows-portability risks detected in scripts |
#> | R-REPRO-012 | Compiled-Code Toolchain | pass | info | 1 | No native compilation; CRAN packages install as prebuilt Windows binaries, so no Rtools toolchain is required |

# From a scored result, written to a file
res <- reproducibility_summary(ev)
f <- repro_report(res, format = "json", file = file.path(d, "repro.json"))
#> ✔ Wrote reproducibility report to /tmp/RtmpXgcl4F/sub_report/repro.json
file.exists(f)
#> [1] TRUE
```
