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

# Coerce a data argument into a data.frame: pass a data.frame through, or read a
# CSV path, or a SAS transport (.xpt) path when 'haven' is available.
read_table_arg <- function(x, arg = "data") {
  if (is.data.frame(x)) return(as.data.frame(x))
  if (is.character(x) && length(x) == 1L && !is.na(x) && file.exists(x)) {
    ext <- tolower(tools::file_ext(x))
    if (ext == "xpt") {
      if (!requireNamespace("haven", quietly = TRUE)) {
        cli::cli_abort("Reading a {.file .xpt} file needs the {.pkg haven} package.")
      }
      return(as.data.frame(haven::read_xpt(x)))
    }
    return(utils::read.csv(x, stringsAsFactors = FALSE))
  }
  cli::cli_abort("{.arg {arg}} must be a data.frame or a path to a CSV or .xpt file.")
}

# Render a data.frame as a GitHub-flavoured Markdown table. Empty when no rows.
md_table <- function(df) {
  if (nrow(df) == 0L) return(character(0))
  esc    <- function(x) gsub("|", "\\|", as.character(x), fixed = TRUE)
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep    <- paste0("|", paste(rep(" --- ", ncol(df)), collapse = "|"), "|")
  rows   <- vapply(seq_len(nrow(df)), function(i) {
    paste0("| ", paste(vapply(df[i, ], esc, character(1)), collapse = " | "), " |")
  }, character(1))
  c(header, sep, rows)
}

# Capture the first quoted file-like argument of calls to any of `funcs`. Used to
# recover the inputs a program reads and the outputs it writes. Best effort:
# matches a literal string argument on a single line.
capture_files <- function(text, funcs) {
  if (!length(text)) return(character(0))
  pat <- paste0("(?:", paste(funcs, collapse = "|"),
                ")\\s*\\([^\"')]*[\"'][^\"']+[\"']")
  raw <- unlist(regmatches(text, gregexpr(pat, text, perl = TRUE)))
  files <- sub("[\"']$", "", sub("^[^\"']+[\"']", "", raw))
  unique(files[nzchar(files)])
}

# Statically scan a submission folder for the facts an ADRG draft needs:
# per-program inputs/outputs, analysis datasets, proprietary vs open-source
# packages (with versions), the R version, and entry points.
adrg_scan <- function(path, config) {
  files     <- list_r_files(path)
  all_lines <- unlist(lapply(files, read_lines_safe))

  read_funcs  <- c("read\\.csv", "read_csv", "read_sas", "read_xpt",
                   "read\\.table", "readRDS", "read_rds")
  write_funcs <- c("write\\.csv", "write_csv", "write_xpt", "write_sas",
                   "saveRDS", "write_rds", "ggsave", "write\\.table",
                   "rtf_encode", "write_rtf")

  prog_tbl <- data.frame(Program = character(0), Inputs = character(0),
                         Outputs = character(0), stringsAsFactors = FALSE)
  for (f in files) {
    ln   <- read_lines_safe(f)
    ins  <- capture_files(ln, read_funcs)
    outs <- capture_files(ln, write_funcs)
    prog_tbl <- rbind(prog_tbl, data.frame(
      Program = basename(f),
      Inputs  = if (length(ins))  paste(ins, collapse = "; ")  else "(none detected)",
      Outputs = if (length(outs)) paste(outs, collapse = "; ") else "(none detected)",
      stringsAsFactors = FALSE))
  }

  present <- list.files(path, recursive = TRUE)
  ds <- sort(unique(basename(present[grepl("\\.(xpt|sas7bdat)$", tolower(present))])))

  pkgs <- extract_packages(all_lines)
  pkgs <- setdiff(pkgs, c("base", "stats", "utils", "methods", "graphics",
                          "grDevices", "datasets", "tools"))
  kp       <- known_pkgs()
  versions <- declared_package_versions(path)
  ver_of   <- function(p) { v <- versions[[p]]; if (is.null(v)) "(add version)" else v }
  prop <- sort(setdiff(pkgs, kp))
  open <- sort(intersect(pkgs, kp))
  prop_tbl <- data.frame(Package = prop, Version = vapply(prop, ver_of, character(1)),
                         stringsAsFactors = FALSE)
  open_tbl <- data.frame(Package = open, Version = vapply(open, ver_of, character(1)),
                         stringsAsFactors = FALSE)

  rver <- "(specify the R version used)"
  lock <- file.path(path, "renv.lock")
  if (file.exists(lock)) {
    lk  <- read_lines_safe(lock)
    idx <- grep("\"R\"\\s*:", lk)
    if (length(idx)) {
      after <- lk[idx[1]:min(length(lk), idx[1] + 5L)]
      mv <- regmatches(after, regexpr("\"Version\"\\s*:\\s*\"[^\"]+\"", after))
      mv <- mv[nzchar(mv)]
      if (length(mv)) rver <- sub("\"$", "", sub(".*:\\s*\"", "", mv[1]))
    }
  }

  entries <- present[tolower(basename(present)) %in% tolower(config$entry_point_names)]

  list(programs = prog_tbl, datasets = ds, proprietary = prop_tbl,
       opensource = open_tbl, r_version = rver, entries = entries)
}

