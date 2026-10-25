# Default Reproducibility Assessment Configuration

Returns the default configuration list used by
[`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md)
and the individual assessment functions.

## Usage

``` r
repro_config_default()
```

## Value

A list of class `"repro_config"` with the following elements:

- max_script_depth:

  Maximum recommended brace nesting depth in a script before it is
  flagged (integer).

- entry_point_names:

  Character vector of file names that count as a single obvious entry
  point.

- lockfile_names:

  Character vector of file names or patterns that count as a captured
  package environment.

- run_evidence_patterns:

  Character vector of regular expressions that match a clean run log or
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) capture.

- expected_output_dir:

  Name of the subfolder that holds the submitted outputs an execution
  check should reproduce (character).

- run_timeout:

  Maximum seconds to allow a reproduction run (integer).

- cosmetic_output_ext:

  Character vector of output file extensions (such as `rtf` and `pdf`)
  whose embedded timestamps are stripped before comparison, so an output
  that differs only in generation time counts as analytically reproduced
  rather than a mismatch.

- compiled_source_ext:

  Character vector of file extensions that mark compiled native source a
  reviewer must build (C, C++, Fortran).

- compiled_call_patterns:

  Character vector of regular expressions for inline compilation calls
  (`sourceCpp`, `cppFunction`, `R CMD SHLIB`).

- compiled_build_files:

  Character vector of build-script file names (`Makevars`,
  `Makevars.win`) that indicate native compilation.

- toolchain_doc_pattern:

  Regular expression that matches documentation of the compiler
  toolchain (Rtools) reviewers need to build from source.

- verification_patterns:

  Character vector of regular expressions that match an
  independent-verification artifact, such as an SAS vs R comparison or a
  QC report.

- windows_risk_patterns:

  Named character vector of regular expressions for non-portable
  constructs that can break on a Windows reviewer machine (shell-outs,
  forking, POSIX paths).

- adrg_names:

  Character vector of patterns matching an Analysis Data Reviewer's
  Guide document file name.

- adrg_required_sections:

  Named character vector of regular expressions for the sections an ADRG
  should contain.

- weights:

  Named list of relative indicator weights summing to 1: `env_lockfile`,
  `path_hygiene`, `entry_point`, `hidden_setup`, `proprietary_pkgs`,
  `clean_run`, `script_depth`, `output_reproduction`,
  `dual_verification`, `adrg`, `windows_reviewability`,
  `compiled_toolchain`.

## Examples

``` r
cfg <- repro_config_default()
cfg$max_script_depth
#> [1] 6
cfg$weights$path_hygiene
#> [1] 0.12
```
