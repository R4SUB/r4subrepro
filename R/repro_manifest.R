# File-hash manifest capture and verification. A manifest is an integrity
# record of every file in a submission (relative path, size, and MD5 hash),
# which a reviewer can later verify the received files against. This is a
# descriptive/integrity layer: it emits no R4SUB evidence and does not change
# any indicator logic, threshold, weight, or score.

# Internal: scan a folder into a data.frame of file (relative, forward slashes),
# bytes (size), and hash (MD5). Excludes any relative path matching a regex in
# `exclude`. Returns the rows ordered by file.
manifest_scan <- function(path, exclude = NULL) {
  rel <- list.files(path, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  rel <- gsub("\\\\", "/", rel)
  # Drop directories that list.files may surface as empty-dir placeholders;
  # list.files returns files only, but guard against directory entries anyway.
  if (length(rel)) {
    full <- file.path(path, rel)
    rel  <- rel[!dir.exists(full)]
  }
  if (length(rel) && length(exclude)) {
    drop <- rep(FALSE, length(rel))
    for (p in exclude) drop <- drop | grepl(p, rel, perl = TRUE)
    rel <- rel[!drop]
  }
  if (!length(rel)) {
    return(data.frame(file = character(0), bytes = numeric(0),
                      hash = character(0), stringsAsFactors = FALSE))
  }
  rel  <- sort(rel)
  full <- file.path(path, rel)
  bytes <- as.numeric(file.info(full)$size)
  hash  <- unname(as.character(tools::md5sum(full)))
  data.frame(file = rel, bytes = bytes, hash = hash,
             stringsAsFactors = FALSE)
}

# Internal: the normalised relative path of `file` within `path`, or NA when it
# is not inside the folder. Used to auto-exclude a manifest written into the
# submission folder from its own verification.
manifest_rel_within <- function(file, path) {
  if (!is.character(file) || length(file) != 1L || is.na(file)) return(NA_character_)
  fp <- normalizePath(file, winslash = "/", mustWork = FALSE)
  rp <- normalizePath(path, winslash = "/", mustWork = FALSE)
  rp_slash <- paste0(sub("/$", "", rp), "/")
  if (startsWith(fp, rp_slash)) substring(fp, nchar(rp_slash) + 1L) else NA_character_
}

# Internal: read a manifest JSON file into a data.frame of file + hash.
manifest_read_json <- function(file) {
  doc <- tryCatch(
    jsonlite::fromJSON(paste(read_lines_safe(file), collapse = "\n"),
                       simplifyVector = FALSE),
    error = function(e) NULL)
  if (is.null(doc) || is.null(doc$files)) {
    cli::cli_abort("{.arg manifest} is not a readable r4subrepro manifest: {.path {file}}")
  }
  files <- doc$files
  if (!length(files)) {
    return(data.frame(file = character(0), hash = character(0),
                      stringsAsFactors = FALSE))
  }
  data.frame(
    file = vapply(files, function(f) as.character(f$file), character(1)),
    hash = vapply(files, function(f) {
      h <- f$hash
      if (is.null(h) || is.na(h)) NA_character_ else as.character(h)
    }, character(1)),
    stringsAsFactors = FALSE)
}

# Internal: coerce the manifest argument to a data.frame of expected file + hash.
manifest_expected <- function(manifest) {
  if (is.data.frame(manifest)) {
    if (!all(c("file", "hash") %in% names(manifest))) {
      cli::cli_abort(
        "A data frame {.arg manifest} must have {.field file} and {.field hash} columns."
      )
    }
    return(data.frame(file = as.character(manifest$file),
                      hash = as.character(manifest$hash),
                      stringsAsFactors = FALSE))
  }
  if (is.character(manifest) && length(manifest) == 1L && !is.na(manifest)) {
    if (!file.exists(manifest)) {
      cli::cli_abort("Manifest file not found: {.path {manifest}}")
    }
    return(manifest_read_json(manifest))
  }
  cli::cli_abort(paste0(
    "{.arg manifest} must be a manifest data frame from {.fn repro_manifest} ",
    "or a path to a manifest JSON file."
  ))
}

#' Capture a File-Hash Manifest of a Submission
#'
#' Records an integrity manifest of every file in a submission's analysis code
#' folder: its path (relative to the folder, with forward slashes), size in
#' bytes, and MD5 hash. The manifest lets a reviewer confirm that the files they
#' received are byte-for-byte the files the sponsor hashed, and lets a
#' reproduction run confirm that nothing in the folder changed. Hashing uses
#' [tools::md5sum()], the same mechanism the output-reproduction check
#' ([assess_output_reproduction()]) already uses, so the manifest is
#' deterministic and needs no network access.
#'
#' This is an integrity helper, not an indicator. It emits no R4SUB evidence,
#' carries no severity, and does not change the pass/fail or score of any
#' indicator. Verify a folder against a manifest with [repro_manifest_verify()].
#'
#' @param path Path to the submission's analysis code folder.
#' @param file Optional path to write the manifest to as JSON. When supplied, the
#'   manifest is written there and the path is returned invisibly; otherwise the
#'   manifest tibble is returned.
#' @param exclude Optional character vector of regular expressions matched
#'   against each file's relative path. Any file whose path matches is left out
#'   of the manifest (for example `"\\.log$"` to skip run logs).
#'
#' @return A [tibble][tibble::tibble] with one row per file and the columns
#'   `file` (relative path, forward slashes), `bytes` (size, numeric), `algo`
#'   (the hash algorithm, `"md5"`), and `hash` (the lowercase MD5 digest). When
#'   `file` is supplied, the path to the written JSON manifest is returned
#'   invisibly instead. The JSON document carries a `manifest_type`, a
#'   `schema_version`, the generation time, the algorithm, the source package and
#'   version, the folder name, the file count, and a `files` array.
#'
#' @seealso [repro_manifest_verify()] to check a folder against a manifest.
#'
#' @examples
#' d <- file.path(tempdir(), "sub_manifest")
#' dir.create(file.path(d, "data"), recursive = TRUE, showWarnings = FALSE)
#' writeLines("source('a.R')", file.path(d, "run.R"))
#' writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
#' writeLines("usubjid,age\n01,55", file.path(d, "data", "adsl.csv"))
#'
#' # As a tibble
#' repro_manifest(d)
#'
#' # Written to a JSON file
#' mf <- repro_manifest(d, file = file.path(d, "manifest.json"))
#' file.exists(mf)
#'
#' @export
repro_manifest <- function(path, file = NULL, exclude = NULL) {
  assert_path(path)
  if (!is.null(exclude) && !is.character(exclude)) {
    cli::cli_abort("{.arg exclude} must be a character vector of patterns or NULL.")
  }

  scan <- manifest_scan(path, exclude)

  tbl <- tibble::tibble(
    file  = scan$file,
    bytes = as.numeric(scan$bytes),
    algo  = rep("md5", nrow(scan)),
    hash  = scan$hash
  )

  if (is.null(file)) return(tbl)

  if (!is.character(file) || length(file) != 1L || is.na(file)) {
    cli::cli_abort("{.arg file} must be a single file path.")
  }
  files <- lapply(seq_len(nrow(scan)), function(i) {
    list(file = scan$file[i], bytes = scan$bytes[i], hash = scan$hash[i])
  })
  doc <- list(
    manifest_type  = "r4subrepro file manifest",
    schema_version = "1",
    generated      = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    algo           = "md5",
    source         = list(name = "r4subrepro", version = repro_source_version()),
    root           = basename(normalizePath(path, winslash = "/", mustWork = FALSE)),
    n_files        = nrow(scan),
    files          = files
  )
  json <- jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null",
                           na = "null")
  writeLines(as.character(json), file)
  cli::cli_alert_success("Wrote file manifest ({nrow(scan)} file{?s}) to {.path {file}}")
  invisible(file)
}

