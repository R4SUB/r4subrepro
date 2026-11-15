# Computational environment capture and comparison. A snapshot records the
# software environment of the running R session (R version, platform, OS,
# locale, and the attached/loaded packages with their versions) into a
# structured, serializable object; the comparator diffs two snapshots. This
# complements the file-hash manifest (repro_manifest()), which tracks the data
# and output files, by tracking the software that produced them.
#
# This is a descriptive/integrity layer: it emits no R4SUB evidence and does not
# change any indicator logic, threshold, weight, or score. Everything is read
# from the running session or from caller-supplied snapshots; nothing is
# invented. Capture is robust when optional sessionInfo() fields are absent.

# Internal: a single character scalar from a possibly NULL/empty/multi value.
# Collapses a vector (such as sessionInfo()$locale) with "; " and returns NA for
# an absent value, so the snapshot always has a well-formed scalar field.
env_scalar_chr <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  x <- as.character(x)
  x <- x[!is.na(x)]
  if (!length(x)) return(NA_character_)
  paste(x, collapse = "; ")
}

# Internal: NA_character_ for a NULL/NA value, otherwise the value as a string.
env_nullable_chr <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  x <- x[[1L]]
  if (is.na(x)) NA_character_ else as.character(x)
}

# Internal: the R version string from a sessionInfo()-like object, trying the
# structured R.version$version.string first and the flat R.version.string next.
env_r_version <- function(si) {
  rv <- si[["R.version"]]
  if (!is.null(rv) && !is.null(rv$version.string)) {
    return(env_scalar_chr(rv$version.string))
  }
  env_scalar_chr(si[["R.version.string"]])
}

# Internal: a data.frame of package, version, attached from a sessionInfo()-like
# object. otherPkgs are the attached non-base packages and loadedOnly the
# loaded-but-not-attached ones; each element carries a Version field. Robust to
# either list being absent (NULL). Base packages are intentionally omitted:
# sessionInfo() records no version for them and they track the R version.
env_packages_from_sessioninfo <- function(si) {
  rows <- list()
  collect <- function(lst, attached) {
    if (is.null(lst) || !length(lst)) return(invisible(NULL))
    nms <- names(lst)
    for (i in seq_along(lst)) {
      el  <- lst[[i]]
      nm  <- if (!is.null(el$Package)) as.character(el$Package) else nms[i]
      ver <- if (!is.null(el$Version)) as.character(el$Version) else NA_character_
      if (is.null(nm) || is.na(nm) || !nzchar(nm)) next
      rows[[length(rows) + 1L]] <<- data.frame(
        package = nm, version = ver, attached = attached,
        stringsAsFactors = FALSE)
    }
  }
  collect(si[["otherPkgs"]], TRUE)
  collect(si[["loadedOnly"]], FALSE)
  if (!length(rows)) {
    return(data.frame(package = character(0), version = character(0),
                      attached = logical(0), stringsAsFactors = FALSE))
  }
  df <- do.call(rbind, rows)
  # A package can appear both attached and loaded only once; keep the attached
  # record. Then order by name for a deterministic, diffable snapshot.
  df <- df[!duplicated(df$package) | df$attached, , drop = FALSE]
  df <- df[!duplicated(df$package), , drop = FALSE]
  df[order(df$package), , drop = FALSE]
}

# Internal: assemble a repro_environment object from its parts.
new_repro_environment <- function(r_version, platform, os, locale, packages,
                                  captured) {
  pkgs <- tibble::tibble(
    package  = as.character(packages$package),
    version  = as.character(packages$version),
    attached = as.logical(packages$attached)
  )
  structure(
    list(
      r_version  = r_version,
      platform   = platform,
      os         = os,
      locale     = locale,
      packages   = pkgs,
      n_packages = nrow(pkgs),
      n_attached = sum(pkgs$attached, na.rm = TRUE),
      captured   = captured
    ),
    class = "repro_environment"
  )
}

