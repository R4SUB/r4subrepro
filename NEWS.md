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