#' Verify a Submission Against a File-Hash Manifest
#'
#' Re-hashes the files currently in a submission folder and compares them to a
#' manifest captured earlier with [repro_manifest()], reporting which files are
#' unchanged, modified, added, or removed. This is how a reviewer confirms that
#' the submission they received matches what the sponsor recorded, and how a
#' reproduction workflow confirms that running the analysis did not alter the
#' inputs.
#'
#' This is an integrity helper, not an indicator. It emits no R4SUB evidence and
#' does not change the pass/fail or score of any indicator. When the manifest was
#' written into the folder being verified, that manifest file is excluded from
#' the comparison automatically so it is not reported as an addition.
#'
#' @param path Path to the submission's analysis code folder to verify.
#' @param manifest Either a manifest tibble from [repro_manifest()] (with at
#'   least `file` and `hash` columns) or a path to a manifest JSON file written
#'   by [repro_manifest()].
#' @param exclude Optional character vector of regular expressions matched
#'   against each current file's relative path; matching files are ignored, as in
#'   [repro_manifest()]. Use the same `exclude` here as when the manifest was
#'   captured.
#'
#' @return An object of class `repro_manifest_check`: a list with `files` (a
#'   [tibble][tibble::tibble] of `file`, `status`, `expected_hash`,
#'   `actual_hash`, one row per file across both the manifest and the folder,
#'   where `status` is `"unchanged"`, `"modified"`, `"added"`, or `"removed"`),
#'   the counts `n_total`, `n_unchanged`, `n_modified`, `n_added`, `n_removed`,
#'   and `ok` (`TRUE` when every manifested file is present and unchanged and
#'   nothing was added). It has a print method.
#'
#' @seealso [repro_manifest()] to capture a manifest.
#'
#' @examples
#' d <- file.path(tempdir(), "sub_verify")
#' dir.create(d, showWarnings = FALSE)
#' writeLines("source('a.R')", file.path(d, "run.R"))
#' writeLines("x <- 1", file.path(d, "a.R"))
#' mf <- repro_manifest(d)
#'
#' # Unchanged folder verifies clean
#' chk <- repro_manifest_verify(d, mf)
#' chk$ok
#'
#' # Modify a file and re-verify
#' writeLines("x <- 2", file.path(d, "a.R"))
#' repro_manifest_verify(d, mf)
#'
#' @export
repro_manifest_verify <- function(path, manifest, exclude = NULL) {
  assert_path(path)
  if (!is.null(exclude) && !is.character(exclude)) {
    cli::cli_abort("{.arg exclude} must be a character vector of patterns or NULL.")
  }

  expected <- manifest_expected(manifest)

  # Auto-exclude a manifest file that lives inside the verified folder.
  if (is.character(manifest) && length(manifest) == 1L && !is.na(manifest)) {
    inside <- manifest_rel_within(manifest, path)
    if (!is.na(inside)) exclude <- c(exclude, paste0("^\\Q", inside, "\\E$"))
  }

  current <- manifest_scan(path, exclude)

  exp_hash <- stats::setNames(expected$hash, expected$file)
  cur_hash <- stats::setNames(current$hash, current$file)
  all_files <- sort(unique(c(expected$file, current$file)))

  status <- vapply(all_files, function(f) {
    in_exp <- f %in% names(exp_hash)
    in_cur <- f %in% names(cur_hash)
    if (in_exp && in_cur) {
      if (identical(unname(exp_hash[[f]]), unname(cur_hash[[f]]))) "unchanged" else "modified"
    } else if (in_cur) {
      "added"
    } else {
      "removed"
    }
  }, character(1))

  files <- tibble::tibble(
    file          = all_files,
    status        = unname(status),
    expected_hash = unname(exp_hash[all_files]),
    actual_hash   = unname(cur_hash[all_files])
  )

  n_modified <- sum(status == "modified")
  n_added    <- sum(status == "added")
  n_removed  <- sum(status == "removed")

  structure(
    list(
      files       = files,
      n_total     = length(all_files),
      n_unchanged = sum(status == "unchanged"),
      n_modified  = n_modified,
      n_added     = n_added,
      n_removed   = n_removed,
      ok          = n_modified == 0L && n_added == 0L && n_removed == 0L,
      algo        = "md5"
    ),
    class = "repro_manifest_check"
  )
}

#' Print a File-Hash Manifest Verification
#'
#' @param x A `repro_manifest_check` object from [repro_manifest_verify()].
#' @param ... Ignored.
#'
#' @return Invisibly returns `x`. Called for the side effect of printing the
#'   file counts and any differences from the manifest.
#'
#' @export
print.repro_manifest_check <- function(x, ...) {
  cli::cli_h2("R4SUB File Manifest Verification")
  cli::cli_text("Files checked: {.val {x$n_total}}  |  Algorithm: {.val {x$algo}}")
  if (isTRUE(x$ok)) {
    cli::cli_alert_success(
      "All {x$n_unchanged} file{?s} match the manifest; nothing modified, added, or removed."
    )
  } else {
    cli::cli_alert_warning(
      "{x$n_unchanged} unchanged, {x$n_modified} modified, {x$n_added} added, {x$n_removed} removed."
    )
    diffs <- x$files[x$files$status != "unchanged", , drop = FALSE]
    for (i in seq_len(nrow(diffs))) {
      cli::cli_text("{.field {diffs$status[i]}}: {diffs$file[i]}")
    }
  }
  invisible(x)
}
