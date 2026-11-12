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
