# Tests for repro_manifest() and repro_manifest_verify().

make_manifest_submission <- function() {
  d <- file.path(tempdir(), paste0("mf_", as.integer(runif(1, 1, 1e6))))
  dir.create(file.path(d, "data"), recursive = TRUE, showWarnings = FALSE)
  writeLines("source('a.R')", file.path(d, "run.R"))
  writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
  writeLines(c("usubjid,age", "01,55"), file.path(d, "data", "adsl.csv"))
  d
}

test_that("repro_manifest returns a tibble with one row per file", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  expect_s3_class(mf, "tbl_df")
  expect_identical(names(mf), c("file", "bytes", "algo", "hash"))
  expect_equal(nrow(mf), 3L)
  expect_setequal(mf$file, c("a.R", "data/adsl.csv", "run.R"))
  expect_true(all(mf$algo == "md5"))
  expect_type(mf$bytes, "double")
})

test_that("manifest hashes match tools::md5sum", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  direct <- unname(tools::md5sum(file.path(d, "run.R")))
  expect_equal(mf$hash[mf$file == "run.R"], direct)
})

test_that("exclude drops matching files", {
  d <- make_manifest_submission()
  writeLines("log", file.path(d, "run.log"))
  mf <- repro_manifest(d, exclude = "\\.log$")
  expect_false(any(grepl("\\.log$", mf$file)))
  expect_equal(nrow(mf), 3L)
})

test_that("writing a manifest produces valid JSON and returns the path invisibly", {
  d <- make_manifest_submission()
  f <- file.path(tempdir(), paste0("manifest_", as.integer(runif(1, 1, 1e6)), ".json"))
  out <- withVisible(suppressMessages(repro_manifest(d, file = f)))
  expect_false(out$visible)
  expect_identical(out$value, f)
  expect_true(file.exists(f))

  parsed <- jsonlite::fromJSON(paste(readLines(f), collapse = "\n"),
                               simplifyVector = FALSE)
  expect_equal(parsed$manifest_type, "r4subrepro file manifest")
  expect_true(nzchar(parsed$schema_version))
  expect_equal(parsed$algo, "md5")
  expect_equal(parsed$source$name, "r4subrepro")
  expect_equal(parsed$n_files, 3L)
  expect_length(parsed$files, 3L)
})

test_that("verify reports an unchanged folder as ok", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  chk <- repro_manifest_verify(d, mf)
  expect_s3_class(chk, "repro_manifest_check")
  expect_true(chk$ok)
  expect_equal(chk$n_unchanged, 3L)
  expect_equal(chk$n_modified + chk$n_added + chk$n_removed, 0L)
  expect_true(all(chk$files$status == "unchanged"))
})

test_that("verify detects a modified file", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  writeLines("x <- 2", file.path(d, "a.R"))
  chk <- repro_manifest_verify(d, mf)
  expect_false(chk$ok)
  expect_equal(chk$n_modified, 1L)
  expect_equal(chk$files$status[chk$files$file == "a.R"], "modified")
})

test_that("verify detects an added file", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  writeLines("extra", file.path(d, "extra.R"))
  chk <- repro_manifest_verify(d, mf)
  expect_false(chk$ok)
  expect_equal(chk$n_added, 1L)
  expect_equal(chk$files$status[chk$files$file == "extra.R"], "added")
})

test_that("verify detects a removed file", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  file.remove(file.path(d, "a.R"))
  chk <- repro_manifest_verify(d, mf)
  expect_false(chk$ok)
  expect_equal(chk$n_removed, 1L)
  expect_equal(chk$files$status[chk$files$file == "a.R"], "removed")
})

test_that("verify reads a JSON manifest and auto-excludes it from the folder", {
  d <- make_manifest_submission()
  f <- file.path(d, "manifest.json")
  suppressMessages(repro_manifest(d, file = f))
  # The manifest was written into the folder but must not count as an addition.
  chk <- repro_manifest_verify(d, f)
  expect_true(chk$ok)
  expect_false("manifest.json" %in% chk$files$file)
})

