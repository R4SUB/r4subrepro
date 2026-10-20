# Tests for assess_windows_reviewability() (R-REPRO-011)

test_that("passes portable code with no Windows-breaking constructs", {
  d <- file.path(tempdir(), paste0("win_good_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("library(dplyr)",
               "x <- read.csv(file.path('data', 'adsl.csv'))",
               "y <- filter(x, mpg > 20)"),
             file.path(d, "a.R"))
  e <- suppressMessages(assess_windows_reviewability(d))
  expect_equal(e$result, "pass")
  expect_equal(e$indicator_id, "R-REPRO-011")
  expect_equal(e$metric_value, 0)
})

test_that("flags a shell-out via system()", {
  d <- file.path(tempdir(), paste0("win_sys_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("system('grep foo data.txt')"), file.path(d, "a.R"))
  e <- suppressMessages(assess_windows_reviewability(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
  expect_gte(e$metric_value, 1)
})

test_that("flags forking (mclapply) and POSIX paths", {
  d <- file.path(tempdir(), paste0("win_fork_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("res <- parallel::mclapply(1:4, sqrt)",
               "writeLines('x', '/tmp/out.txt')",
               "con <- file('/dev/null')"),
             file.path(d, "a.R"))
  e <- suppressMessages(assess_windows_reviewability(d))
  expect_equal(e$result, "warn")
  expect_gte(e$metric_value, 3)
})

test_that("does not flag commented-out constructs", {
  d <- file.path(tempdir(), paste0("win_comment_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("# system('rm -rf /tmp/x') is only in a comment",
               "x <- 1"),
             file.path(d, "a.R"))
  e <- suppressMessages(assess_windows_reviewability(d))
  expect_equal(e$result, "pass")
})

test_that("windows reviewability is part of the full assessment", {
  d <- file.path(tempdir(), paste0("win_full_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- 1", file.path(d, "a.R"))
  ev <- suppressMessages(assess_reproducibility(d))
  expect_true("R-REPRO-011" %in% ev$indicator_id)
})
