# Internal: map indicator ids to their configured weight names.
repro_indicator_weight <- function(ids, config) {
  map <- c("R-REPRO-001" = "env_lockfile",
           "R-REPRO-002" = "path_hygiene",
           "R-REPRO-003" = "entry_point",
           "R-REPRO-004" = "hidden_setup",
           "R-REPRO-005" = "proprietary_pkgs",
           "R-REPRO-006" = "clean_run",
           "R-REPRO-007" = "script_depth",
           "R-REPRO-008" = "output_reproduction",
           "R-REPRO-009" = "dual_verification",
           "R-REPRO-010" = "adrg",
           "R-REPRO-011" = "windows_reviewability",
           "R-REPRO-012" = "compiled_toolchain")
  vapply(ids, function(id) {
    key <- unname(map[id])
    if (is.na(key)) return(0)
    w <- config$weights[[key]]
    if (is.null(w)) 0 else as.numeric(w)
  }, numeric(1))
}

#' Summarise Reproducibility Evidence
#'
#' Produces a structured summary of reproducibility evidence, suitable for
#' printing or for passing to downstream reporting.
#'
#' @param evidence A validated evidence table from [assess_reproducibility()] or
#'   the individual assessment functions.
#' @param config A configuration from [repro_config_default()], used for the
#'   per-indicator weights in the overall score. When `NULL` the default
#'   configuration is used.
#'
#' @return A `repro_result` list (class `"repro_result"`) with:
#'   \describe{
#'     \item{study_id}{The study identifier from the evidence.}
#'     \item{n_indicators}{Number of distinct indicators assessed.}
#'     \item{overall_score}{The weighted mean of the per-indicator scores (pass
#'       is 1, warn is 0.5, fail is 0), using the configuration weights.}
#'     \item{summary}{A data.frame with one row per indicator: `indicator_id`,
#'       `indicator_name`, `result`, `severity`, and `score`.}
#'     \item{n_pass, n_fail, n_warn}{Counts across indicators.}
#'     \item{evidence}{The original evidence table.}
#'   }
#'
#' @examples
#' d <- file.path(tempdir(), "sub_sum")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("{}", file.path(d, "renv.lock"))
#' writeLines("source('a.R')", file.path(d, "run.R"))
#' writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
#' ev  <- suppressMessages(assess_reproducibility(d))
#' res <- reproducibility_summary(ev)
#' print(res)
#'
#' @export
reproducibility_summary <- function(evidence, config = NULL) {
  config <- resolve_config(config)

  result_score <- c(pass = 1, warn = 0.5, fail = 0, na = NA_real_)

  ids <- unique(evidence$indicator_id)
  rows <- lapply(ids, function(id) {
    sub <- evidence[evidence$indicator_id == id, ]
    r   <- sub$result[1L]
    data.frame(
      indicator_id   = id,
      indicator_name = sub$indicator_name[1L],
      result         = r,
      severity       = sub$severity[1L],
      score          = unname(result_score[r]),
      stringsAsFactors = FALSE
    )
  })
  summary_tbl <- do.call(rbind, rows)

  w <- repro_indicator_weight(summary_tbl$indicator_id, config)
  usable <- !is.na(summary_tbl$score) & w > 0
  overall <- if (any(usable)) {
    sum(summary_tbl$score[usable] * w[usable]) / sum(w[usable])
  } else {
    NA_real_
  }

  structure(
    list(
      study_id      = unique(evidence$study_id)[1L],
      n_indicators  = length(ids),
      overall_score = overall,
      summary       = summary_tbl,
      n_pass        = sum(summary_tbl$result == "pass"),
      n_fail        = sum(summary_tbl$result == "fail"),
      n_warn        = sum(summary_tbl$result == "warn"),
      evidence      = evidence
    ),
    class = "repro_result"
  )
}

#' Print a Reproducibility Result Summary
#'
#' @param x A `repro_result` object from [reproducibility_summary()].
#' @param ... Ignored.
#'
#' @return Invisibly returns `x`. Called for the side effect of printing the
#'   per-indicator results and the weighted overall score.
#'
#' @export
print.repro_result <- function(x, ...) {
  cli::cli_h2("R4SUB Reproducibility Assessment")
  cli::cli_text("Study: {.val {x$study_id}}  |  Indicators: {.val {x$n_indicators}}")
  cli::cli_text("")

  for (i in seq_len(nrow(x$summary))) {
    row <- x$summary[i, ]
    icon <- switch(row$result,
                   pass = cli::col_green("u2713"),
                   warn = cli::col_yellow("!"),
                   fail = cli::col_red("u2717"),
                   " ")
    cli::cli_text("{icon} {row$indicator_id} {row$indicator_name}: {row$result}")
  }

  cli::cli_text("")
  if (is.na(x$overall_score)) {
    cli::cli_alert_info("Overall reproducibility score: not available")
  } else {
    cli::cli_alert_info(
      "Overall reproducibility score: {round(x$overall_score * 100, 1)}% ({x$n_pass} pass, {x$n_warn} warn, {x$n_fail} fail)"
    )
  }
  invisible(x)
}