test_that("verify accepts a data frame manifest with file and hash columns", {
  d <- make_manifest_submission()
  mf <- as.data.frame(repro_manifest(d))
  chk <- repro_manifest_verify(d, mf[, c("file", "hash")])
  expect_true(chk$ok)
})

test_that("print returns the object invisibly", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  chk <- repro_manifest_verify(d, mf)
  out <- withVisible(print(chk))
  expect_false(out$visible)
  expect_identical(out$value, chk)
})

test_that("verify errors on an unusable manifest and manifest errors on a missing dir", {
  d <- make_manifest_submission()
  expect_error(repro_manifest_verify(d, 42))
  expect_error(repro_manifest_verify(d, data.frame(a = 1)), "file")
  expect_error(repro_manifest(file.path(tempdir(), "no_such_dir_abc")))
  expect_error(repro_manifest_verify(d, file.path(tempdir(), "no_such_manifest.json")),
               "not found")
})

test_that("verify reports unchanged, modified, added, and removed together", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)                         # a.R, data/adsl.csv, run.R
  writeLines("x <- 999", file.path(d, "a.R"))     # modify a.R
  file.remove(file.path(d, "run.R"))              # remove run.R
  writeLines("brand new", file.path(d, "new.R"))  # add new.R
  # data/adsl.csv is left untouched -> unchanged

  chk <- repro_manifest_verify(d, mf)
  expect_false(chk$ok)
  expect_equal(chk$n_total, 4L)
  expect_equal(chk$n_unchanged, 1L)
  expect_equal(chk$n_modified, 1L)
  expect_equal(chk$n_added, 1L)
  expect_equal(chk$n_removed, 1L)

  st <- stats::setNames(chk$files$status, chk$files$file)
  expect_equal(st[["a.R"]], "modified")
  expect_equal(st[["run.R"]], "removed")
  expect_equal(st[["new.R"]], "added")
  expect_equal(st[["data/adsl.csv"]], "unchanged")

  # A removed file keeps its expected hash but has no actual hash; an added file
  # is the reverse.
  expect_true(is.na(chk$files$actual_hash[chk$files$file == "run.R"]))
  expect_true(is.na(chk$files$expected_hash[chk$files$file == "new.R"]))
})

test_that("exclude accepts multiple patterns and drops every match", {
  d <- make_manifest_submission()
  writeLines("log", file.path(d, "run.log"))
  writeLines("tmp", file.path(d, "scratch.tmp"))
  mf <- repro_manifest(d, exclude = c("\\.log$", "\\.tmp$"))
  expect_false(any(grepl("\\.(log|tmp)$", mf$file)))
  expect_setequal(mf$file, c("a.R", "data/adsl.csv", "run.R"))
})

test_that("nested subdirectories use normalized forward-slash relative paths", {
  d <- make_manifest_submission()
  dir.create(file.path(d, "data", "raw", "y2024"), recursive = TRUE,
             showWarnings = FALSE)
  writeLines("deep", file.path(d, "data", "raw", "y2024", "x.csv"))
  mf <- repro_manifest(d)
  expect_true("data/raw/y2024/x.csv" %in% mf$file)
  expect_false(any(grepl("\\\\", mf$file)))  # no backslashes on any platform

  # The deeply nested path round-trips through verification unchanged.
  chk <- repro_manifest_verify(d, mf)
  expect_true(chk$ok)
  expect_equal(chk$files$status[chk$files$file == "data/raw/y2024/x.csv"],
               "unchanged")
})

test_that("verify exclude ignores an added file that matches the pattern", {
  d <- make_manifest_submission()
  mf <- repro_manifest(d)
  writeLines("log", file.path(d, "run.log"))
  # Without exclude the stray log counts as an addition and ok is FALSE...
  expect_false(repro_manifest_verify(d, mf)$ok)
  # ...with the same exclude used at capture time it is ignored and ok is TRUE.
  chk <- repro_manifest_verify(d, mf, exclude = "\\.log$")
  expect_true(chk$ok)
  expect_false("run.log" %in% chk$files$file)
})

