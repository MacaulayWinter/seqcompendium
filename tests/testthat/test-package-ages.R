# E3-M11 age check (inst/scripts/check_package_ages.R): the authenticated, retrying lookup, and that the rule still fails when a commit is too recent.
ages_env <- function() {
  f <- system.file("scripts", "check_package_ages.R", package = "seqcompendium")
  if (!nzchar(f)) f <- file.path("..", "..", "inst", "scripts", "check_package_ages.R")
  e <- new.env(); sys.source(f, envir = e); e
}
fake_lock <- function(sha = "abc1234567") list(
  R = list(Repositories = list(list(Name = "CRAN", URL = "https://packagemanager.posit.co/cran/2026-10-14"))),
  Packages = list(Pkg = list(Package = "Pkg", Version = "1.0", Source = "GitHub", RemoteUsername = "u", RemoteRepo = "r", RemoteSha = sha)))
reply <- function(date) list(commit = list(committer = list(date = paste0(date, "T12:00:00Z"))))

test_that("the Authorization header is sent only when the token is set", {
  e <- ages_env()
  expect_length(e$age_headers(""), 0)
  h <- e$age_headers("tok123")
  expect_equal(unname(h["Authorization"]), "Bearer tok123")
})

test_that("a failed lookup is retried up to 3 times, then succeeds or gives NA", {
  e <- ages_env(); calls <- 0
  flaky <- function(u) { calls <<- calls + 1; if (calls < 3) stop("HTTP 403") else reply("2026-06-16") }
  expect_equal(e$commit_date("u", fetch = flaky, pause = 0), as.Date("2026-06-16")); expect_equal(calls, 3)
  calls <- 0; never <- function(u) { calls <<- calls + 1; stop("HTTP 403") }
  expect_true(is.na(e$commit_date("u", fetch = never, pause = 0))); expect_equal(calls, 3)
})

test_that("the rule is unchanged: old enough passes; too recent fails with the same message; an unreadable date fails", {
  e <- ages_env(); ld <- as.Date("2026-10-29")
  ok <- e$check_ages(fake_lock(), ld, fetch = function(u) reply("2026-06-16"), pause = 0)
  expect_length(ok$fail, 0); expect_match(ok$lines, "135 days before the lock")
  recent <- e$check_ages(fake_lock(), ld, fetch = function(u) reply("2026-10-20"), pause = 0)
  expect_length(recent$fail, 1); expect_match(recent$fail, "commit abc1234567 is from 2026-10-20, less than 14 days before 2026-10-29")
  edge <- e$check_ages(fake_lock(), ld, fetch = function(u) reply("2026-10-15"), pause = 0)   # exactly 14 days: allowed
  expect_length(edge$fail, 0)
  gone <- e$check_ages(fake_lock(), ld, fetch = function(u) stop("HTTP 403"), pause = 0)
  expect_match(gone$fail, "Pkg: could not read the date of commit abc1234567")
})
