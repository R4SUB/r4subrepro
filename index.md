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
| R-REPRO-001 | Environment lockfile present | `renv.lock`, packrat, or a versioned `DESCRIPTION` |
| R-REPRO-002 | Path hygiene | absolute or OS-specific paths in scripts |
| R-REPRO-003 | Single entry point | a `run.R` / `main.R` style script exists |
| R-REPRO-004 | Hidden setup assumptions | `.Rprofile` / `.Renviron`, `Sys.setenv`, preloaded workspaces |
| R-REPRO-005 | Proprietary packages declared | undeclared or unknown packages referenced in code |
| R-REPRO-006 | Clean run evidence | a [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) capture or run log |
| R-REPRO-007 | Script complexity | brace nesting depth against a limit |

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
| [`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md) | Run all seven indicators over a folder |
| [`assess_env_lockfile()`](https://r4sub.github.io/r4subrepro/reference/assess_env_lockfile.md) | Environment lockfile present (R-REPRO-001) |
| [`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md) | Absolute / OS-specific paths (R-REPRO-002) |
| [`assess_entry_point()`](https://r4sub.github.io/r4subrepro/reference/assess_entry_point.md) | Single entry point (R-REPRO-003) |
| [`assess_hidden_setup()`](https://r4sub.github.io/r4subrepro/reference/assess_hidden_setup.md) | Hidden setup assumptions (R-REPRO-004) |
| [`assess_proprietary_pkgs()`](https://r4sub.github.io/r4subrepro/reference/assess_proprietary_pkgs.md) | Undeclared packages (R-REPRO-005) |
| [`assess_clean_run_evidence()`](https://r4sub.github.io/r4subrepro/reference/assess_clean_run_evidence.md) | Clean run evidence (R-REPRO-006) |
| [`assess_script_depth()`](https://r4sub.github.io/r4subrepro/reference/assess_script_depth.md) | Script complexity (R-REPRO-007) |
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
