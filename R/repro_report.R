# Internal: assemble the per-indicator report rows by joining the scored summary
# (indicator_id, indicator_name, result, severity, score) with the first
# evidence row for each indicator (message, metric_value, metric_unit, location).
repro_report_rows <- function(res, evidence) {
  summ <- res$summary
  detail <- function(id, col) {
    sub <- evidence[evidence$indicator_id == id, ]
    if (nrow(sub) == 0L) return(NA)
    sub[[col]][1L]
  }
  summ$message      <- vapply(summ$indicator_id, detail, character(1),
                              col = "message")
  summ$metric_value <- vapply(summ$indicator_id,
                              function(id) as.numeric(detail(id, "metric_value")),
                              numeric(1))
  summ$metric_unit  <- vapply(summ$indicator_id, detail, character(1),
                              col = "metric_unit")
  summ$location     <- vapply(summ$indicator_id, detail, character(1),
                              col = "location")
  summ
}

# The standing note that keeps the report framed as decision-support.
repro_report_disclaimer <- function() {
  paste0("Decision-support only: this report summarises automated indicator ",
         "evidence to help prepare a submission. It is not an official ",
         "submission artifact and does not represent regulatory review or approval.")
}

# Render the report as a JSON string via jsonlite.
repro_report_json <- function(res, rows) {
  pct <- if (is.na(res$overall_score)) NA_real_ else
    round(res$overall_score * 100, 1)

  indicators <- lapply(seq_len(nrow(rows)), function(i) {
    r <- rows[i, ]
    list(
      indicator_id   = r$indicator_id,
      indicator_name = r$indicator_name,
      result         = r$result,
      severity       = r$severity,
      score          = if (is.na(r$score)) NULL else r$score,
      metric_value   = if (is.na(r$metric_value)) NULL else r$metric_value,
      metric_unit    = if (is.na(r$metric_unit)) NULL else r$metric_unit,
      message        = r$message,
      location       = if (is.na(r$location)) NULL else r$location
    )
  })

  doc <- list(
    report_type    = "r4subrepro reproducibility report",
    schema_version = "1",
    generated      = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    disclaimer     = repro_report_disclaimer(),
    source         = list(name = "r4subrepro", version = repro_source_version()),
    study_id       = res$study_id,
    overall_score  = if (is.na(res$overall_score)) NULL else res$overall_score,
    overall_score_pct = if (is.na(pct)) NULL else pct,
    counts         = list(
      indicators = res$n_indicators,
      pass       = res$n_pass,
      warn       = res$n_warn,
      fail       = res$n_fail
    ),
    indicators     = indicators
  )

  jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null",
                   na = "null")
}

# Render the report as a Markdown string.
repro_report_markdown <- function(res, rows) {
  score_line <- if (is.na(res$overall_score)) {
    "Overall reproducibility score: not available"
  } else {
    paste0("Overall reproducibility score: ",
           round(res$overall_score * 100, 1), "% (",
           res$n_pass, " pass, ", res$n_warn, " warn, ", res$n_fail, " fail)")
  }

  tbl <- data.frame(
    Indicator = rows$indicator_id,
    Name      = rows$indicator_name,
    Result    = rows$result,
    Severity  = rows$severity,
    Score     = ifelse(is.na(rows$score), "NA", as.character(rows$score)),
    Detail    = rows$message,
    stringsAsFactors = FALSE
  )

  lines <- c(
    "# R4SUB Reproducibility Report",
    "",
    paste0("- Study: ", res$study_id),
    paste0("- Indicators assessed: ", res$n_indicators),
    paste0("- Generated: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    paste0("- Source: r4subrepro ", repro_source_version()),
    "",
    paste0("> ", repro_report_disclaimer()),
    "",
    "## Overall",
    "",
    score_line,
    "",
    "## Indicators",
    "",
    md_table(tbl),
    ""
  )
  paste(lines, collapse = "\n")
}

#' Export a Machine-Readable Reproducibility Report
#'
#' Renders the evidence from [assess_reproducibility()] and the scores from
#' [reproducibility_summary()] into a portable report, as either a JSON string
#' (via 'jsonlite') or a Markdown summary string. This is a reporting layer only:
#' it reads the existing evidence and scores without changing any indicator
#' logic, thresholds, weights, or results. The report is **decision-support** to
#' help prepare a submission; it is not an official submission artifact and does
#' not represent regulatory review.
#'
#' The JSON document carries a `report_type`, a `schema_version`, the generation
#' time, the disclaimer, the source package and version, the study id, the
#' weighted overall score (as a fraction and a percentage), the pass/warn/fail
#' counts, and an `indicators` array with one object per indicator
#' (`indicator_id`, `indicator_name`, `result`, `severity`, `score`,
#' `metric_value`, `metric_unit`, `message`, `location`). The Markdown rendering
#' presents the same evidence as a header block, the overall score, and a table
#' of indicators.
#'
#' @param x Either a validated evidence table from [assess_reproducibility()] (or
#'   an individual assessment function), or a `repro_result` from
#'   [reproducibility_summary()]. When an evidence table is passed, it is scored
#'   with [reproducibility_summary()] using `config`.
#' @param format Output format: `"json"` (default) or `"markdown"`.
#' @param file Optional path to write the rendered report to. When supplied, the
#'   report is written there and the path is returned invisibly; otherwise the
#'   rendered string is returned.
#' @param config A configuration from [repro_config_default()], used only when
#'   `x` is an evidence table that must be scored. When `NULL` the default
#'   configuration is used.
#'
#' @return A single character string with the rendered report, or, when `file`
#'   is supplied, the path to the written file (invisibly).
#'
#' @seealso [assess_reproducibility()], [reproducibility_summary()]
#'
#' @examples
#' d <- file.path(tempdir(), "sub_report")
#' dir.create(d, showWarnings = FALSE)
#' writeLines(c('{ "R": { "Version": "4.4.1" },',
#'              '  "Packages": { "dplyr": { "Package": "dplyr", "Version": "1.1.4" } } }'),
#'            file.path(d, "renv.lock"))
#' writeLines("source('a.R')", file.path(d, "run.R"))
#' writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
#' ev <- suppressMessages(assess_reproducibility(d))
#'
#' # JSON string (machine-readable)
#' cat(repro_report(ev, format = "json"))
#'
#' # Markdown summary string
#' cat(repro_report(ev, format = "markdown"))
#'
#' # From a scored result, written to a file
#' res <- reproducibility_summary(ev)
#' f <- repro_report(res, format = "json", file = file.path(d, "repro.json"))
#' file.exists(f)
#'
#' @export
repro_report <- function(x, format = c("json", "markdown"), file = NULL,
                         config = NULL) {
  format <- match.arg(format)

  if (inherits(x, "repro_result")) {
    res      <- x
    evidence <- x$evidence
  } else if (is.data.frame(x) && all(c("indicator_id", "result") %in% names(x))) {
    config   <- resolve_config(config)
    res      <- reproducibility_summary(x, config = config)
    evidence <- x
  } else {
    cli::cli_abort(paste0(
      "{.arg x} must be an evidence table from {.fn assess_reproducibility} ",
      "or a {.cls repro_result} from {.fn reproducibility_summary}."
    ))
  }

  rows <- repro_report_rows(res, evidence)

  out <- switch(format,
                json     = repro_report_json(res, rows),
                markdown = repro_report_markdown(res, rows))
  out <- as.character(out)

  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file)) {
      cli::cli_abort("{.arg file} must be a single file path.")
    }
    writeLines(out, file)
    cli::cli_alert_success("Wrote reproducibility report to {.path {file}}")
    return(invisible(file))
  }
  out
}
