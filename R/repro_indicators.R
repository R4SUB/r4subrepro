#' Assess Environment Lockfile Presence
#'
#' Checks whether the submission folder captures its package environment, for
#' example through an `renv.lock`, a `packrat` lockfile, or a versioned
#' `DESCRIPTION`. A reviewer cannot reinstall the software stack without one, so
#' its absence is a high severity finding. Returns R4SUB evidence with
#' `indicator_id = "R-REPRO-001"`.
#'
#' @param path Path to the submission's analysis code folder.
#' @param ctx A run context from [r4subcore::r4sub_run_context()]. When `NULL` a
#'   default context is created from the folder name.
#' @param config A configuration from [repro_config_default()]. When `NULL` the
#'   default configuration is used.
#'
#' @return A validated evidence table (see [r4subcore::as_evidence()]).
#'
#' @examples
#' d <- file.path(tempdir(), "sub001")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("{}", file.path(d, "renv.lock"))
#' ev <- suppressMessages(assess_env_lockfile(d))
#' ev$result
#'
#' @export
assess_env_lockfile <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  found <- character(0)
  for (nm in config$lockfile_names) {
    hit <- list.files(path, pattern = paste0("^", nm, "$"), recursive = TRUE,
                      all.files = TRUE, full.names = FALSE)
    if (length(hit)) found <- c(found, hit)
  }
  # A DESCRIPTION only counts if it pins at least one version.
  desc <- file.path(path, "DESCRIPTION")
  if ("DESCRIPTION" %in% basename(found) && file.exists(desc)) {
    if (!any(grepl("\\(\\s*[<>=]", read_lines_safe(desc)))) {
      found <- found[basename(found) != "DESCRIPTION"]
    }
  }

  if (length(found) > 0L) {
    row <- repro_row("R-REPRO-001", "Environment Lockfile Present", asset,
                     "pass", "info",
                     paste0("Captured environment found: ",
                            paste(unique(basename(found)), collapse = ", ")),
                     metric_value = 1, metric_unit = "present",
                     location = paste(unique(found), collapse = "; "))
  } else {
    row <- repro_row("R-REPRO-001", "Environment Lockfile Present", asset,
                     "fail", "high",
                     "No renv.lock, packrat lockfile, or versioned DESCRIPTION found",
                     metric_value = 0, metric_unit = "present", location = path)
  }
  repro_evidence(row, ctx)
}

#' Assess Path Hygiene
#'
#' Scans the R and R Markdown scripts for absolute or operating system specific
#' file paths (Windows drive letters, UNC shares, home directory references, and
#' absolute POSIX paths). These break in a reviewer's environment, so any hit is
#' a high severity finding. Returns evidence with `indicator_id = "R-REPRO-002"`.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub002")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
#' ev <- suppressMessages(assess_path_hygiene(d))
#' ev$result
#'
#' @export
assess_path_hygiene <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  files <- list_r_files(path)
  patterns <- c(
    win_drive = "[A-Za-z]:[\\\\/]",
    unc       = "\\\\\\\\[A-Za-z0-9_.$]",
    home      = "~/",
    posix_abs = "[\"'](/[A-Za-z_][^\"':]*)[\"']"
  )

  offenders <- character(0)
  for (f in files) {
    lines <- read_lines_safe(f)
    if (length(lines) == 0L) next
    for (i in seq_along(lines)) {
      ln <- lines[i]
      if (grepl("://", ln, fixed = TRUE)) ln <- gsub("[a-z]+://[^\"'[:space:]]*", "", ln)
      hit <- FALSE
      for (p in patterns) if (grepl(p, ln, perl = TRUE)) { hit <- TRUE; break }
      if (hit) {
        offenders <- c(offenders,
                       paste0(basename(f), ":", i))
      }
    }
  }

  if (length(offenders) == 0L) {
    row <- repro_row("R-REPRO-002", "Path Hygiene", asset, "pass", "info",
                     "No absolute or OS-specific paths found in scripts",
                     metric_value = 0, metric_unit = "hits", location = path)
  } else {
    shown <- paste(utils::head(offenders, 5L), collapse = ", ")
    more  <- if (length(offenders) > 5L) paste0(" (+", length(offenders) - 5L, " more)") else ""
    row <- repro_row("R-REPRO-002", "Path Hygiene", asset, "fail", "high",
                     paste0(length(offenders), " absolute or OS-specific path(s): ",
                            shown, more),
                     metric_value = length(offenders), metric_unit = "hits",
                     location = shown)
  }
  repro_evidence(row, ctx)
}

