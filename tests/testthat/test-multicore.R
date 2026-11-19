# V-E10b (validation/PREREGISTRATION.md section 10): the multi-core override check. Written before the code.
# V-E10b-4 (the worker rule), V-E10b-5 (results join in task order), a killed worker, and the default (cores = 1) leaving everything as it was.

test_that("V-E10b-4: the worker rule gives the written answers and names the limiting factor", {
  wc <- seqcompendium:::worker_count
  a <- wc(asked = 8, detected = 8, ram_gb = 8, peak_gb = 2.5);  expect_equal(a$workers, 2);  expect_match(a$reason, "memory")
  b <- wc(asked = 8, detected = 8, ram_gb = 8, peak_gb = 13.5); expect_equal(b$workers, 1);  expect_match(b$reason, "memory")
  d <- wc(asked = 8, detected = 4, ram_gb = 64, peak_gb = 13.5); expect_equal(d$workers, 3); expect_match(d$reason, "cores")
  e <- wc(asked = 1, detected = 8, ram_gb = 64, peak_gb = 1);   expect_equal(e$workers, 1);  expect_match(e$reason, "asked")
  f <- wc(asked = 2, detected = 8, ram_gb = 64, peak_gb = 1);   expect_equal(f$workers, 2);  expect_match(f$reason, "asked")
  expect_match(a$reason, "you asked for 8")          # the message says what was asked and what is used
  expect_match(a$reason, "using 2")
  g <- wc(asked = 4, detected = 1, ram_gb = 64, peak_gb = 1);   expect_equal(g$workers, 1)   # never below 1
})

test_that("V-E10b-5: results come back in task order whatever order they finish in", {
  pm <- seqcompendium:::par_map; me <- Sys.getpid()
  slow_first <- function(i) { if (Sys.getpid() != me && i == 2) Sys.sleep(1.5); i^2 }   # task 2 is the slowest worker task
  options(seqcompendium.ram_gb = 64); on.exit(options(seqcompendium.ram_gb = NULL), add = TRUE)
  got <- pm(1:8, slow_first, cores = 3, label = "test")
  expect_identical(got, as.list((1:8)^2))
  expect_identical(pm(1:8, slow_first, cores = 1, label = "test"), as.list((1:8)^2))   # cores = 1 is a plain serial loop
})

test_that("V-E10b-2: handing the tasks out in a shuffled order does not change the joined result", {
  pm <- seqcompendium:::par_map
  options(seqcompendium.ram_gb = 64, seqcompendium.shuffle_seed = 7L); on.exit(options(seqcompendium.ram_gb = NULL, seqcompendium.shuffle_seed = NULL), add = TRUE)
  fn <- function(i) { set.seed(1000L + i); c(i, runif(1)) }     # a task whose value depends only on its own seed
  expect_identical(pm(1:9, fn, cores = 3, label = "test"), lapply(1:9, fn))
})

test_that("a replicate's random numbers depend only on its own seed, not on the worker count", {
  pm <- seqcompendium:::par_map
  options(seqcompendium.ram_gb = 64); on.exit(options(seqcompendium.ram_gb = NULL), add = TRUE)
  fn <- function(i) { set.seed(5000L + i); runif(3) }
  expect_identical(pm(1:10, fn, cores = 1, label = "test"), pm(1:10, fn, cores = 4, label = "test"))
})

test_that("V-E10b-4: a worker that dies stops the run with a message naming `cores`, and no result with a gap is returned", {
  skip_on_os("windows")
  pm <- seqcompendium:::par_map; me <- Sys.getpid()
  options(seqcompendium.ram_gb = 64); on.exit(options(seqcompendium.ram_gb = NULL), add = TRUE)
  die <- function(i) { if (Sys.getpid() != me && i == 3) tools::pskill(Sys.getpid(), tools::SIGKILL); i }
  expect_error(pm(1:6, die, cores = 3, label = "test"), "cores")
  boom <- function(i) { if (Sys.getpid() != me && i == 4) stop("task four failed"); i }
  expect_error(pm(1:6, boom, cores = 3, label = "test"), "task four failed")
})

test_that("each loop records what it used, and the settings file says why", {
  pm <- seqcompendium:::par_map
  options(seqcompendium.ram_gb = 64); on.exit(options(seqcompendium.ram_gb = NULL), add = TRUE)
  seqcompendium:::par_log_reset()
  invisible(pm(1:6, function(i) i, cores = 2, label = "calibration"))
  invisible(pm(1:6, function(i) i, cores = 1, label = "mde"))
  s <- seqcompendium:::par_log_get()
  expect_equal(names(s), c("calibration", "mde"))
  expect_equal(s$calibration$cores_asked, 2); expect_equal(s$calibration$workers_used, 2); expect_equal(s$mde$workers_used, 1)
})

test_that("cores must be a whole number of at least 1", {
  expect_error(seqcompendium:::check_cores(0), "cores")
  expect_error(seqcompendium:::check_cores("a"), "cores")
  expect_equal(seqcompendium:::check_cores(3), 3L)
})

# V-E10b-1 (identity) on a small bundle, the part that needs the simulator: the whole run at cores = 1, 2 and 4 gives the same CSV files byte for byte.
# The pre-registered mark runs the main toy and the first 4 V-E1 bundles through validation/mac_marks.R; this is the cheap version for CI.
test_that("V-E10b-1 (small): run_compendium at cores = 1, 2 and 4 writes byte-identical CSVs; only run_settings.yaml differs", {
  skip_on_os("windows")
  b <- toy("calib"); o1 <- out_dir(); o2 <- out_dir(); o4 <- out_dir()   # "calib": a design on which the override check runs
  run_compendium(b, o1, cores = 1); run_compendium(b, o2, cores = 2); run_compendium(b, o4, cores = 4)
  csvs <- function(o) sort(list.files(o, pattern = "\\.csv$", recursive = TRUE))
  expect_identical(csvs(o1), csvs(o2)); expect_identical(csvs(o1), csvs(o4))
  md5 <- function(o, f) unname(tools::md5sum(file.path(o, f)))
  for (f in csvs(o1)) { expect_identical(md5(o1, f), md5(o2, f), info = f); expect_identical(md5(o1, f), md5(o4, f), info = f) }
  st <- yaml::read_yaml(file.path(o4, "provenance", "run_settings.yaml")); expect_equal(st$cores_asked, 4)
  expect_true(file.exists(file.path(o1, "provenance", "run_settings.yaml")))
  expect_true(all(c("calibration loop", "minimum-detectable-effect loop") %in% names(st$workers_used)))   # the override check really ran (not vacuous)
  expect_true(file.exists(file.path(o1, "02_method_choice", "simulation", "per_dataset.csv")))
})
