# Tests for capture_environment() and compare_environments(). All inputs are
# synthetic sessionInfo()-like lists so the tests are deterministic and never
# assert on machine-specific values.

fake_si <- function(r = "R version 4.4.1 (2024-06-14)",
                    platform = "x86_64-w64-mingw32/x64",
                    running = "Windows 11 x64 (build 22631)",
                    locale = "LC_COLLATE=English_United States.utf8",
                    other = list(dplyr = list(Package = "dplyr", Version = "1.1.4"),
                                 ggplot2 = list(Package = "ggplot2", Version = "3.5.1")),
                    loaded = list(rlang = list(Package = "rlang", Version = "1.1.4"))) {
  list(
    R.version  = list(version.string = r),
    platform   = platform,
    running    = running,
    locale     = locale,
    otherPkgs  = other,
    loadedOnly = loaded
  )
}

test_that("capture_environment builds a structured snapshot from a session", {
  env <- capture_environment(fake_si())
  expect_s3_class(env, "repro_environment")
  expect_equal(env$r_version, "R version 4.4.1 (2024-06-14)")
  expect_equal(env$platform, "x86_64-w64-mingw32/x64")
  expect_equal(env$os, "Windows 11 x64 (build 22631)")
  expect_s3_class(env$packages, "tbl_df")
  expect_identical(names(env$packages), c("package", "version", "attached"))
  expect_equal(env$n_packages, 3L)
  expect_equal(env$n_attached, 2L)
  # Packages are ordered by name for a deterministic, diffable snapshot.
  expect_identical(env$packages$package, c("dplyr", "ggplot2", "rlang"))
  expect_true(all(env$packages$attached[env$packages$package %in% c("dplyr", "ggplot2")]))
  expect_false(env$packages$attached[env$packages$package == "rlang"])
})

test_that("capture_environment defaults to the live session without error", {
  env <- capture_environment()
  expect_s3_class(env, "repro_environment")
  expect_true(is.character(env$r_version) && nzchar(env$r_version))
  expect_true(all(c("package", "version", "attached") %in% names(env$packages)))
})

test_that("capture_environment is robust to absent optional fields", {
  minimal <- list(R.version = list(version.string = "R version 4.3.0 (2023-04-21)"))
  env <- capture_environment(minimal)
  expect_equal(env$r_version, "R version 4.3.0 (2023-04-21)")
  expect_true(is.na(env$platform))
  expect_true(is.na(env$os))
  expect_true(is.na(env$locale))
  expect_equal(env$n_packages, 0L)
  expect_equal(nrow(env$packages), 0L)
})

test_that("capture_environment falls back to R.version.string", {
  env <- capture_environment(list(R.version.string = "R version 4.2.2 (2022-10-31)"))
  expect_equal(env$r_version, "R version 4.2.2 (2022-10-31)")
})

test_that("capture_environment collapses a multi-element locale", {
  env <- capture_environment(fake_si(locale = c("LC_COLLATE=C", "LC_TIME=C")))
  expect_equal(env$r_version, "R version 4.4.1 (2024-06-14)")
  expect_equal(env$locale, "LC_COLLATE=C; LC_TIME=C")
})

test_that("capture_environment errors on a non-list info", {
  expect_error(capture_environment(42), "list")
})

test_that("writing a snapshot produces valid JSON and returns the path invisibly", {
  f <- file.path(tempdir(), paste0("env_", as.integer(runif(1, 1, 1e6)), ".json"))
  out <- withVisible(suppressMessages(capture_environment(fake_si(), file = f)))
  expect_false(out$visible)
  expect_identical(out$value, f)
  expect_true(file.exists(f))

  parsed <- jsonlite::fromJSON(paste(readLines(f), collapse = "\n"),
                               simplifyVector = FALSE)
  expect_equal(parsed$env_type, "r4subrepro environment snapshot")
  expect_true(nzchar(parsed$schema_version))
  expect_equal(parsed$source$name, "r4subrepro")
  expect_equal(parsed$r_version, "R version 4.4.1 (2024-06-14)")
  expect_equal(parsed$n_packages, 3L)
  expect_length(parsed$packages, 3L)
})

test_that("a written snapshot round-trips through compare_environments by path", {
  f <- file.path(tempdir(), paste0("env_rt_", as.integer(runif(1, 1, 1e6)), ".json"))
  suppressMessages(capture_environment(fake_si(), file = f))
  env <- capture_environment(fake_si())
  d <- compare_environments(f, env)
  expect_true(d$identical)
  expect_equal(d$n_unchanged, 3L)
})