#' Assess Single Entry Point
#'
#' Checks that the folder provides one obvious script a reviewer can run to
#' reproduce the analysis (for example `run.R` or `main.R`). Returns evidence
#' with `indicator_id = "R-REPRO-003"`.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub003")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("source('a.R')", file.path(d, "run.R"))
#' ev <- suppressMessages(assess_entry_point(d))
#' ev$result
#'
#' @export
assess_entry_point <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  present <- list.files(path, recursive = TRUE)
  hits <- present[tolower(basename(present)) %in% tolower(config$entry_point_names)]

  if (length(hits) > 0L) {
    row <- repro_row("R-REPRO-003", "Single Entry Point", asset, "pass", "info",
                     paste0("Entry point found: ", paste(basename(hits), collapse = ", ")),
                     metric_value = 1, metric_unit = "present",
                     location = paste(hits, collapse = "; "))
  } else {
    row <- repro_row("R-REPRO-003", "Single Entry Point", asset, "fail", "medium",
                     paste0("No entry point script found (expected one of: ",
                            paste(config$entry_point_names, collapse = ", "), ")"),
                     metric_value = 0, metric_unit = "present", location = path)
  }
  repro_evidence(row, ctx)
}

#' Assess Hidden Setup Assumptions
#'
#' Flags dependencies that are invisible to a reviewer: `.Rprofile` or
#' `.Renviron` files in the folder, environment variables set in code, or
#' preloaded workspaces (`load()` of an `.RData` file). Setting the environment
#' or loading a saved workspace is a fail; only reading the environment is a
#' warn. Returns evidence with `indicator_id = "R-REPRO-004"`.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub004")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("library(dplyr)", file.path(d, "a.R"))
#' ev <- suppressMessages(assess_hidden_setup(d))
#' ev$result
#'
#' @export
assess_hidden_setup <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  dotfiles <- list.files(path, pattern = "^\\.(Rprofile|Renviron)$",
                         all.files = TRUE, recursive = TRUE)
  files <- list_r_files(path)
  text  <- unlist(lapply(files, read_lines_safe))
  text  <- paste(text, collapse = "\n")

  hard <- grepl("Sys\\.setenv", text) ||
    grepl("load\\(\\s*[\"'][^\"']*\\.RData", text, perl = TRUE) ||
    length(dotfiles) > 0L
  soft <- grepl("Sys\\.getenv", text)

  if (hard) {
    detail <- character(0)
    if (length(dotfiles) > 0L) detail <- c(detail, paste(dotfiles, collapse = ", "))
    if (grepl("Sys\\.setenv", text)) detail <- c(detail, "Sys.setenv()")
    if (grepl("load\\(\\s*[\"'][^\"']*\\.RData", text, perl = TRUE)) detail <- c(detail, "load(.RData)")
    row <- repro_row("R-REPRO-004", "Hidden Setup Assumptions", asset, "fail",
                     "medium",
                     paste0("Hidden setup detected: ", paste(detail, collapse = "; ")),
                     metric_value = 0, metric_unit = "score", location = path)
  } else if (soft) {
    row <- repro_row("R-REPRO-004", "Hidden Setup Assumptions", asset, "warn",
                     "low",
                     "Code reads environment variables (Sys.getenv); document their expected values",
                     metric_value = 0.5, metric_unit = "score", location = path)
  } else {
    row <- repro_row("R-REPRO-004", "Hidden Setup Assumptions", asset, "pass",
                     "info", "No hidden setup assumptions detected",
                     metric_value = 1, metric_unit = "score", location = path)
  }
  repro_evidence(row, ctx)
}

#' Assess Proprietary Package Declaration
#'
#' Extracts the packages referenced by the scripts and flags any that are not in
#' the bundled allowlist of base, recommended, and common CRAN and pharma
#' packages, unless the folder declares them in an `renv.lock` or versioned
#' `DESCRIPTION`. Undeclared internal packages break a review, so this is a warn.
#' The check uses a bundled allowlist rather than a live CRAN query, so it is
#' deterministic and works offline. Returns evidence with
#' `indicator_id = "R-REPRO-005"`.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub005")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("library(dplyr)", file.path(d, "a.R"))
#' ev <- suppressMessages(assess_proprietary_pkgs(d))
#' ev$result
#'
#' @export
assess_proprietary_pkgs <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  files <- list_r_files(path)
  text  <- unlist(lapply(files, read_lines_safe))
  used  <- extract_packages(text)
  allow <- c(known_pkgs(), declared_packages(path))
  flagged <- setdiff(used, allow)

  if (length(flagged) == 0L) {
    row <- repro_row("R-REPRO-005", "Proprietary Packages Declared", asset,
                     "pass", "info",
                     "All referenced packages are known or declared",
                     metric_value = 0, metric_unit = "packages", location = path)
  } else {
    row <- repro_row("R-REPRO-005", "Proprietary Packages Declared", asset,
                     "warn", "medium",
                     paste0(length(flagged),
                            " undeclared or unknown package(s): ",
                            paste(flagged, collapse = ", ")),
                     metric_value = length(flagged), metric_unit = "packages",
                     location = paste(flagged, collapse = ", "))
  }
  repro_evidence(row, ctx)
}

