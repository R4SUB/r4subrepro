# Assess Output Reproduction

Re-runs the submission's entry point in a fresh R session and checks
that the outputs it produces match the submitted outputs. This is the
executable counterpart to
[`assess_clean_run_evidence()`](https://r4sub.github.io/r4subrepro/reference/assess_clean_run_evidence.md),
which only checks that a run log is present. Returns evidence with
`indicator_id = "R-REPRO-008"`.

## Usage

``` r
assess_output_reproduction(
  path,
  expected = NULL,
  entry = NULL,
  ctx = NULL,
  config = NULL,
  run = NULL,
  timeout = NULL
)
```

## Arguments

- path:

  Path to the submission's analysis code folder.

- expected:

  Name of the subfolder, relative to `path`, holding the submitted
  outputs to reproduce. Defaults to `config$expected_output_dir`.

- entry:

  Entry point script to run, relative to `path`. When `NULL` the first
  file matching `config$entry_point_names` is used.

- ctx:

  A run context from
  [`r4subcore::r4sub_run_context()`](https://r4sub.github.io/r4subcore/reference/r4sub_run_context.html).
  When `NULL` a default context is created from the folder name.

- config:

  A configuration from
  [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md).
  When `NULL` the default configuration is used.

- run:

  Whether to execute the entry point. When `NULL` (default), execution
  happens only in an interactive session with 'callr' installed, so
  examples, tests, and CRAN do not run submission code unless asked.

- timeout:

  Maximum seconds to allow the run. Defaults to `config$run_timeout`.

## Value

A validated evidence table.

## Details

Comparison separates analytical content from cosmetic bytes. Data
outputs (CSV, text) must match byte for byte, but formatted outputs
(`rtf`, `pdf`; see `config$cosmetic_output_ext`) embed a generation
timestamp that changes on every run, so those are compared after the
timestamps are stripped. An output that differs only in its embedded
time still counts as reproduced, and the message says so; only a
difference in the actual results is a failure.

Execution is opt-in and sandboxed. The folder is copied to a temporary
location and the entry point runs in a separate R session (via 'callr')
with a timeout, so nothing in the submission folder is modified. The
submitted outputs under `expected` are hashed from the original folder
and compared to the files the re-run produces in the copy. When
`run = FALSE`, or 'callr' is not installed, no code runs and the
indicator returns `na`, which keeps the check safe offline and on CRAN.
When the outputs reproduce but the run happened on a non-Windows OS, the
result is a `warn`, since FDA reviewers execute on Windows and the
outputs must reproduce there.

## Examples

``` r
d <- file.path(tempdir(), "sub008")
dir.create(file.path(d, "outputs"), recursive = TRUE, showWarnings = FALSE)
writeLines("writeLines('1', 'outputs/res.txt')", file.path(d, "run.R"))
writeLines("1", file.path(d, "outputs", "res.txt"))
ev <- suppressMessages(assess_output_reproduction(d, run = FALSE))
ev$result
#> [1] "na"
# \donttest{
if (requireNamespace("callr", quietly = TRUE)) {
  ev2 <- suppressMessages(assess_output_reproduction(d, run = TRUE))
  ev2$result
}
#> [1] "warn"
# }
```
