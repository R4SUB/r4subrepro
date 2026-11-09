# Getting started with r4subrepro

`r4subrepro` scores the computational reproducibility and reviewer
readiness of an R based regulatory submission. It inspects the analysis
code folder *statically*, without running any submitted code, and asks
the questions a reviewer asks before trying to re-run anything:

- can the package environment be reinstalled,
- do the file paths work off the author’s machine,
- is there one obvious script to run,
- are there hidden setup assumptions,
- are all packages declared,
- is there proof of a clean run,
- is the code readable,
- are the results independently verified,
- is there a reviewer’s guide,
- will the code run on the reviewer’s Windows machine, and
- is any compiled native code documented.

Each check emits a standard R4SUB evidence row
(`indicator_domain = "usability"`) via `r4subcore`, so the results flow
straight into the Submission Confidence Index alongside the other R4SUB
packages.

``` r

library(r4subrepro)
```

## A worked example

The assessment functions take a path to a submission’s analysis code
folder. To keep this vignette self-contained we build a small synthetic
submission in a temporary directory. A real submission would be the
analysis folder you are preparing for the agency.

``` r

sub <- file.path(tempdir(), "demo_submission")
dir.create(sub, showWarnings = FALSE)
dir.create(file.path(sub, "data"), showWarnings = FALSE)

# A version-pinned environment lockfile (R-REPRO-001).
writeLines(c(
  '{ "R": { "Version": "4.4.1" },',
  '  "Packages": { "dplyr": { "Package": "dplyr", "Version": "1.1.4" } } }'
), file.path(sub, "renv.lock"))

# A single, obvious entry point (R-REPRO-003) using relative paths (R-REPRO-002).
writeLines(c(
  "source('load.R')",
  "source('analysis.R')"
), file.path(sub, "run.R"))

writeLines(c(
  "library(dplyr)",
  "adsl <- read.csv('data/adsl.csv')"
), file.path(sub, "load.R"))

writeLines(c(
  "result <- adsl",
  "if (nrow(result) > 0) message('ok')"
), file.path(sub, "analysis.R"))

# Evidence of a clean run (R-REPRO-006).
writeLines(c("R version 4.4.1", "attached packages: dplyr"),
           file.path(sub, "sessionInfo.txt"))
```

## Running the full assessment