#' Assess Clean Run Evidence
#'
#' Checks that the folder ships proof the analysis was run end to end in a clean
#' session, such as a `sessionInfo()` capture or a run log. Its absence is a low
#' severity warn. Returns evidence with `indicator_id = "R-REPRO-006"`.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub006")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("R version", file.path(d, "sessionInfo.txt"))
#' ev <- suppressMessages(assess_clean_run_evidence(d))
#' ev$result
#'
#' @export
assess_clean_run_evidence <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  present <- list.files(path, recursive = TRUE)
  base_lc <- tolower(basename(present))
  hit <- character(0)
  for (pat in config$run_evidence_patterns) {
    hit <- c(hit, present[grepl(pat, base_lc, perl = TRUE)])
  }
  hit <- unique(hit)

  if (length(hit) > 0L) {
    row <- repro_row("R-REPRO-006", "Clean Run Evidence", asset, "pass", "info",
                     paste0("Run evidence found: ", paste(basename(hit), collapse = ", ")),
                     metric_value = 1, metric_unit = "present",
                     location = paste(hit, collapse = "; "))
  } else {
    row <- repro_row("R-REPRO-006", "Clean Run Evidence", asset, "warn", "low",
                     "No sessionInfo capture or run log found",
                     metric_value = 0, metric_unit = "present", location = path)
  }
  repro_evidence(row, ctx)
}

#' Assess Script Complexity
#'
#' Reports the deepest brace nesting across the scripts. Deeply nested code is
#' hard for a reviewer to follow, so exceeding `config$max_script_depth` is a low
#' severity warn. Returns evidence with `indicator_id = "R-REPRO-007"`.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub007")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("f <- function(x) x + 1", file.path(d, "a.R"))
#' ev <- suppressMessages(assess_script_depth(d))
#' ev$result
#'
#' @export
assess_script_depth <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  files <- list.files(path, pattern = "\\.(R|r)$", recursive = TRUE,
                      full.names = TRUE)
  depths <- vapply(files, function(f) max_brace_depth(read_lines_safe(f)),
                   integer(1))
  max_depth <- if (length(depths)) max(depths) else 0L
  deepest <- if (length(depths)) basename(files[which.max(depths)]) else NA_character_

  if (max_depth > config$max_script_depth) {
    row <- repro_row("R-REPRO-007", "Script Complexity", asset, "warn", "low",
                     paste0("Deepest nesting is ", max_depth, " (limit ",
                            config$max_script_depth, ") in ", deepest),
                     metric_value = max_depth, metric_unit = "depth",
                     location = deepest)
  } else {
    row <- repro_row("R-REPRO-007", "Script Complexity", asset, "pass", "info",
                     paste0("Deepest nesting is ", max_depth, " (limit ",
                            config$max_script_depth, ")"),
                     metric_value = max_depth, metric_unit = "depth",
                     location = if (is.na(deepest)) path else deepest)
  }
  repro_evidence(row, ctx)
}