# Hash every file under a directory, returning a character vector of MD5 sums
# named by path relative to that directory. Empty when the directory is absent.
hash_dir <- function(dir) {
  if (!dir.exists(dir)) return(stats::setNames(character(0), character(0)))
  files <- list.files(dir, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  if (length(files) == 0L) return(stats::setNames(character(0), character(0)))
  full <- file.path(dir, files)
  stats::setNames(as.character(tools::md5sum(full)), files)
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
    "r2rtf", "visR", "cowplot", "huxtable", "pharmaRTF", "pkglite",
    "emmeans", "broom", "survival", "survminer", "nlme", "lme4", "mmrm",
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

# Source tier of each package declared in an renv.lock, as a named list
# pkg -> "cran" (a versioned repository a reviewer can restore from a dated
# snapshot) or "noncran" (GitHub, Git, URL, Bioconductor, or local source that
# must be bundled with the submission). Same light line parser as the versions
# reader: track the current package, then classify from its "Source" field.
declared_package_sources <- function(path) {
  res <- list()
  lock <- file.path(path, "renv.lock")
  if (!file.exists(lock)) return(res)
  txt <- read_lines_safe(lock)
  cur <- NA_character_
  for (ln in txt) {
    mp <- regmatches(ln, regexpr("\"Package\"\\s*:\\s*\"[^\"]+\"", ln))
    if (length(mp)) cur <- sub("\"$", "", sub(".*:\\s*\"", "", mp))
    ms <- regmatches(ln, regexpr("\"Source\"\\s*:\\s*\"[^\"]+\"", ln))
    if (length(ms) && !is.na(cur)) {
      src <- tolower(sub("\"$", "", sub(".*:\\s*\"", "", ms)))
      res[[cur]] <- if (src %in% c("repository", "cran")) "cran" else "noncran"
      cur <- NA_character_
    }
  }
  res
}

# Read a file as raw bytes, returning NULL on any error or an empty file.
read_bytes <- function(path) {
  n <- tryCatch(file.info(path)$size, error = function(e) NA_real_)
  if (is.na(n) || n == 0) return(NULL)
  con <- tryCatch(file(path, "rb"), error = function(e) NULL)
  if (is.null(con)) return(NULL)
  on.exit(close(con))
  tryCatch(readBin(con, "raw", n), error = function(e) NULL)
}

# Normalise a cosmetic output file to its analytical content by stripping the
# embedded generation timestamps that change on every run (RTF creatim/revtim
# groups, PDF CreationDate/ModDate and file ID). Returns the normalised text, or
# NA when the file cannot be read. Best effort: it removes the volatile bytes a
# re-run changes so that two outputs with identical numbers compare equal.
normalize_cosmetic <- function(path, ext) {
  raw <- read_bytes(path)
  if (is.null(raw)) return(NA_character_)
  raw[raw == as.raw(0L)] <- as.raw(0x20)   # drop NULs so rawToChar is safe
  txt <- tryCatch(rawToChar(raw), error = function(e) NA_character_)
  if (is.na(txt)) return(NA_character_)
  if (ext == "rtf") {
    txt <- gsub("\\{\\\\\\*?\\\\(creatim|revtim|printim|buptim)[^}]*\\}", "",
                txt, perl = TRUE, useBytes = TRUE)
    txt <- gsub("\\\\(yr|mo|dy|hr|min|sec)[0-9]+", "",
                txt, perl = TRUE, useBytes = TRUE)
  } else if (ext == "pdf") {
    txt <- gsub("/(CreationDate|ModDate)\\s*\\(D:[^)]*\\)", "",
                txt, perl = TRUE, useBytes = TRUE)
    txt <- gsub("/ID\\s*\\[[^]]*\\]", "", txt, perl = TRUE, useBytes = TRUE)
  }
  gsub("[[:space:]]+", " ", txt, perl = TRUE, useBytes = TRUE)
}

# Classify one produced output against its submitted counterpart:
#   exact    - byte-for-byte identical
#   cosmetic - differs only in embedded timestamps (cosmetic formats)
#   mismatch - analytical content differs
#   missing  - the re-run did not produce the file
output_status <- function(exp_path, prod_path, cosmetic_ext) {
  if (!file.exists(prod_path)) return("missing")
  if (identical(unname(tools::md5sum(exp_path)),
                unname(tools::md5sum(prod_path)))) return("exact")
  ext <- tolower(tools::file_ext(exp_path))
  if (ext %in% cosmetic_ext) {
    a <- normalize_cosmetic(exp_path, ext)
    b <- normalize_cosmetic(prod_path, ext)
    if (!is.na(a) && !is.na(b) && identical(a, b)) return("cosmetic")
  }
  "mismatch"
}

# Detect signals that the submission compiles native code and so needs a
# compiler toolchain (Rtools on Windows): C/C++/Fortran source, a src/ folder,
# Makevars build scripts, or inline compilation calls in the R code. Returns a
# character vector of the signals found (empty when none).
compiled_signals <- function(path, config) {
  signals <- character(0)
  present <- list.files(path, recursive = TRUE)
  base_lc <- tolower(basename(present))

  ext_hits <- present[tolower(tools::file_ext(present)) %in% config$compiled_source_ext]
  if (length(ext_hits)) {
    signals <- c(signals, paste0("native source (",
                                 paste(utils::head(basename(ext_hits), 3L),
                                       collapse = ", "), ")"))
  }
  if (any(base_lc %in% config$compiled_build_files)) {
    signals <- c(signals, "Makevars build script")
  }
  if (dir.exists(file.path(path, "src"))) signals <- c(signals, "src/ folder")

  text <- paste(unlist(lapply(list_r_files(path), read_lines_safe)),
                collapse = "\n")
  for (p in config$compiled_call_patterns) {
    if (grepl(p, text, perl = TRUE)) {
      signals <- c(signals, "inline compilation call")
      break
    }
  }
  unique(signals)
}

# Whether the submission documents the compiler toolchain (Rtools) in any of its
# text files (ADRG, README, run logs).
documents_toolchain <- function(path, config) {
  docs <- list.files(path, recursive = TRUE, full.names = TRUE,
                     pattern = "\\.(md|markdown|txt|rmd|rtf|tex|org)$",
                     ignore.case = TRUE)
  for (f in docs) {
    text <- tolower(paste(read_lines_safe(f), collapse = "\n"))
    if (grepl(config$toolchain_doc_pattern, text, perl = TRUE)) return(TRUE)
  }
  FALSE
}

# Package versions declared in an renv.lock, as a named list pkg -> version.
# Light line parser so no JSON dependency is needed; handles the common
# "Package" then "Version" layout renv writes.
declared_package_versions <- function(path) {
  res <- list()
  lock <- file.path(path, "renv.lock")
  if (!file.exists(lock)) return(res)
  txt <- read_lines_safe(lock)
  cur <- NA_character_
  for (ln in txt) {
    mp <- regmatches(ln, regexpr("\"Package\"\\s*:\\s*\"[^\"]+\"", ln))
    if (length(mp)) cur <- sub("\"$", "", sub(".*:\\s*\"", "", mp))
    mv <- regmatches(ln, regexpr("\"Version\"\\s*:\\s*\"[^\"]+\"", ln))
    if (length(mv) && !is.na(cur)) {
      res[[cur]] <- sub("\"$", "", sub(".*:\\s*\"", "", mv))
      cur <- NA_character_
    }
  }
  res
}