test_that("compare_environments detects an R version change", {
  a <- capture_environment(fake_si(r = "R version 4.4.1 (2024-06-14)"))
  b <- capture_environment(fake_si(r = "R version 4.5.1 (2025-06-13)"))
  d <- compare_environments(a, b)
  expect_s3_class(d, "repro_environment_diff")
  expect_true(d$r_version_changed)
  expect_false(d$identical)
  expect_equal(d$r_version_x, "R version 4.4.1 (2024-06-14)")
  expect_equal(d$r_version_y, "R version 4.5.1 (2025-06-13)")
})

test_that("compare_environments identifies added, removed, and changed packages", {
  a <- capture_environment(fake_si(
    other = list(dplyr = list(Package = "dplyr", Version = "1.1.4"),
                 tidyr = list(Package = "tidyr", Version = "1.3.0")),
    loaded = NULL))
  b <- capture_environment(fake_si(
    other = list(dplyr = list(Package = "dplyr", Version = "1.1.5"),
                 ggplot2 = list(Package = "ggplot2", Version = "3.5.1")),
    loaded = NULL))
  d <- compare_environments(a, b)

  st <- stats::setNames(d$packages$status, d$packages$package)
  expect_equal(st[["dplyr"]], "version_changed")   # 1.1.4 -> 1.1.5
  expect_equal(st[["tidyr"]], "removed")            # in a, not in b
  expect_equal(st[["ggplot2"]], "added")            # in b, not in a
  expect_equal(d$n_changed, 1L)
  expect_equal(d$n_removed, 1L)
  expect_equal(d$n_added, 1L)
  expect_equal(d$n_unchanged, 0L)
  expect_false(d$identical)

  # Version columns carry the versions on each side; NA where absent.
  row <- d$packages[d$packages$package == "ggplot2", ]
  expect_true(is.na(row$version_x))
  expect_equal(row$version_y, "3.5.1")
  row2 <- d$packages[d$packages$package == "tidyr", ]
  expect_equal(row2$version_x, "1.3.0")
  expect_true(is.na(row2$version_y))
})

test_that("identical environments compare as identical", {
  a <- capture_environment(fake_si())
  b <- capture_environment(fake_si())
  d <- compare_environments(a, b)
  expect_true(d$identical)
  expect_false(d$r_version_changed)
  expect_equal(d$n_added + d$n_removed + d$n_changed, 0L)
  expect_true(all(d$packages$status == "unchanged"))
})

test_that("identical is TRUE for matching R version and packages despite platform drift", {
  a <- capture_environment(fake_si(platform = "x86_64-w64-mingw32/x64",
                                   running = "Windows 11 x64"))
  b <- capture_environment(fake_si(platform = "x86_64-pc-linux-gnu",
                                   running = "Ubuntu 22.04 LTS"))
  d <- compare_environments(a, b)
  expect_true(d$platform_changed)
  expect_true(d$os_changed)
  # identical is defined over R version and packages only.
  expect_true(d$identical)
})

test_that("compare_environments accepts custom labels", {
  a <- capture_environment(fake_si())
  b <- capture_environment(fake_si(r = "R version 4.5.1 (2025-06-13)"))
  d <- compare_environments(a, b, labels = c("recorded", "reproduced"))
  expect_identical(d$labels, c("recorded", "reproduced"))
  expect_error(compare_environments(a, b, labels = "only-one"), "two names")
})

test_that("compare_environments errors on an unusable argument", {
  a <- capture_environment(fake_si())
  expect_error(compare_environments(a, 42), "repro_environment")
  expect_error(compare_environments(a, file.path(tempdir(), "no_such_env.json")),
               "not found")
})

test_that("reading a non-snapshot JSON file errors clearly", {
  f <- file.path(tempdir(), paste0("notenv_", as.integer(runif(1, 1, 1e6)), ".json"))
  writeLines('{ "something": "else" }', f)
  a <- capture_environment(fake_si())
  expect_error(compare_environments(a, f), "environment snapshot")
})

test_that("print methods return their object invisibly", {
  env <- capture_environment(fake_si())
  out1 <- withVisible(print(env))
  expect_false(out1$visible)
  expect_identical(out1$value, env)

  d <- compare_environments(env, capture_environment(fake_si(r = "R version 4.5.1 (2025-06-13)")))
  out2 <- withVisible(print(d))
  expect_false(out2$visible)
  expect_identical(out2$value, d)
})

test_that("a package attached in one session and loaded in another is matched by name", {
  a <- capture_environment(fake_si(
    other = list(rlang = list(Package = "rlang", Version = "1.1.4")),
    loaded = NULL))
  b <- capture_environment(fake_si(
    other = NULL,
    loaded = list(rlang = list(Package = "rlang", Version = "1.1.4"))))
  d <- compare_environments(a, b)
  # Same name and version, regardless of attached vs loaded -> unchanged.
  expect_equal(d$packages$status[d$packages$package == "rlang"], "unchanged")
})