#' Assess Output Reproduction
#'
#' Re-runs the submission's entry point in a fresh R session and checks that the
#' outputs it produces match the submitted outputs byte for byte. This is the
#' executable counterpart to [assess_clean_run_evidence()], which only checks
#' that a run log is present. Returns evidence with
#' `indicator_id = "R-REPRO-008"`.
#'
#' Execution is opt-in and sandboxed. The folder is copied to a temporary
#' location and the entry point runs in a separate R session (via 'callr') with
#' a timeout, so nothing in the submission folder is modified. The submitted
#' outputs under `expected` are hashed from the original folder and compared to
#' the files the re-run produces in the copy. When `run = FALSE`, or 'callr' is
#' not installed, no code runs and the indicator returns `na`, which keeps the
#' check safe offline and on CRAN.
#'
#' @inheritParams assess_env_lockfile
#' @param expected Name of the subfolder, relative to `path`, holding the
#'   submitted outputs to reproduce. Defaults to `config$expected_output_dir`.
#' @param entry Entry point script to run, relative to `path`. When `NULL` the
#'   first file matching `config$entry_point_names` is used.
#' @param run Whether to execute the entry point. When `NULL` (default),
#'   execution happens only in an interactive session with 'callr' installed, so
#'   examples, tests, and CRAN do not run submission code unless asked.
#' @param timeout Maximum seconds to allow the run. Defaults to
#'   `config$run_timeout`.
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub008")
#' dir.create(file.path(d, "outputs"), recursive = TRUE, showWarnings = FALSE)
#' writeLines("writeLines('1', 'outputs/res.txt')", file.path(d, "run.R"))
#' writeLines("1", file.path(d, "outputs", "res.txt"))
#' ev <- suppressMessages(assess_output_reproduction(d, run = FALSE))
#' ev$result
#' \donttest{
#' if (requireNamespace("callr", quietly = TRUE)) {
#'   ev2 <- suppressMessages(assess_output_reproduction(d, run = TRUE))
#'   ev2$result
#' }
#' }
#'
#' @export
assess_output_reproduction <- function(path, expected = NULL, entry = NULL,
                                       ctx = NULL, config = NULL,
                                       run = NULL, timeout = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)
  if (is.null(expected)) expected <- config$expected_output_dir
  if (is.null(timeout))  timeout  <- config$run_timeout

  have_callr <- requireNamespace("callr", quietly = TRUE)
  if (is.null(run)) run <- interactive() && have_callr
  if (isTRUE(run) && !have_callr) run <- FALSE

  if (!isTRUE(run)) {
    row <- repro_row("R-REPRO-008", "Output Reproduction", asset, "na", "info",
                     "Execution not attempted; output reproduction not verified (set run = TRUE with 'callr' installed)",
                     metric_value = NA_real_, metric_unit = "match_rate",
                     location = path)
    return(repro_evidence(row, ctx))
  }

  if (is.null(entry)) {
    present <- list.files(path, recursive = TRUE)
    hits <- present[tolower(basename(present)) %in% tolower(config$entry_point_names)]
    entry <- if (length(hits)) hits[1L] else NA_character_
  }
  if (is.na(entry) || !nzchar(entry)) {
    row <- repro_row("R-REPRO-008", "Output Reproduction", asset, "fail", "high",
                     "No entry point script found to execute",
                     metric_value = 0, metric_unit = "match_rate", location = path)
    return(repro_evidence(row, ctx))
  }

  expected_hashes <- hash_dir(file.path(path, expected))

  run_dir <- tempfile("r4subrepro_run_")
  dir.create(run_dir)
  on.exit(unlink(run_dir, recursive = TRUE, force = TRUE), add = TRUE)
  items <- list.files(path, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  file.copy(items, run_dir, recursive = TRUE)

  entry_abs <- file.path(run_dir, entry)
  err <- tryCatch({
    callr::rscript(entry_abs, wd = run_dir, show = FALSE, timeout = timeout,
                   fail_on_status = TRUE)
    NA_character_
  }, error = function(e) conditionMessage(e))

  if (!is.na(err)) {
    row <- repro_row("R-REPRO-008", "Output Reproduction", asset, "fail", "high",
                     paste0("Entry point '", entry, "' errored or timed out: ",
                            substr(err, 1L, 160L)),
                     metric_value = 0, metric_unit = "match_rate", location = entry)
    return(repro_evidence(row, ctx))
  }

  if (length(expected_hashes) == 0L) {
    row <- repro_row("R-REPRO-008", "Output Reproduction", asset, "warn", "low",
                     paste0("Entry point ran clean but no submitted outputs in '",
                            expected, "' to compare against"),
                     metric_value = NA_real_, metric_unit = "match_rate",
                     location = file.path(path, expected))
    return(repro_evidence(row, ctx))
  }

  produced_hashes <- hash_dir(file.path(run_dir, expected))
  exp_rel <- names(expected_hashes)
  reproduced <- vapply(exp_rel, function(f) {
    i <- match(f, names(produced_hashes))
    !is.na(i) && identical(unname(produced_hashes[i]), unname(expected_hashes[[f]]))
  }, logical(1))

  rate <- mean(reproduced)
  if (all(reproduced)) {
    row <- repro_row("R-REPRO-008", "Output Reproduction", asset, "pass", "info",
                     paste0("All ", length(reproduced), " submitted output(s) reproduced exactly"),
                     metric_value = rate, metric_unit = "match_rate",
                     location = file.path(path, expected))
  } else {
    bad   <- exp_rel[!reproduced]
    shown <- paste(utils::head(bad, 5L), collapse = ", ")
    more  <- if (length(bad) > 5L) paste0(" (+", length(bad) - 5L, " more)") else ""
    row <- repro_row("R-REPRO-008", "Output Reproduction", asset, "fail", "high",
                     paste0(length(bad), " of ", length(reproduced),
                            " output(s) did not reproduce: ", shown, more),
                     metric_value = rate, metric_unit = "match_rate",
                     location = shown)
  }
  repro_evidence(row, ctx)
}

