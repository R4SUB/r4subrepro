# r4subrepro

**r4subrepro** scores the computational reproducibility and reviewer
readiness of an R based regulatory submission. It statically inspects
the analysis code folder and asks the questions a reviewer asks before
trying to re-run anything: can the environment be reinstalled, do the
paths work off this machine, is there one obvious script to run, are
there hidden setup assumptions, are all packages declared, is there
proof of a clean run, and is the code readable.

Results are emitted as standard R4SUB evidence rows
(`indicator_domain = "usability"`) via `r4subcore`, so they flow
straight into the Submission Confidence Index alongside the other
reviewer-experience indicators from `r4subscore` and `r4subprofile`.

## Installation

``` r

install.packages("r4subrepro")
```

Development version:

``` r

pak::pak(c("R4SUB/r4subcore", "R4SUB/r4subrepro"))
```

## Indicators

| ID | Indicator | Checks |
|----|----|----|
| R-REPRO-001 | Environment lockfile present | a version-pinned `renv.lock`, packrat, or a `DESCRIPTION` dependency list |
| R-REPRO-002 | Path hygiene | absolute or OS-specific paths in scripts |
| R-REPRO-003 | Single entry point | a `run.R` / `main.R` style script exists |
| R-REPRO-004 | Hidden setup assumptions | `.Rprofile` / `.Renviron`, `Sys.setenv`, preloaded workspaces |
| R-REPRO-005 | Package reproducibility tiering | packages tiered by how reproducible their source is (CRAN, non-CRAN, undeclared) |
| R-REPRO-006 | Clean run evidence | a [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) capture or run log |
| R-REPRO-007 | Script complexity | brace nesting depth against a limit |
| R-REPRO-008 | Output reproduction | re-runs the entry point and compares outputs (opt-in; executes code) |
| R-REPRO-009 | Dual verification | declared independent verification, e.g. an SAS vs R comparison |
| R-REPRO-010 | Analysis Data Reviewer’s Guide | an ADRG covering the required sections |
| R-REPRO-011 | Windows reviewability | non-portable constructs that break on a Windows reviewer machine |
| R-REPRO-012 | Compiled-code toolchain | native code compilation with the Rtools toolchain documented |

[`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md)
runs the static indicators (all except the opt-in `R-REPRO-008`, which
executes submitted code and is enabled with `include_execution = TRUE`).

## Quick Start

``` r

library(r4subrepro)

# Point it at a submission's analysis code folder
ev  <- assess_reproducibility("path/to/submission")
res <- reproducibility_summary(ev)
res
```

## Key Functions

| Function | Purpose |
|----|----|
| [`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md) | Run the static indicators over a folder |
| [`assess_env_lockfile()`](https://r4sub.github.io/r4subrepro/reference/assess_env_lockfile.md) | Environment lockfile present (R-REPRO-001) |
| [`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md) | Absolute / OS-specific paths (R-REPRO-002) |
| [`assess_entry_point()`](https://r4sub.github.io/r4subrepro/reference/assess_entry_point.md) | Single entry point (R-REPRO-003) |
| [`assess_hidden_setup()`](https://r4sub.github.io/r4subrepro/reference/assess_hidden_setup.md) | Hidden setup assumptions (R-REPRO-004) |
| [`assess_proprietary_pkgs()`](https://r4sub.github.io/r4subrepro/reference/assess_proprietary_pkgs.md) | Package reproducibility tiering (R-REPRO-005) |
| [`assess_clean_run_evidence()`](https://r4sub.github.io/r4subrepro/reference/assess_clean_run_evidence.md) | Clean run evidence (R-REPRO-006) |
| [`assess_script_depth()`](https://r4sub.github.io/r4subrepro/reference/assess_script_depth.md) | Script complexity (R-REPRO-007) |
| [`assess_output_reproduction()`](https://r4sub.github.io/r4subrepro/reference/assess_output_reproduction.md) | Re-run and compare outputs (R-REPRO-008, opt-in) |
| [`assess_dual_verification()`](https://r4sub.github.io/r4subrepro/reference/assess_dual_verification.md) | Independent verification declared (R-REPRO-009) |
| [`assess_adrg()`](https://r4sub.github.io/r4subrepro/reference/assess_adrg.md) | Analysis Data Reviewer’s Guide present (R-REPRO-010) |
| [`assess_windows_reviewability()`](https://r4sub.github.io/r4subrepro/reference/assess_windows_reviewability.md) | Windows reviewability (R-REPRO-011) |
| [`assess_compiled_toolchain()`](https://r4sub.github.io/r4subrepro/reference/assess_compiled_toolchain.md) | Compiled-code toolchain documented (R-REPRO-012) |
| [`adrg_skeleton()`](https://r4sub.github.io/r4subrepro/reference/adrg_skeleton.md) | Draft an ADRG from a static scan of the folder |
| [`reproducibility_summary()`](https://r4sub.github.io/r4subrepro/reference/reproducibility_summary.md) | Weighted summary of the evidence |
| [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md) | Default thresholds and weights |

## Maintained by

R4SUB is part of the open-source work of
[TechWorksLab](https://techworkslab.com) - clinical programming and
regulatory submissions. Maintainer: Pawan Rama Mali.

## License

MIT

## Further reading

- [Making R submissions reviewable for
  FDA](https://r-consortium.org/posts/making-r-submissions-reviewable-for-fda/),
  the reproducibility guidance this package operationalizes, from the R
  Consortium.
- [R4SUB articles on the TECHWORKSLAB
  blog](https://techworkslab.com/insights)
