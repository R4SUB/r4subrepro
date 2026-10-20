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