#' Assess Independent (Dual) Verification
#'
#' Checks whether the submission declares independent verification of its
#' results, such as an SAS versus R comparison, QC double programming, or a
#' concordance report. The reproducibility guidance and real hybrid SAS/R
#' submissions treat independent verification of R results as first class: it is
#' how a reviewer is shown that the R output can be trusted. Returns evidence
#' with `indicator_id = "R-REPRO-009"`.
#'
#' This is a static check for the presence of verification evidence. To compare
#' two result tables directly, use [assess_sas_r_concordance()].
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub009")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("compare", file.path(d, "qc_compare_sas_r.txt"))
#' ev <- suppressMessages(assess_dual_verification(d))
#' ev$result
#'
#' @export
assess_dual_verification <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  present <- list.files(path, recursive = TRUE)
  base_lc <- tolower(basename(present))
  hit <- character(0)
  for (pat in config$verification_patterns) {
    hit <- c(hit, present[grepl(pat, base_lc, perl = TRUE)])
  }
  hit <- unique(hit)

  if (length(hit) > 0L) {
    row <- repro_row("R-REPRO-009", "Dual Verification", asset, "pass", "info",
                     paste0("Independent verification evidence found: ",
                            paste(utils::head(basename(hit), 5L), collapse = ", ")),
                     metric_value = length(hit), metric_unit = "artifacts",
                     location = paste(utils::head(hit, 5L), collapse = "; "))
  } else {
    row <- repro_row("R-REPRO-009", "Dual Verification", asset, "warn", "medium",
                     "No independent verification evidence (e.g. SAS vs R comparison or QC report) declared",
                     metric_value = 0, metric_unit = "artifacts", location = path)
  }
  repro_evidence(row, ctx)
}

#' Compare SAS and R Result Tables for Concordance
#'
#' Compares two result tables cell by cell and reports how many values agree,
#' numeric values within `tol` and other values exactly. This supports the SAS
#' versus R dual-verification step of a hybrid submission, where the same table
#' is produced in both languages and the results are reconciled. Returns
#' evidence with `indicator_id = "R-REPRO-009"`.
#'
#' @param r_data,sas_data The R and SAS result tables, as data.frames or as
#'   paths to CSV files (or SAS transport `.xpt` files when 'haven' is
#'   installed).
#' @param keys Optional character vector of key columns to order both tables by
#'   before comparing. When `NULL` the tables are compared in their given order.
#' @param tol Numeric tolerance for comparing numeric values. Defaults to 1e-8.
#' @param ctx A run context from [r4subcore::r4sub_run_context()]. When `NULL` a
#'   default `"SAS_R_COMPARISON"` context is created.
#' @return A validated evidence table.
#'
#' @examples
#' a <- data.frame(id = 1:3, val = c(1.0, 2.0, 3.0))
#' b <- data.frame(id = 1:3, val = c(1.0, 2.0, 3.0))
#' suppressMessages(assess_sas_r_concordance(a, b))$result
#'
#' @export
assess_sas_r_concordance <- function(r_data, sas_data, keys = NULL,
                                     tol = 1e-8, ctx = NULL) {
  r <- read_table_arg(r_data, "r_data")
  s <- read_table_arg(sas_data, "sas_data")
  if (is.null(ctx)) {
    ctx <- r4subcore::r4sub_run_context(study_id = "SAS_R_COMPARISON")
  } else if (!inherits(ctx, "r4sub_run_context")) {
    cli::cli_abort("{.arg ctx} must be a run context from {.fn r4subcore::r4sub_run_context}.")
  }
  asset <- "sas_r_comparison"

  common <- intersect(names(r), names(s))
  if (length(common) == 0L) {
    row <- repro_row("R-REPRO-009", "Dual Verification", asset, "warn", "medium",
                     "No shared columns between the R and SAS tables to compare",
                     metric_value = 0, metric_unit = "concordance", location = asset)
    return(repro_evidence(row, ctx))
  }

  if (!is.null(keys)) {
    keys <- intersect(keys, common)
    if (length(keys)) {
      r <- r[do.call(order, r[keys]), , drop = FALSE]
      s <- s[do.call(order, s[keys]), , drop = FALSE]
    }
  }

  if (nrow(r) != nrow(s)) {
    row <- repro_row("R-REPRO-009", "Dual Verification", asset, "warn", "medium",
                     paste0("Row counts differ (R: ", nrow(r), ", SAS: ", nrow(s),
                            "); cannot align for comparison"),
                     metric_value = 0, metric_unit = "concordance", location = asset)
    return(repro_evidence(row, ctx))
  }

  n <- nrow(r)
  cell_agree <- function(col) {
    a <- r[[col]]; b <- s[[col]]
    if (is.numeric(a) && is.numeric(b)) {
      ok <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= tol)
    } else {
      a <- as.character(a); b <- as.character(b)
      ok <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
    }
    ok[is.na(ok)] <- FALSE
    ok
  }
  agree_by_col <- vapply(common, function(col) sum(cell_agree(col)), integer(1))
  total <- n * length(common)
  rate  <- if (total > 0) sum(agree_by_col) / total else 1
  mismatched <- common[agree_by_col < n]

  if (rate >= 1) {
    row <- repro_row("R-REPRO-009", "Dual Verification", asset, "pass", "info",
                     paste0("R and SAS results concordant across ", length(common),
                            " column(s) and ", n, " row(s)"),
                     metric_value = 1, metric_unit = "concordance", location = asset)
  } else {
    shown <- paste(utils::head(mismatched, 5L), collapse = ", ")
    more  <- if (length(mismatched) > 5L) paste0(" (+", length(mismatched) - 5L, " more)") else ""
    row <- repro_row("R-REPRO-009", "Dual Verification", asset, "fail", "high",
                     paste0(round(rate * 100, 1), "% concordance; mismatches in: ",
                            shown, more),
                     metric_value = rate, metric_unit = "concordance", location = shown)
  }
  repro_evidence(row, ctx)
}