# Internal: read an environment snapshot JSON file into a repro_environment.
environment_read_json <- function(file) {
  doc <- tryCatch(
    jsonlite::fromJSON(paste(read_lines_safe(file), collapse = "\n"),
                       simplifyVector = FALSE),
    error = function(e) NULL)
  if (is.null(doc) || is.null(doc$env_type)) {
    cli::cli_abort("{.arg x} is not a readable r4subrepro environment snapshot: {.path {file}}")
  }
  pkgs <- doc$packages
  if (is.null(pkgs) || !length(pkgs)) {
    ptbl <- data.frame(package = character(0), version = character(0),
                       attached = logical(0), stringsAsFactors = FALSE)
  } else {
    ptbl <- data.frame(
      package = vapply(pkgs, function(p) as.character(p$package), character(1)),
      version = vapply(pkgs, function(p) {
        v <- p$version
        if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
      }, character(1)),
      attached = vapply(pkgs, function(p) {
        a <- p$attached
        if (is.null(a) || is.na(a)) NA else isTRUE(a)
      }, logical(1)),
      stringsAsFactors = FALSE)
  }
  new_repro_environment(
    r_version = env_nullable_chr(doc$r_version),
    platform  = env_nullable_chr(doc$platform),
    os        = env_nullable_chr(doc$os),
    locale    = env_nullable_chr(doc$locale),
    packages  = ptbl,
    captured  = env_nullable_chr(doc$captured)
  )
}

# Internal: coerce the comparator argument to a repro_environment (pass an
# object through, or read a snapshot JSON path).
as_repro_environment <- function(x, arg = "x") {
  if (inherits(x, "repro_environment")) return(x)
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    if (!file.exists(x)) {
      cli::cli_abort("Environment snapshot file not found: {.path {x}}")
    }
    return(environment_read_json(x))
  }
  cli::cli_abort(paste0(
    "{.arg {arg}} must be a {.cls repro_environment} from {.fn capture_environment} ",
    "or a path to a snapshot JSON file."
  ))
}

#' Capture the Computational Environment of a Session
#'
#' Records the software environment of the running R session into a structured,
#' serializable snapshot: the R version, the platform and operating system, the
#' locale, and the attached and loaded packages with their versions. A
#' submission is only reproducible if a reviewer can recreate the environment
#' that produced it, so capturing that environment alongside the data and
#' outputs is a core reproducibility concern. This complements
#' [repro_manifest()], which hashes the data and output *files*, by recording
#' the *software* that produced them.
#'
#' The snapshot is read entirely from [utils::sessionInfo()]: the attached
#' non-base packages (`otherPkgs`) and the loaded-but-not-attached packages
#' (`loadedOnly`), each with the version `sessionInfo()` reports. Base packages
#' are omitted because `sessionInfo()` records no version for them and they
#' track the R version. Capture is robust when optional fields are absent.
#'
#' This is a descriptive/integrity helper, not an indicator. It emits no R4SUB
#' evidence, carries no severity, and does not change the pass/fail or score of
#' any indicator. Compare two snapshots with [compare_environments()].
#'
#' @param info A [utils::sessionInfo()]-like object to capture from. When `NULL`
#'   (the default), the running session is captured with `utils::sessionInfo()`.
#'   Supplying `info` makes capture testable with a synthetic session.
#' @param file Optional path to write the snapshot to as JSON. When supplied, the
#'   snapshot is written there and the path is returned invisibly; otherwise the
#'   `repro_environment` object is returned.
#'
#' @return An object of class `repro_environment`: a list with `r_version`,
#'   `platform`, `os`, `locale`, a `packages` [tibble][tibble::tibble] (columns
#'   `package`, `version`, `attached`), the counts `n_packages` and `n_attached`,
#'   and `captured` (the capture time). When `file` is supplied, the path to the
#'   written JSON snapshot is returned invisibly instead. The JSON document
#'   carries an `env_type`, a `schema_version`, the capture time, the source
#'   package and version, the R version, platform, OS, locale, the package
#'   count, and a `packages` array. It has a print method.
#'
#' @seealso [compare_environments()] to diff two snapshots, and [repro_manifest()]
#'   for the companion file-hash manifest.
#'
#' @examples
#' # Capture the current session
#' env <- capture_environment()
#' env$r_version
#' env$packages
#'
#' # Write a portable JSON snapshot
#' f <- capture_environment(file = file.path(tempdir(), "env.json"))
#' file.exists(f)
#'
#' @export
capture_environment <- function(info = NULL, file = NULL) {
  si <- if (is.null(info)) utils::sessionInfo() else info
  if (!is.list(si)) {
    cli::cli_abort("{.arg info} must be a {.fn utils::sessionInfo}-like list or NULL.")
  }

  env <- new_repro_environment(
    r_version = env_r_version(si),
    platform  = env_scalar_chr(si[["platform"]]),
    os        = env_scalar_chr(si[["running"]]),
    locale    = env_scalar_chr(si[["locale"]]),
    packages  = env_packages_from_sessioninfo(si),
    captured  = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )

  if (is.null(file)) return(env)

  if (!is.character(file) || length(file) != 1L || is.na(file)) {
    cli::cli_abort("{.arg file} must be a single file path.")
  }
  pk <- env$packages
  files <- lapply(seq_len(nrow(pk)), function(i) {
    list(package = pk$package[i], version = pk$version[i],
         attached = isTRUE(pk$attached[i]))
  })
  doc <- list(
    env_type       = "r4subrepro environment snapshot",
    schema_version = "1",
    captured       = env$captured,
    source         = list(name = "r4subrepro", version = repro_source_version()),
    r_version      = env$r_version,
    platform       = env$platform,
    os             = env$os,
    locale         = env$locale,
    n_packages     = env$n_packages,
    packages       = files
  )
  json <- jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null",
                           na = "null")
  writeLines(as.character(json), file)
  cli::cli_alert_success(
    "Wrote environment snapshot ({env$n_packages} package{?s}) to {.path {file}}")
  invisible(file)
}