test_that("a same-size content change is caught by the hash, not the size", {
  d <- file.path(tempdir(), paste0("mf_sz_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("AB", file.path(d, "f.txt"))
  mf <- repro_manifest(d)
  size_before <- mf$bytes[mf$file == "f.txt"]

  writeLines("BA", file.path(d, "f.txt"))  # same byte length, different content
  mf2 <- repro_manifest(d)
  expect_equal(mf2$bytes[mf2$file == "f.txt"], size_before)   # size is identical
  expect_false(identical(mf$hash[1], mf2$hash[1]))            # but the hash moved

  chk <- repro_manifest_verify(d, mf)
  expect_false(chk$ok)
  expect_equal(chk$n_modified, 1L)
  expect_equal(chk$files$status[chk$files$file == "f.txt"], "modified")
})

test_that("JSON manifests round-trip NA/null hashes without error", {
  d <- make_manifest_submission()
  f <- file.path(tempdir(), paste0("mf_na_", as.integer(runif(1, 1, 1e6)), ".json"))
  # Hand-build a manifest document the way repro_manifest() writes it, with one
  # file carrying an NA hash so the null round-trip is exercised end to end.
  doc <- list(
    manifest_type  = "r4subrepro file manifest",
    schema_version = "1",
    algo           = "md5",
    files = list(
      list(file = "a.R",   bytes = 10, hash = NA),
      list(file = "run.R", bytes = 13, hash = "deadbeef")
    )
  )
  json <- jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE,
                           null = "null", na = "null")
  writeLines(as.character(json), f)

  chk <- repro_manifest_verify(d, f)
  expect_s3_class(chk, "repro_manifest_check")
  # The null hash survives the round-trip as NA and does not error out.
  expect_true(is.na(chk$files$expected_hash[chk$files$file == "a.R"]))
  # NA expected vs. a real on-disk hash is a mismatch -> modified.
  expect_equal(chk$files$status[chk$files$file == "a.R"], "modified")
  # The stub hash never matches the real file -> modified.
  expect_equal(chk$files$status[chk$files$file == "run.R"], "modified")
  # A folder file absent from the manifest -> added.
  expect_equal(chk$files$status[chk$files$file == "data/adsl.csv"], "added")
})

test_that("auto-exclude of an in-folder manifest fires for the JSON-path form only", {
  d <- make_manifest_submission()
  f <- file.path(d, "manifest.json")
  suppressMessages(repro_manifest(d, file = f))

  # JSON-path form: the manifest written into the folder is auto-excluded, so the
  # folder verifies clean and the manifest file is not reported.
  chk_path <- repro_manifest_verify(d, f)
  expect_true(chk_path$ok)
  expect_false("manifest.json" %in% chk_path$files$file)

  # data.frame form: the same on-disk manifest.json is still in the folder, but a
  # data-frame manifest carries no auto-exclude. Capturing the data frame while
  # skipping the json keeps the three real files, and verification then reports
  # the still-present manifest.json as an addition. This pins the documented gap:
  # auto-exclude only applies to the JSON-path form, not the data.frame form.
  df <- as.data.frame(repro_manifest(d, exclude = "^manifest\\.json$"))
  chk_df <- repro_manifest_verify(d, df[, c("file", "hash")])
  expect_false(chk_df$ok)
  expect_true("manifest.json" %in% chk_df$files$file)
  expect_equal(chk_df$files$status[chk_df$files$file == "manifest.json"], "added")
})

test_that("a manifest JSON outside the verified folder is not auto-excluded by path", {
  d <- make_manifest_submission()
  f <- file.path(tempdir(), paste0("outside_", as.integer(runif(1, 1, 1e6)), ".json"))
  suppressMessages(repro_manifest(d, file = f))
  # The manifest lives outside the folder, so nothing in the folder matches the
  # auto-exclude path and the three real files still verify clean.
  chk <- repro_manifest_verify(d, f)
  expect_true(chk$ok)
  expect_equal(chk$n_unchanged, 3L)
})