#' Assess the Analysis Data Reviewer's Guide (ADRG)
#'
#' Checks that the submission includes an Analysis Data Reviewer's Guide and,
#' when the document is a readable text format, that it covers the sections a
#' reviewer needs: required inputs, run order, expected outputs, the R packages
#' and versions, and the environment setup. The reproducibility guidance and
#' real hybrid SAS/R submissions describe the ADRG as the reviewer's map to the
#' analysis. Returns evidence with `indicator_id = "R-REPRO-010"`.
#'
#' Binary documents (`.pdf`, `.docx`) are recognised as present but their
#' sections are not inspected, so they pass with a note. Use [adrg_skeleton()]
#' to generate a Markdown ADRG draft that this check can read in full.
#'
#' @inheritParams assess_env_lockfile
#' @return A validated evidence table.
#'
#' @examples
#' d <- file.path(tempdir(), "sub010")
#' dir.create(d, showWarnings = FALSE)
#' suppressMessages(adrg_skeleton(d))
#' ev <- suppressMessages(assess_adrg(d))
#' ev$result
#'
#' @export
assess_adrg <- function(path, ctx = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)
  asset  <- basename(path)

  present <- list.files(path, recursive = TRUE)
  base_lc <- tolower(basename(present))
  is_adrg <- rep(FALSE, length(present))
  for (pat in config$adrg_names) is_adrg <- is_adrg | grepl(pat, base_lc, perl = TRUE)
  docs <- present[is_adrg]

  if (length(docs) == 0L) {
    row <- repro_row("R-REPRO-010", "Analysis Data Reviewer's Guide", asset,
                     "fail", "medium",
                     "No ADRG (Analysis Data Reviewer's Guide) document found",
                     metric_value = 0, metric_unit = "sections", location = path)
    return(repro_evidence(row, ctx))
  }

  doc <- docs[1L]
  ext <- tolower(tools::file_ext(doc))
  text_ext <- c("md", "markdown", "txt", "rmd", "rtf", "tex", "org")

  if (!ext %in% text_ext) {
    row <- repro_row("R-REPRO-010", "Analysis Data Reviewer's Guide", asset,
                     "pass", "info",
                     paste0("ADRG present (", basename(doc),
                            "); binary format not inspected for sections"),
                     metric_value = NA_real_, metric_unit = "sections",
                     location = doc)
    return(repro_evidence(row, ctx))
  }

  text <- tolower(paste(read_lines_safe(file.path(path, doc)), collapse = "\n"))
  req  <- config$adrg_required_sections
  found <- vapply(req, function(p) grepl(p, text, perl = TRUE), logical(1))
  rate  <- mean(found)

  if (all(found)) {
    row <- repro_row("R-REPRO-010", "Analysis Data Reviewer's Guide", asset,
                     "pass", "info",
                     paste0("ADRG present and covers all ", length(req),
                            " required sections (", basename(doc), ")"),
                     metric_value = rate, metric_unit = "sections", location = doc)
  } else {
    missing <- names(req)[!found]
    row <- repro_row("R-REPRO-010", "Analysis Data Reviewer's Guide", asset,
                     "warn", "medium",
                     paste0("ADRG present but missing section(s): ",
                            paste(missing, collapse = ", ")),
                     metric_value = rate, metric_unit = "sections", location = doc)
  }
  repro_evidence(row, ctx)
}