#' Compare Two Computational Environment Snapshots
#'
#' Diffs two environment snapshots from [capture_environment()] and reports what
#' changed between them: whether the R version, platform, operating system, or
#' locale differ, and which packages were added, removed, or changed version.
#' This is how a reviewer, or the sponsor before submission, checks that a
#' reproduction environment matches the one that produced the submitted results,
#' and pinpoints the exact software differences when results diverge.
#'
#' The comparison is directional: `x` is the baseline (for example the recorded
#' submission environment) and `y` is the comparison (for example the reviewer's
#' reproduction environment). A package present in `y` but not `x` is `"added"`;
#' one present in `x` but not `y` is `"removed"`; one present in both with a
#' different version is `"version_changed"`.
#'
#' This is a descriptive/integrity helper, not an indicator. It emits no R4SUB
#' evidence and does not change the pass/fail or score of any indicator. It
#' reports the differences mechanically and applies no threshold or judgement
#' about whether a given change matters.
#'
#' @param x,y Two environments to compare, each either a `repro_environment`
#'   object from [capture_environment()] or a path to a snapshot JSON file
#'   written by it. `x` is the baseline and `y` the comparison.
#' @param labels Optional character vector of two short names for `x` and `y`
#'   used in the printed output and the version columns. Defaults to
#'   `c("x", "y")`.
#'
#' @return An object of class `repro_environment_diff`: a list with
#'   `r_version_changed`, `platform_changed`, `os_changed`, and `locale_changed`
#'   (logical flags), each accompanied by `*_x` and `*_y` values; a `packages`
#'   [tibble][tibble::tibble] with one row per package across both snapshots
#'   (columns `package`, `status` - one of `"unchanged"`, `"added"`,
#'   `"removed"`, `"version_changed"` - `version_x`, and `version_y`); the counts
#'   `n_unchanged`, `n_added`, `n_removed`, `n_changed`; `labels`; and
#'   `identical` (`TRUE` when the R version and every package match, regardless
#'   of platform, OS, or locale). It has a print method.
#'
#' @seealso [capture_environment()] to capture a snapshot.
#'
#' @examples
#' # Two synthetic snapshots (a reproducer would pass real captures)
#' si1 <- list(
#'   R.version = list(version.string = "R version 4.4.1 (2024-06-14)"),
#'   platform  = "x86_64-w64-mingw32/x64",
#'   otherPkgs = list(dplyr = list(Package = "dplyr", Version = "1.1.4")))
#' si2 <- list(
#'   R.version = list(version.string = "R version 4.5.1 (2025-06-13)"),
#'   platform  = "x86_64-w64-mingw32/x64",
#'   otherPkgs = list(dplyr = list(Package = "dplyr", Version = "1.1.5")))
#' d <- compare_environments(capture_environment(si1), capture_environment(si2))
#' d$r_version_changed
#' d$packages
#'
#' @export
compare_environments <- function(x, y, labels = c("x", "y")) {
  ex <- as_repro_environment(x, "x")
  ey <- as_repro_environment(y, "y")
  if (!is.character(labels) || length(labels) != 2L || any(is.na(labels))) {
    cli::cli_abort("{.arg labels} must be a character vector of two names.")
  }

  px <- stats::setNames(ex$packages$version, ex$packages$package)
  py <- stats::setNames(ey$packages$version, ey$packages$package)
  all_pkgs <- sort(unique(c(names(px), names(py))))

  status <- vapply(all_pkgs, function(p) {
    in_x <- p %in% names(px)
    in_y <- p %in% names(py)
    if (in_x && in_y) {
      if (identical(unname(px[[p]]), unname(py[[p]]))) "unchanged" else "version_changed"
    } else if (in_y) {
      "added"
    } else {
      "removed"
    }
  }, character(1))

  packages <- tibble::tibble(
    package   = all_pkgs,
    status    = unname(status),
    version_x = unname(px[all_pkgs]),
    version_y = unname(py[all_pkgs])
  )

  r_version_changed <- !identical(ex$r_version, ey$r_version)

  structure(
    list(
      r_version_changed = r_version_changed,
      r_version_x       = ex$r_version,
      r_version_y       = ey$r_version,
      platform_changed  = !identical(ex$platform, ey$platform),
      platform_x        = ex$platform,
      platform_y        = ey$platform,
      os_changed        = !identical(ex$os, ey$os),
      os_x              = ex$os,
      os_y              = ey$os,
      locale_changed    = !identical(ex$locale, ey$locale),
      locale_x          = ex$locale,
      locale_y          = ey$locale,
      packages          = packages,
      n_unchanged       = sum(status == "unchanged"),
      n_added           = sum(status == "added"),
      n_removed         = sum(status == "removed"),
      n_changed         = sum(status == "version_changed"),
      labels            = labels,
      identical         = !r_version_changed && all(status == "unchanged")
    ),
    class = "repro_environment_diff"
  )
}

