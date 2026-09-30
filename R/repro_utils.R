# Internal helpers for r4subrepro. Not exported.

# Resolve a run context, creating a default one from the folder name when NULL.
repro_resolve_ctx <- function(ctx, path) {
  if (is.null(ctx)) {
    study <- basename(normalizePath(path, winslash = "/", mustWork = FALSE))
    if (is.na(study) || !nzchar(study)) study <- "REPRO"
    return(r4subcore::r4sub_run_context(study_id = study))
  }
  if (!inherits(ctx, "r4sub_run_context")) {
    cli::cli_abort(
      "{.arg ctx} must be a run context from {.fn r4subcore::r4sub_run_context}."
    )
  }
  ctx
}

# The package version string, computed once per call rather than per row.
repro_source_version <- function() {
  as.character(utils::packageVersion("r4subrepro"))
}

# Abort clearly when the target folder does not exist.
assert_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort("{.arg path} must be a single directory path.")
  }
  if (!dir.exists(path)) {
    cli::cli_abort("Directory not found: {.path {path}}")
  }
  invisible(path)
}

# List R and R Markdown scripts under a folder (recursive).
list_r_files <- function(path) {
  list.files(path, pattern = "\\.(R|r|Rmd|rmd|Rnw)$", recursive = TRUE,
             full.names = TRUE)
}

# Read a file's lines, returning character(0) on any read error.
read_lines_safe <- function(f) {
  tryCatch(readLines(f, warn = FALSE, encoding = "UTF-8"),
           error = function(e) character(0))
}

# Build a single evidence row as a plain data.frame in schema column order.
repro_row <- function(indicator_id, indicator_name, asset_id, result, severity,
                      message, metric_value = NA_real_, metric_unit = NA_character_,
                      location = NA_character_, pkg_ver = repro_source_version(),
                      asset_type = "program") {
  data.frame(
    asset_type       = asset_type,
    asset_id         = asset_id,
    source_name      = "r4subrepro",
    source_version   = pkg_ver,
    indicator_id     = indicator_id,
    indicator_name   = indicator_name,
    indicator_domain = "usability",
    severity         = severity,
    result           = result,
    metric_value     = as.numeric(metric_value),
    metric_unit      = metric_unit,
    message          = message,
    location         = location,
    evidence_payload = "{}",
    stringsAsFactors = FALSE
  )
}

# Coerce a one row data.frame into a validated evidence table.
repro_evidence <- function(row, ctx) {
  r4subcore::as_evidence(row, ctx = ctx)
}

# Maximum brace nesting depth across a set of code lines. Comments are stripped
# with a simple heuristic; braces inside strings are a rare enough source of
# noise that a running balance is a good, deterministic proxy for complexity.
max_brace_depth <- function(lines) {
  if (length(lines) == 0L) return(0L)
  no_comment <- sub("#.*$", "", lines)
  depth <- 0L
  max_depth <- 0L
  chars <- strsplit(paste(no_comment, collapse = "\n"), "")[[1]]
  for (ch in chars) {
    if (ch == "{") {
      depth <- depth + 1L
      if (depth > max_depth) max_depth <- depth
    } else if (ch == "}") {
      depth <- max(0L, depth - 1L)
    }
  }
  max_depth
}

# Packages treated as reproducible without an explicit declaration: base and
# recommended packages plus a curated set of common CRAN and pharma packages,
# and the R4SUB ecosystem. This is a bundled allowlist, not a live CRAN query,
# so the check is deterministic and works offline.
known_pkgs <- function() {
  base_rec <- rownames(utils::installed.packages(priority = c("base", "recommended")))
  if (is.null(base_rec)) base_rec <- character(0)
  common <- c(
    "dplyr", "tidyr", "purrr", "tibble", "readr", "stringr", "forcats",
    "ggplot2", "lubridate", "glue", "cli", "rlang", "vctrs", "magrittr",
    "data.table", "jsonlite", "xml2", "httr", "readxl", "writexl", "openxlsx",
    "haven", "knitr", "rmarkdown", "shiny", "bslib", "htmltools", "DT",
    "gt", "gtsummary", "flextable", "officer", "testthat", "withr", "fs",
    "here", "renv", "devtools", "usethis", "roxygen2", "pkgdown",
    "admiral", "admiraldev", "metacore", "metatools", "xportr",
    "pharmaverseadam", "pharmaversesdtm", "Tplyr", "rtables", "tern",
    "r4sub", "r4subcore", "r4subscore", "r4subtrace", "r4subrisk",
    "r4subdata", "r4subprofile", "r4subusability", "r4subpharma", "r4subrepro"
  )
  unique(c(base_rec, common))
}

# Extract package names referenced by library(), require(), requireNamespace(),
# and pkg:: usage across a set of code lines.
extract_packages <- function(lines) {
  text <- paste(lines, collapse = "\n")
  pkgs <- character(0)

  lib <- regmatches(
    text,
    gregexpr("(?:library|require)\\(\\s*[\"']?([A-Za-z][A-Za-z0-9._]*)", text,
             perl = TRUE)
  )[[1]]
  if (length(lib)) {
    pkgs <- c(pkgs, sub(".*[\\(]\\s*[\"']?", "", lib))
  }

  rns <- regmatches(
    text,
    gregexpr("requireNamespace\\(\\s*[\"']([A-Za-z][A-Za-z0-9._]*)[\"']", text,
             perl = TRUE)
  )[[1]]
  if (length(rns)) {
    pkgs <- c(pkgs, sub(".*[\"']", "", rns))
  }

  colon <- regmatches(
    text,
    gregexpr("([A-Za-z][A-Za-z0-9._]*)(?=:::?)", text, perl = TRUE)
  )[[1]]
  if (length(colon)) pkgs <- c(pkgs, colon)

  unique(pkgs[nzchar(pkgs)])
}

# Packages declared in a captured environment (renv.lock or a versioned
# DESCRIPTION), used to excuse an otherwise unknown package.
declared_packages <- function(path) {
  declared <- character(0)
  lock <- file.path(path, "renv.lock")
  if (file.exists(lock)) {
    txt <- read_lines_safe(lock)
    nm <- regmatches(txt, regexpr("\"Package\"\\s*:\\s*\"[^\"]+\"", txt))
    nm <- sub(".*:\\s*\"", "", nm)
    nm <- sub("\"$", "", nm)
    declared <- c(declared, nm[nzchar(nm)])
  }
  desc <- file.path(path, "DESCRIPTION")
  if (file.exists(desc)) {
    dcf <- tryCatch(read.dcf(desc), error = function(e) NULL)
    if (!is.null(dcf)) {
      fields <- intersect(c("Imports", "Depends", "Suggests"), colnames(dcf))
      for (f in fields) {
        parts <- strsplit(dcf[1, f], ",")[[1]]
        parts <- trimws(sub("\\(.*", "", parts))
        declared <- c(declared, parts[nzchar(parts) & parts != "R"])
      }
    }
  }
  unique(declared)
}
