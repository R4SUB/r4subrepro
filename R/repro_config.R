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
#'     \item{verification_patterns}{Character vector of regular expressions that
#'       match an independent-verification artifact, such as an SAS vs R
#'       comparison or a QC report.}
#'     \item{adrg_names}{Character vector of patterns matching an Analysis Data
#'       Reviewer's Guide document file name.}
#'     \item{adrg_required_sections}{Named character vector of regular
#'       expressions for the sections an ADRG should contain.}
#'     \item{weights}{Named list of relative indicator weights summing to 1:
#'       `env_lockfile`, `path_hygiene`, `entry_point`, `hidden_setup`,
#'       `proprietary_pkgs`, `clean_run`, `script_depth`,
#'       `output_reproduction`, `dual_verification`, `adrg`.}
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
      verification_patterns = c("qc", "verif", "validation", "concordance",
                                "compare", "comparison", "double.?program",
                                "sas.?r", "r.?sas"),
      adrg_names = c("adrg", "analysis.?data.?reviewer"),
      adrg_required_sections = c(
        inputs      = "input",
        run_order   = "run.?order",
        outputs     = "output|table|figure|listing",
        packages    = "package|r version|session",
        environment = "environment|renv|setup|install"
      ),
      weights = list(
        env_lockfile        = 0.15,
        path_hygiene        = 0.15,
        entry_point         = 0.10,
        hidden_setup        = 0.08,
        proprietary_pkgs    = 0.08,
        clean_run           = 0.04,
        script_depth        = 0.07,
        output_reproduction = 0.14,
        dual_verification   = 0.10,
        adrg                = 0.09
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
