#!/usr/bin/env Rscript
`%||%` <- function(a, b) if (is.null(a)) b else a
# E3-M11: every version in renv.lock was published at least 14 days before
# the lock date. CRAN and Bioconductor packages come from the dated Posit
# Package Manager snapshots, so their age is the snapshot's age; GitHub
# packages are checked by the date of their pinned commit (needs network).
# Usage: check_package_ages.R [renv.lock] [lock date, YYYY-MM-DD]
# GitHub's API refuses anonymous callers on shared runners (HTTP 403, rate limit), so when GITHUB_TOKEN is set it is sent as an Authorization header
# (the workflow's own read-only token; never printed), and a failed lookup is tried up to 3 times with a short pause. Without the variable the
# lookup is anonymous, so local runs work as before. The rule itself (14 days) and the failure messages are unchanged.
age_headers <- function(token = Sys.getenv("GITHUB_TOKEN", "")) if (nzchar(token)) c(Authorization = paste("Bearer", token), Accept = "application/vnd.github+json") else character(0)
default_fetch <- function(u, headers = age_headers()) {
  con <- if (length(headers)) url(u, headers = headers) else url(u)
  on.exit(try(close(con), silent = TRUE)); jsonlite::fromJSON(con)   # fromJSON opens and closes the connection itself; the close here is only for a failed read
}
commit_date <- function(u, fetch = default_fetch, tries = 3L, pause = 5) {
  for (i in seq_len(tries)) {
    d <- tryCatch(as.Date(substr(fetch(u)$commit$committer$date, 1, 10)), error = function(e) NA)
    if (length(d) == 1 && !is.na(d)) return(d)
    if (i < tries) Sys.sleep(pause)
  }
  as.Date(NA)
}
# Returns list(fail = <messages>, n = <packages checked>, snap = <snapshot dates>, lines = <progress lines>).
check_ages <- function(lock, lock_date, fetch = default_fetch, pause = 5) {
  fail <- character(0); lines <- character(0)
  repos <- vapply(lock$R$Repositories, `[[`, "", "URL")
  snap <- as.Date(sub("^.*/([0-9]{4}-[0-9]{2}-[0-9]{2})(/.*)?$", "\\1", repos))
  if (anyNA(snap)) fail <- c(fail, sprintf("repository without a dated snapshot: %s", paste(repos[is.na(snap)], collapse = ", ")))
  if (any(lock_date - snap < 14, na.rm = TRUE)) fail <- c(fail, sprintf("a snapshot is less than 14 days older than the lock date: %s", paste(repos[lock_date - snap < 14], collapse = ", ")))
  n <- 0
  for (p in lock$Packages) {
    src <- p$Source %||% ""
    if (identical(src, "Repository")) { n <- n + 1; next }
    if (identical(src, "GitHub")) {
      u <- sprintf("https://api.github.com/repos/%s/%s/commits/%s", p$RemoteUsername, p$RemoteRepo, p$RemoteSha)
      d <- commit_date(u, fetch, pause = pause)
      if (is.na(d)) fail <- c(fail, sprintf("%s: could not read the date of commit %s", p$Package, p$RemoteSha))
      else if (lock_date - d < 14) fail <- c(fail, sprintf("%s: commit %s is from %s, less than 14 days before %s", p$Package, p$RemoteSha, d, lock_date))
      else lines <- c(lines, sprintf("%s %s: GitHub commit %s, %s (%d days before the lock)", p$Package, p$Version, substr(p$RemoteSha, 1, 7), d, as.integer(lock_date - d)))
      n <- n + 1; next
    }
    fail <- c(fail, sprintf("%s: source '%s' is neither a dated snapshot nor a pinned GitHub commit", p$Package, src))
  }
  list(fail = fail, n = n, snap = snap, lines = lines)
}

if (sys.nframe() == 0L) {   # run as a script (a test sources the functions above without running this)
  args <- commandArgs(trailingOnly = TRUE)
  lock_file <- if (length(args) >= 1) args[1] else "renv.lock"
  lock_date <- as.Date(if (length(args) >= 2) args[2] else "2026-10-29")   # the date renv.lock was made (CLAUDE.md D13)
  lock <- jsonlite::read_json(lock_file)
  r <- check_ages(lock, lock_date)
  if (length(r$lines)) cat(r$lines, sep = "\n")
  cat(sprintf("%d packages checked; snapshots dated %s; lock date %s.\n", r$n, paste(unique(r$snap), collapse = ", "), lock_date))
  if (length(r$fail)) { cat("FAILED:\n", paste0("  - ", r$fail, "\n"), sep = ""); quit(status = 1) }
  cat("Every version is at least 14 days old.\n")
}
