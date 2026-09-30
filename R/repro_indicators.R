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

#' Assess Reproducibility of a Submission Folder
#'
#' Runs all seven reproducibility indicators over a submission's analysis code
#' folder and returns the combined R4SUB evidence table. The rows carry
#' `indicator_domain = "usability"`, so they flow directly into the Submission
#' Confidence Index alongside the other reviewer-experience indicators.
#'
#' @param path Path to the submission's analysis code folder.
#' @param ctx A run context from [r4subcore::r4sub_run_context()]. When `NULL` a
#'   default context is created from the folder name.
#' @param config A configuration from [repro_config_default()].
#'
#' @return A validated, combined evidence table for indicators `R-REPRO-001`
#'   through `R-REPRO-007`.
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
                                   config = repro_config_default()) {
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
    assess_script_depth(path, ctx, config)
  )
  do.call(r4subcore::bind_evidence, parts)
}
