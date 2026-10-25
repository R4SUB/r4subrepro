# r4subrepro 0.4.1

- Add a pkgdown documentation site and prepare metadata for CRAN submission.

# r4subrepro 0.4.0

- Adds `assess_compiled_toolchain()` (`R-REPRO-012`), which detects whether the
  submission compiles native code (C/C++/Fortran source, a `src/` folder, a
  `Makevars` script, or an inline `sourceCpp()`/`cppFunction()`/`R CMD SHLIB`
  call) and, when it does, checks that the Rtools toolchain reviewers need to
  build it on Windows is documented. CRAN packages install as prebuilt Windows
  binaries, so a submission without local compilation passes.
- `assess_proprietary_pkgs()` (`R-REPRO-005`) now tiers referenced packages by
  how reproducible their source is instead of a binary known/unknown split:
  CRAN or known packages pass, non-CRAN packages declared from a GitHub/Git/URL/
  local source warn (bundle the sources), and undeclared proprietary packages
  warn at medium severity. Renamed to "Package Reproducibility Tiering".
- `assess_output_reproduction()` (`R-REPRO-008`) now separates analytical
  content from cosmetic bytes: data outputs must match exactly, but `rtf` and
  `pdf` outputs are compared after their embedded generation timestamps are
  stripped, so an output that differs only in generation time counts as
  reproduced rather than a false mismatch.
- Reweights the indicator set to include the compiled-code toolchain check.

# r4subrepro 0.3.0

- Adds `assess_windows_reviewability()` (`R-REPRO-011`), a static check for
  non-portable constructs that can break on a Windows reviewer machine
  (shell-outs, forking, POSIX paths). Windows is the FDA reviewer environment.
- `assess_output_reproduction()` (`R-REPRO-008`) now records the operating
  system the re-run happened on and warns when it is not Windows, since the
  outputs must reproduce on the reviewer's Windows machine.
- Reweights the indicator set to include Windows reviewability.
- `assess_env_lockfile()` (`R-REPRO-001`) now grades lockfile quality instead of
  mere presence: a version-pinned `renv.lock` or `packrat` lockfile passes, an
  `renv.lock` stub with no versions or a `DESCRIPTION`-only dependency list
  warns, and nothing fails. A top-level dependency list is not a version-pinned
  lockfile.
- `adrg_skeleton()` now generates an Executive Summary (overview of the analysis
  programs and their purpose), a Troubleshooting section (path, package
  install, Rtools/compiled, R-version, and proprietary-package failure modes),
  and an analysis-type (primary/secondary) column in the program table.
  `assess_adrg()` requires the executive summary and troubleshooting sections.

# r4subrepro 0.2.0

- Adds `assess_output_reproduction()` (`R-REPRO-008`), which re-runs a
  submission's entry point in a fresh, sandboxed R session and checks that the
  outputs match the submitted outputs byte for byte. Execution is opt-in and
  never touches the submission folder; without `run = TRUE` the indicator
  returns `na`.
- `assess_reproducibility()` gains `include_execution` to append the
  output-reproduction check.
- Adds `assess_dual_verification()` (`R-REPRO-009`), which checks that the
  submission declares independent verification of its results, such as an SAS
  versus R comparison or a QC report, and `assess_sas_r_concordance()`, which
  compares two result tables cell by cell within a tolerance. The static check
  is included in `assess_reproducibility()`.
- Adds `assess_adrg()` (`R-REPRO-010`), which checks that the submission
  includes an Analysis Data Reviewer's Guide covering the required inputs, run
  order, expected outputs, R packages, and environment setup, and
  `adrg_skeleton()`, which generates a draft in the standard PHUSE / R
  Consortium ADRG structure (sections 1 to 8 plus an R execution appendix),
  auto-filling the analysis datasets, the analysis output programs and a
  program-to-output traceability table, the proprietary and open-source R
  package split with versions, and the execution steps, and adding a
  Reproducibility and Verification section the base template omits. The check
  is included in `assess_reproducibility()`.
- Reweights the indicator set to accommodate the new reproducibility,
  verification, and reviewer-guide indicators.

# r4subrepro 0.1.0

- Initial release.
- Adds seven static reproducibility and reviewability indicators over a
  submission's analysis code folder, following the guidance on making R
  submissions reviewable for regulators: environment lockfile present
  (`R-REPRO-001`), path hygiene (`R-REPRO-002`), single entry point
  (`R-REPRO-003`), hidden setup assumptions (`R-REPRO-004`), proprietary package
  declaration (`R-REPRO-005`), clean run evidence (`R-REPRO-006`), and script
  complexity (`R-REPRO-007`).
- `assess_reproducibility()` runs all seven and returns a combined R4SUB
  evidence table with `indicator_domain = "usability"`, so the results flow into
  the Submission Confidence Index.
- `reproducibility_summary()` gives a weighted overall score with a readable
  print method.