#' Generate an ADRG Draft
#'
#' Writes a Markdown Analysis Data Reviewer's Guide following the standard PHUSE
#' / R Consortium ADRG structure (sections 1 to 8 plus an R execution appendix),
#' pre-filled by statically scanning the submission folder. From the scan it
#' auto-fills the analysis datasets, the analysis output programs and their
#' outputs, a program-to-output traceability table of the inputs each program
#' reads, the proprietary and open-source R packages split with versions, the R
#' version, and the execution steps. It also adds a Reproducibility and
#' Verification section (environment, SAS vs R verification, clean-run evidence)
#' that the base ADRG template omits. Sections needing human judgement are
#' marked TODO. The draft contains every section [assess_adrg()] checks for.
#'
#' @param path Path to the submission's analysis code folder.
#' @param out Output file. When `NULL`, writes `ADRG.md` inside `path`.
#' @param config A configuration from [repro_config_default()].
#' @return The path to the written file, invisibly.
#'
#' @examples
#' d <- file.path(tempdir(), "sub_adrg")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "run.R"))
#' f <- adrg_skeleton(d)
#' file.exists(f)
#'
#' @export
adrg_skeleton <- function(path = ".", out = NULL, config = NULL) {
  assert_path(path)
  config <- resolve_config(config)
  if (is.null(out)) out <- file.path(path, "ADRG.md")

  scan  <- adrg_scan(path, config)
  study <- basename(normalizePath(path, winslash = "/", mustWork = FALSE))

  ds_block <- if (length(scan$datasets)) paste0("- ", scan$datasets) else
    "TODO: list the analysis datasets (ADSL, ADAE, ADTTE, ...) and their structure."

  prog_out <- if (nrow(scan$programs)) {
    md_table(scan$programs[, c("Program", "Outputs")])
  } else "TODO: list the analysis output programs and the outputs they create."

  trace_tbl <- if (nrow(scan$programs)) {
    md_table(scan$programs[, c("Program", "Inputs")])
  } else "TODO: map each program to the datasets and variables it reads."

  prop_block <- if (nrow(scan$proprietary)) md_table(scan$proprietary) else
    "None. All analysis packages are open source."

  open_block <- if (nrow(scan$opensource)) md_table(scan$opensource) else
    "TODO: list the open-source R packages and versions used."

  install_line <- if (nrow(scan$opensource)) {
    paste0('install.packages(c(',
           paste0('"', scan$opensource$Package, '"', collapse = ", "), '))')
  } else 'install.packages(c( ... ))'

  entry_block <- if (length(scan$entries)) {
    paste0("- `", scan$entries, "`")
  } else "- TODO: add the run script(s) a reviewer executes, in order."

  lines <- c(
    "# Analysis Data Reviewer's Guide (ADRG)",
    "",
    paste0("Study: ", study),
    "",
    "Draft generated by r4subrepro from a static scan of the analysis folder.",
    "Lines marked TODO need sponsor input; review every auto-filled table before submission.",
    "",
    "## 1. Introduction",
    "### 1.1 Purpose",
    "This guide gives context for the analysis datasets and programs beyond the",
    "data definition document (define.xml), and a summary of conformance findings.",
    "",
    "### 1.2 Study Data Standards and Dictionary Inventory",
    "| Standard or Dictionary | Version Used |",
    "| --- | --- |",
    "| SDTM | TODO |",
    "| ADaM | TODO |",
    "| Controlled Terminology | TODO |",
    "| Data Definitions | define.xml TODO |",
    "| Medications Dictionary | TODO |",
    "",
    "### 1.3 Source Data Used for Analysis Dataset Creation",
    "TODO: describe the source ADaM/SDTM data and where it comes from.",
    "",
    "## 2. Protocol Description",
    "### 2.1 Protocol Number and Title",
    "TODO: protocol number and title.",
    "### 2.2 Protocol Design in Relation to ADaM Concepts",
    "TODO: objectives, methodology, planned number of subjects, study schema.",
    "",
    "## 3. Analysis Considerations Related to Multiple Analysis Datasets",
    "### 3.1 Core Variables",
    "TODO: variables represented across most analysis datasets.",
    "### 3.2 Treatment Variables",
    "TODO: planned vs actual treatment variables.",
    "### 3.3 Use of Visit Windowing, Unscheduled Visits, and Record Selection",
    "TODO.",
    "### 3.4 Imputation/Derivation Methods",
    "TODO, or 'Not applicable'.",
    "",
    "## 4. Analysis Data Creation and Processing Issues",
    "### 4.1 Data Dependencies",
    "TODO: dependencies between datasets (for example ADAE -> ADTTE).",
    "",
    "## 5. Analysis Dataset Descriptions",
    "### 5.1 Overview",
    "TODO: what the submitted analyses cover.",
    "### 5.2 Analysis Datasets",
    ds_block,
    "",
    "## 6. Data Conformance Summary",
    "### 6.1 Conformance Inputs",
    "TODO: Were the datasets evaluated with CDISC ADaM Validation Checks",
    "(for example Pinnacle 21)? Were they evaluated against define.xml?",
    "### 6.2 Issues Summary",
    "TODO: list any conformance findings, severity, and explanation.",
    "",
    "## 7. Submission of Programs",
    "### 7.1 Description",
    paste0("Programs that produce the analysis results were created using R version ",
           scan$r_version, "."),
    "### 7.2 ADaM Programs",
    "TODO, or 'Not applicable' if only analysis-output programs are submitted.",
    "### 7.3 Analysis Output Programs",
    prog_out,
    "",
    "### 7.4 Proprietary R Analysis Packages",
    prop_block,
    "",
    "### 7.5 Open-source R Analysis Packages",
    open_block,
    "",
    "### 7.6 Program-to-Output Traceability",
    "Inputs each program reads (complete with variables and selection criteria):",
    trace_tbl,
    "",
    "## 8. Directory Structure",
    "Datasets and supporting files follow the FDA Study Data Technical Conformance Guide:",
    "- m5/datasets/<study>/analysis/adam/datasets - ADaM datasets, this ADRG, define files",
    "- m5/datasets/<study>/analysis/adam/programs - analysis programs",
    "",
    "## 9. Reproducibility and Verification",
    "### 9.1 Environment and lockfile",
    "A captured package environment (renv.lock) and a single package list file are",
    "included so the reviewer can restore exact versions on a standard Windows system.",
    "### 9.2 Independent verification (SAS vs R)",
    "TODO: describe how the R results were independently verified, for example an",
    "SAS vs R comparison of the RTF outputs, or cross-checks against SAS procedures.",
    "### 9.3 Clean-run reproduction evidence",
    "TODO: confirm the submitted outputs were reproduced from a clean run, and attach",
    "the session information. r4subrepro::assess_output_reproduction() can verify this.",
    "",
    "## Appendix: Instructions to Execute Analysis Programs in R",
    paste0("1. Install R ", scan$r_version, "."),
    "2. Create a working directory and copy all submitted programs into it.",
    "3. Restore the package environment (for example `renv::restore()` from renv.lock),",
    "   or set a dated snapshot repository, so the exact versions are installed.",
    paste0("4. Install the open-source packages: `", install_line, "`"),
    "5. Install any proprietary packages (see section 7.4) from the bundled sources.",
    "6. Set the input and output paths relative to the project root.",
    "7. Execute the analysis program(s):",
    entry_block,
    ""
  )
  writeLines(lines, out)
  cli::cli_alert_success("Wrote ADRG draft to {.path {out}}")
  invisible(out)
}

