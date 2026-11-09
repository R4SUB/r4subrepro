# r4subrepro

<!-- badges: start -->
[![R-CMD-check](https://github.com/R4SUB/r4subrepro/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/R4SUB/r4subrepro/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/r4subrepro)](https://CRAN.R-project.org/package=r4subrepro)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/r4subrepro)](https://CRAN.R-project.org/package=r4subrepro)
<!-- badges: end -->

**r4subrepro** scores the computational reproducibility and reviewer readiness of an R based regulatory submission. It statically inspects the analysis code folder and asks the questions a reviewer asks before trying to re-run anything: can the environment be reinstalled, do the paths work off this machine, is there one obvious script to run, are there hidden setup assumptions, are all packages declared, is there proof of a clean run, and is the code readable.

Results are emitted as standard R4SUB evidence rows (`indicator_domain = "usability"`) via `r4subcore`, so they flow straight into the Submission Confidence Index alongside the other reviewer-experience indicators from `r4subscore` and `r4subprofile`.

## Installation

```r
install.packages("r4subrepro")
```

Development version:

```r
pak::pak(c("R4SUB/r4subcore", "R4SUB/r4subrepro"))
```

## Indicators

| ID | Indicator | Checks |
|---|---|---|
| R-REPRO-001 | Environment lockfile present | a version-pinned `renv.lock`, packrat, or a `DESCRIPTION` dependency list |
| R-REPRO-002 | Path hygiene | absolute or OS-specific paths in scripts |
| R-REPRO-003 | Single entry point | a `run.R` / `main.R` style script exists |
| R-REPRO-004 | Hidden setup assumptions | `.Rprofile` / `.Renviron`, `Sys.setenv`, preloaded workspaces |
| R-REPRO-005 | Package reproducibility tiering | packages tiered by how reproducible their source is (CRAN, non-CRAN, undeclared) |
| R-REPRO-006 | Clean run evidence | a `sessionInfo()` capture or run log |
| R-REPRO-007 | Script complexity | brace nesting depth against a limit |
| R-REPRO-008 | Output reproduction | re-runs the entry point and compares outputs (opt-in; executes code) |
| R-REPRO-009 | Dual verification | declared independent verification, e.g. an SAS vs R comparison |
| R-REPRO-010 | Analysis Data Reviewer's Guide | an ADRG covering the required sections |
| R-REPRO-011 | Windows reviewability | non-portable constructs that break on a Windows reviewer machine |
| R-REPRO-012 | Compiled-code toolchain | native code compilation with the Rtools toolchain documented |

`assess_reproducibility()` runs the static indicators (all except the opt-in
`R-REPRO-008`, which executes submitted code and is enabled with
`include_execution = TRUE`).

## Quick Start

```r
library(r4subrepro)

# Point it at a submission's analysis code folder
ev  <- assess_reproducibility("path/to/submission")
res <- reproducibility_summary(ev)
res
```

## Key Functions

| Function | Purpose |
|---|---|
| `assess_reproducibility()` | Run the static indicators over a folder |
| `assess_env_lockfile()` | Environment lockfile present (R-REPRO-001) |
| `assess_path_hygiene()` | Absolute / OS-specific paths (R-REPRO-002) |
| `path_hygiene_report()` | Line-by-line advisory report of non-portable paths with suggested relative rewrites |
| `assess_entry_point()` | Single entry point (R-REPRO-003) |
| `assess_hidden_setup()` | Hidden setup assumptions (R-REPRO-004) |
| `assess_proprietary_pkgs()` | Package reproducibility tiering (R-REPRO-005) |
| `assess_clean_run_evidence()` | Clean run evidence (R-REPRO-006) |
| `assess_script_depth()` | Script complexity (R-REPRO-007) |
| `assess_output_reproduction()` | Re-run and compare outputs (R-REPRO-008, opt-in) |
| `assess_dual_verification()` | Independent verification declared (R-REPRO-009) |
| `assess_adrg()` | Analysis Data Reviewer's Guide present (R-REPRO-010) |
| `assess_windows_reviewability()` | Windows reviewability (R-REPRO-011) |
| `assess_compiled_toolchain()` | Compiled-code toolchain documented (R-REPRO-012) |
| `adrg_skeleton()` | Draft an ADRG from a static scan of the folder |
| `reproducibility_summary()` | Weighted summary of the evidence |
| `repro_report()` | Export the evidence and scores as a machine-readable JSON or Markdown report |
| `repro_config_default()` | Default thresholds and weights |

## Maintained by

R4SUB is part of the open-source work of [TechWorksLab](https://techworkslab.com) - clinical programming and regulatory submissions. Maintainer: Pawan Rama Mali.

## License

MIT

## Further reading

- [Making R submissions reviewable for FDA](https://r-consortium.org/posts/making-r-submissions-reviewable-for-fda/), the reproducibility guidance this package operationalizes, from the R Consortium.
- [R4SUB articles on the TECHWORKSLAB blog](https://techworkslab.com/insights)
