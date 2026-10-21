#' Default Reproducibility Assessment Configuration
#'
#' Returns the default configuration list used by [assess_reproducibility()] and
#' the individual assessment functions.
#'
#' @return A list of class `"repro_config"` with the following elements:
#'   \describe{
#'     \item{max_script_depth}{Maximum recommended brace nesting depth in a
#'       script before it is flagged (integer).}
#'     \item{entry_point_names}{Character vector of file names that count as a
#'       single obvious entry point.}
#'     \item{lockfile_names}{Character vector of file names or patterns that
#'       count as a captured package environment.}
#'     \item{run_evidence_patterns}{Character vector of regular expressions that
#'       match a clean run log or `sessionInfo()` capture.}
#'     \item{expected_output_dir}{Name of the subfolder that holds the submitted
#'       outputs an execution check should reproduce (character).}
#'     \item{run_timeout}{Maximum seconds to allow a reproduction run (integer).}
#'     \item{cosmetic_output_ext}{Character vector of output file extensions
#'       (such as `rtf` and `pdf`) whose embedded timestamps are stripped before
#'       comparison, so an output that differs only in generation time counts as
#'       analytically reproduced rather than a mismatch.}
#'     \item{compiled_source_ext}{Character vector of file extensions that mark
#'       compiled native source a reviewer must build (C, C++, Fortran).}
#'     \item{compiled_call_patterns}{Character vector of regular expressions for
#'       inline compilation calls (`sourceCpp`, `cppFunction`, `R CMD SHLIB`).}
#'     \item{compiled_build_files}{Character vector of build-script file names
#'       (`Makevars`, `Makevars.win`) that indicate native compilation.}
#'     \item{toolchain_doc_pattern}{Regular expression that matches documentation
#'       of the compiler toolchain (Rtools) reviewers need to build from source.}
#'     \item{verification_patterns}{Character vector of regular expressions that
#'       match an independent-verification artifact, such as an SAS vs R
#'       comparison or a QC report.}
#'     \item{windows_risk_patterns}{Named character vector of regular expressions
#'       for non-portable constructs that can break on a Windows reviewer
#'       machine (shell-outs, forking, POSIX paths).}
#'     \item{adrg_names}{Character vector of patterns matching an Analysis Data
#'       Reviewer's Guide document file name.}
#'     \item{adrg_required_sections}{Named character vector of regular
#'       expressions for the sections an ADRG should contain.}
#'     \item{weights}{Named list of relative indicator weights summing to 1:
#'       `env_lockfile`, `path_hygiene`, `entry_point`, `hidden_setup`,
#'       `proprietary_pkgs`, `clean_run`, `script_depth`,
#'       `output_reproduction`, `dual_verification`, `adrg`,
#'       `windows_reviewability`, `compiled_toolchain`.}
#'   }
#'
#' @examples
#' cfg <- repro_config_default()
#' cfg$max_script_depth
#' cfg$weights$path_hygiene
#'
#' @export
repro_config_default <- function() {
  structure(
    list(
      max_script_depth  = 6L,
      entry_point_names = c("run.R", "main.R", "00_run.R", "runall.R",
                            "run_all.R", "master.R"),
      lockfile_names    = c("renv.lock", "packrat.lock", "packrat",
                            "DESCRIPTION"),
      run_evidence_patterns = c("sessioninfo.*\\.txt$", "\\.log$",
                                "reproduce.*\\.(txt|md|log)$",
                                "runlog.*\\.(txt|log)$"),
      expected_output_dir = "outputs",
      run_timeout         = 600L,
      cosmetic_output_ext = c("rtf", "pdf"),
      compiled_source_ext = c("c", "cc", "cpp", "cxx", "h", "hpp",
                              "f", "f90", "f95", "f77"),
      compiled_call_patterns = c("\\bsourceCpp\\s*\\(", "\\bcppFunction\\s*\\(",
                                 "\\bcxxfunction\\s*\\(", "R CMD SHLIB"),
      compiled_build_files = c("makevars", "makevars.win"),
      toolchain_doc_pattern = "rtools",
      verification_patterns = c("qc", "verif", "validation", "concordance",
                                "compare", "comparison", "double.?program",
                                "sas.?r", "r.?sas"),
      windows_risk_patterns = c(
        system_call = "\\bsystem2?\\s*\\(",
        fork        = "mclapply|mcmapply|mcparallel|makeForkCluster|mccollect",
        dev_null    = "/dev/null",
        posix_tmp   = "[\"']/tmp/"
      ),
      adrg_names = c("adrg", "analysis.?data.?reviewer"),
      adrg_required_sections = c(
        introduction   = "introduction|purpose",
        data_standards = "standard|dictionary|define",
        datasets       = "analysis dataset|dataset description",
        conformance    = "conformance|pinnacle|validation check",
        programs       = "program",
        packages       = "package",
        directory      = "directory structure|ectd|module",
        execution      = "execute|installation|appendix|setup",
        verification   = "verification|reproduc|concordance",
        exec_summary   = "executive summary|overview of (the )?program",
        troubleshooting = "troubleshoot"
      ),
      weights = list(
        env_lockfile          = 0.13,
        path_hygiene          = 0.12,
        entry_point           = 0.08,
        hidden_setup          = 0.07,
        proprietary_pkgs      = 0.07,
        clean_run             = 0.04,
        script_depth          = 0.05,
        output_reproduction   = 0.12,
        dual_verification     = 0.09,
        adrg                  = 0.08,
        windows_reviewability = 0.09,
        compiled_toolchain    = 0.06
      )
    ),
    class = "repro_config"
  )
}

# Internal: validate a configuration argument, filling the default when NULL.
resolve_config <- function(config) {
  if (is.null(config)) return(repro_config_default())
  if (!inherits(config, "repro_config")) {
    cli::cli_abort(
      "{.arg config} must be a {.cls repro_config} from {.fn repro_config_default}."
    )
  }
  config
}