#' Assess Reproducibility of a Submission Folder
#'
#' Runs the static reproducibility indicators over a submission's analysis code
#' folder and returns the combined R4SUB evidence table. The rows carry
#' `indicator_domain = "usability"`, so they flow directly into the Submission
#' Confidence Index alongside the other reviewer-experience indicators.
#'
#' @param path Path to the submission's analysis code folder.
#' @param ctx A run context from [r4subcore::r4sub_run_context()]. When `NULL` a
#'   default context is created from the folder name.
#' @param config A configuration from [repro_config_default()].
#' @param include_execution When `TRUE`, also runs [assess_output_reproduction()]
#'   (`R-REPRO-008`), which executes the submission's entry point. Off by
#'   default so the scan stays static and never runs submission code unasked.
#'
#' @return A validated, combined evidence table for indicators `R-REPRO-001`
#'   through `R-REPRO-007`, `R-REPRO-009`, and `R-REPRO-010`, plus `R-REPRO-008`
#'   when `include_execution = TRUE`.
#'
#' @examples
#' d <- file.path(tempdir(), "sub_all")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("{}", file.path(d, "renv.lock"))
#' writeLines("source('a.R')", file.path(d, "run.R"))
#' writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
#' ev <- suppressMessages(assess_reproducibility(d))
#' table(ev$result)
#'
#' @export
assess_reproducibility <- function(path, ctx = NULL,
                                   config = repro_config_default(),
                                   include_execution = FALSE) {
  assert_path(path)
  config <- resolve_config(config)
  ctx    <- repro_resolve_ctx(ctx, path)

  parts <- list(
    assess_env_lockfile(path, ctx, config),
    assess_path_hygiene(path, ctx, config),
    assess_entry_point(path, ctx, config),
    assess_hidden_setup(path, ctx, config),
    assess_proprietary_pkgs(path, ctx, config),
    assess_clean_run_evidence(path, ctx, config),
    assess_script_depth(path, ctx, config),
    assess_dual_verification(path, ctx, config),
    assess_adrg(path, ctx, config)
  )
  if (isTRUE(include_execution)) {
    parts <- c(parts, list(assess_output_reproduction(path, ctx = ctx, config = config)))
  }
  do.call(r4subcore::bind_evidence, parts)
}