[`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md)
runs the static indicators over the folder and returns a combined
evidence table.

``` r

ev <- assess_reproducibility(sub)
#> ℹ Run context created: "R4S-20261109181121-wl4dieex"
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Evidence table created: 1 row
#> ✔ Bound 11 evidence tables: 11 total rows
ev[, c("indicator_id", "indicator_name", "result", "severity")]
#>    indicator_id                  indicator_name result severity
#> 1   R-REPRO-001    Environment Lockfile Present   pass     info
#> 2   R-REPRO-002                    Path Hygiene   pass     info
#> 3   R-REPRO-003              Single Entry Point   pass     info
#> 4   R-REPRO-004        Hidden Setup Assumptions   pass     info
#> 5   R-REPRO-005 Package Reproducibility Tiering   pass     info
#> 6   R-REPRO-006              Clean Run Evidence   pass     info
#> 7   R-REPRO-007               Script Complexity   pass     info
#> 8   R-REPRO-009               Dual Verification   warn   medium
#> 9   R-REPRO-010  Analysis Data Reviewer's Guide   fail   medium
#> 10  R-REPRO-011           Windows Reviewability   pass     info
#> 11  R-REPRO-012         Compiled-Code Toolchain   pass     info
```

By default the scan stays static and never executes any submitted code.
The optional output-reproduction check (`R-REPRO-008`), which does
re-run the submission’s entry point in a sandboxed session, is opt-in
through `include_execution = TRUE`.

## Summarising the result

[`reproducibility_summary()`](https://r4sub.github.io/r4subrepro/reference/reproducibility_summary.md)
turns the evidence into a weighted score with a readable print method.

``` r

res <- reproducibility_summary(ev)
res
#> 
#> ── R4SUB Reproducibility Assessment ──
#> 
#> Study: "demo_submission" | Indicators: 11
#> 
#> ✔ R-REPRO-001 Environment Lockfile Present: pass
#> ✔ R-REPRO-002 Path Hygiene: pass
#> ✔ R-REPRO-003 Single Entry Point: pass
#> ✔ R-REPRO-004 Hidden Setup Assumptions: pass
#> ✔ R-REPRO-005 Package Reproducibility Tiering: pass
#> ✔ R-REPRO-006 Clean Run Evidence: pass
#> ✔ R-REPRO-007 Script Complexity: pass
#> ! R-REPRO-009 Dual Verification: warn
#> ✖ R-REPRO-010 Analysis Data Reviewer's Guide: fail
#> ✔ R-REPRO-011 Windows Reviewability: pass
#> ✔ R-REPRO-012 Compiled-Code Toolchain: pass
#> 
#> ℹ Overall reproducibility score: 85.8% (9 pass, 1 warn, 1 fail)
```

The summary object carries the per-indicator breakdown and the overall
score, which you can use in downstream reporting:

``` r

res$overall_score
#> [1] 0.8579545
res$summary
#>    indicator_id                  indicator_name result severity score
#> 1   R-REPRO-001    Environment Lockfile Present   pass     info   1.0
#> 2   R-REPRO-002                    Path Hygiene   pass     info   1.0
#> 3   R-REPRO-003              Single Entry Point   pass     info   1.0
#> 4   R-REPRO-004        Hidden Setup Assumptions   pass     info   1.0
#> 5   R-REPRO-005 Package Reproducibility Tiering   pass     info   1.0
#> 6   R-REPRO-006              Clean Run Evidence   pass     info   1.0
#> 7   R-REPRO-007               Script Complexity   pass     info   1.0
#> 8   R-REPRO-009               Dual Verification   warn   medium   0.5
#> 9   R-REPRO-010  Analysis Data Reviewer's Guide   fail   medium   0.0
#> 10  R-REPRO-011           Windows Reviewability   pass     info   1.0
#> 11  R-REPRO-012         Compiled-Code Toolchain   pass     info   1.0
```

## Running a single indicator

Every indicator is also exported on its own, which is handy when you
want to focus on one aspect. For example, to check only the environment
lockfile:

``` r

lock <- assess_env_lockfile(sub)
#> ℹ Run context created: "R4S-20261109181122-ombeu7fd"
#> ✔ Evidence table created: 1 row
lock[, c("indicator_id", "result", "message")]
#>   indicator_id result                                  message
#> 1  R-REPRO-001   pass Version-pinned lockfile found: renv.lock
```

The full indicator set is:
[`assess_env_lockfile()`](https://r4sub.github.io/r4subrepro/reference/assess_env_lockfile.md),
[`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md),
[`assess_entry_point()`](https://r4sub.github.io/r4subrepro/reference/assess_entry_point.md),
[`assess_hidden_setup()`](https://r4sub.github.io/r4subrepro/reference/assess_hidden_setup.md),
[`assess_proprietary_pkgs()`](https://r4sub.github.io/r4subrepro/reference/assess_proprietary_pkgs.md),
[`assess_clean_run_evidence()`](https://r4sub.github.io/r4subrepro/reference/assess_clean_run_evidence.md),
[`assess_script_depth()`](https://r4sub.github.io/r4subrepro/reference/assess_script_depth.md),
[`assess_dual_verification()`](https://r4sub.github.io/r4subrepro/reference/assess_dual_verification.md),
[`assess_adrg()`](https://r4sub.github.io/r4subrepro/reference/assess_adrg.md),
[`assess_windows_reviewability()`](https://r4sub.github.io/r4subrepro/reference/assess_windows_reviewability.md),
[`assess_compiled_toolchain()`](https://r4sub.github.io/r4subrepro/reference/assess_compiled_toolchain.md),
and the opt-in
[`assess_output_reproduction()`](https://r4sub.github.io/r4subrepro/reference/assess_output_reproduction.md).

## Tuning the thresholds

[`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md)
returns the thresholds and per-indicator weights used by the assessment.
You can inspect them and pass a modified configuration to any assessment
function via the `config` argument.

``` r

cfg <- repro_config_default()
cfg$max_script_depth
#> [1] 6
cfg$weights$path_hygiene
#> [1] 0.12
```

## Drafting a reviewer’s guide

[`adrg_skeleton()`](https://r4sub.github.io/r4subrepro/reference/adrg_skeleton.md)
writes a draft Analysis Data Reviewer’s Guide (ADRG) in the standard
PHUSE / R Consortium structure, pre-filled from a static scan of the
folder. Lines that need human judgement are marked `TODO` for the
sponsor to complete.

``` r

guide <- adrg_skeleton(sub, out = file.path(tempdir(), "ADRG.md"))
#> ✔ Wrote ADRG draft to /tmp/RtmpKkEfVi/ADRG.md
basename(guide)
#> [1] "ADRG.md"
```

Once you have filled in the draft,
[`assess_adrg()`](https://r4sub.github.io/r4subrepro/reference/assess_adrg.md)
checks that the guide covers every required section.