#' Print a Computational Environment Snapshot
#'
#' @param x A `repro_environment` object from [capture_environment()].
#' @param ... Ignored.
#'
#' @return Invisibly returns `x`. Called for the side effect of printing the R
#'   version, platform, OS, locale, and package count.
#'
#' @export
print.repro_environment <- function(x, ...) {
  cli::cli_h2("R4SUB Environment Snapshot")
  cli::cli_text("R version: {.val {x$r_version}}")
  if (!is.na(x$platform)) cli::cli_text("Platform: {.val {x$platform}}")
  if (!is.na(x$os))       cli::cli_text("OS: {.val {x$os}}")
  if (!is.na(x$locale))   cli::cli_text("Locale: {.val {x$locale}}")
  cli::cli_text(
    "Packages: {.val {x$n_packages}} ({x$n_attached} attached, {x$n_packages - x$n_attached} loaded)")
  invisible(x)
}

#' Print a Computational Environment Comparison
#'
#' @param x A `repro_environment_diff` object from [compare_environments()].
#' @param ... Ignored.
#'
#' @return Invisibly returns `x`. Called for the side effect of printing the
#'   environment differences.
#'
#' @export
print.repro_environment_diff <- function(x, ...) {
  lab <- x$labels
  cli::cli_h2("R4SUB Environment Comparison")
  if (x$r_version_changed) {
    cli::cli_alert_warning(
      "R version differs: {lab[1]} {.val {x$r_version_x}} vs {lab[2]} {.val {x$r_version_y}}")
  } else {
    cli::cli_alert_success("R version matches: {.val {x$r_version_x}}")
  }
  if (x$platform_changed) {
    cli::cli_text("Platform differs: {lab[1]} {.val {x$platform_x}} vs {lab[2]} {.val {x$platform_y}}")
  }
  if (x$os_changed) {
    cli::cli_text("OS differs: {lab[1]} {.val {x$os_x}} vs {lab[2]} {.val {x$os_y}}")
  }
  if (x$locale_changed) {
    cli::cli_text("Locale differs between {lab[1]} and {lab[2]}")
  }

  if (x$n_added + x$n_removed + x$n_changed == 0L) {
    cli::cli_alert_success(
      "All {x$n_unchanged} package{?s} match in name and version.")
  } else {
    cli::cli_alert_warning(
      "{x$n_unchanged} unchanged, {x$n_added} added, {x$n_removed} removed, {x$n_changed} version-changed.")
    diffs <- x$packages[x$packages$status != "unchanged", , drop = FALSE]
    for (i in seq_len(nrow(diffs))) {
      vx <- if (is.na(diffs$version_x[i])) "-" else diffs$version_x[i]
      vy <- if (is.na(diffs$version_y[i])) "-" else diffs$version_y[i]
      cli::cli_text("{.field {diffs$status[i]}}: {diffs$package[i]} ({lab[1]} {vx} -> {lab[2]} {vy})")
    }
  }
  invisible(x)
}
