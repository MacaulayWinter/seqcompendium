# parallel.R: running the override check's simulated data sets side by side (V-E10b,
# validation/PREREGISTRATION.md section 10). The answer must not depend on the number of
# cores: every task sets its own seed, packages that draw random numbers when they load are
# loaded before any seed is set, workers are forked (parallel::mclapply) so they inherit the
# same R state, results are joined in task order, and the default is one core, which is a
# plain serial loop exactly as before.

check_cores <- function(cores) {
  if (!is.numeric(cores) || length(cores) != 1 || is.na(cores) || cores < 1 || cores != round(cores))
    stop_engine("`cores` must be a whole number of at least 1 (for example cores = 4).")
  as.integer(cores)
}

# The worker rule (section 10.1): max(1, min(cores asked, detected cores - 1,
# floor((available RAM - 1 GB) / the loop's measured single-process peak))).
worker_count <- function(asked, detected, ram_gb, peak_gb) {
  by_cores <- max(1L, as.integer(detected) - 1L)
  by_mem <- if (is.finite(ram_gb) && is.finite(peak_gb) && peak_gb > 0) as.integer(floor((ram_gb - 1) / peak_gb)) else NA_integer_
  lim <- c(asked = as.integer(asked), cores = by_cores, memory = by_mem)
  w <- max(1L, min(lim, na.rm = TRUE))
  # The limiting factor is named only when it is below what was asked.
  who <- if (w >= asked) "asked" else if (!is.na(by_mem) && by_mem < by_cores) "memory" else "cores"
  reason <- switch(who,
    asked  = sprintf("you asked for %d; using %d (as asked)", asked, w),
    cores  = sprintf("you asked for %d; using %d: this machine has %d cores and one is left free", asked, w, as.integer(detected)),
    memory = sprintf("you asked for %d; using %d: memory allows it (this machine has %.0f GB of memory free and each worker needs about %.1f GB)", asked, w, ram_gb, peak_gb))
  list(workers = w, reason = reason)
}

# Available memory in GB: a test hook, then the container's limit, then the machine's.
available_ram_gb <- function() {
  h <- getOption("seqcompendium.ram_gb"); if (!is.null(h)) return(as.numeric(h))
  out <- NA_real_
  rd <- function(f) tryCatch(suppressWarnings(as.numeric(readLines(f, n = 1, warn = FALSE))), error = function(e) NA_real_)
  if (file.exists("/proc/meminfo")) {
    mi <- readLines("/proc/meminfo"); a <- mi[grepl("^MemAvailable:", mi)]
    if (length(a)) out <- as.numeric(gsub("[^0-9]", "", a)) / 1024^2
    lim <- rd("/sys/fs/cgroup/memory.max"); use <- rd("/sys/fs/cgroup/memory.current")           # cgroup v2
    if (is.na(lim)) { lim <- rd("/sys/fs/cgroup/memory/memory.limit_in_bytes"); use <- rd("/sys/fs/cgroup/memory/memory.usage_in_bytes") }   # v1
    if (is.finite(lim) && lim < 2^50) out <- min(out, (lim - if (is.finite(use)) use else 0) / 1024^3, na.rm = TRUE)
  } else {
    tot <- tryCatch(as.numeric(system("sysctl -n hw.memsize", intern = TRUE, ignore.stderr = TRUE)) / 1024^3, error = function(e) NA_real_, warning = function(w) NA_real_)
    vm <- tryCatch(system("vm_stat", intern = TRUE, ignore.stderr = TRUE), error = function(e) character(), warning = function(w) character())
    pg <- function(k) { l <- vm[grepl(k, vm)]; if (length(l)) as.numeric(gsub("[^0-9]", "", sub(".*:", "", l[1]))) else 0 }
    ps <- as.numeric(sub(".*page size of ([0-9]+) bytes.*", "\\1", vm[1])); if (is.na(ps)) ps <- 4096
    if (length(vm)) out <- (pg("Pages free") + pg("Pages inactive")) * ps / 1024^3 else out <- tot
  }
  out
}

# This process's peak resident memory in GB (Linux: VmHWM; elsewhere the current resident size).
peak_rss_gb <- function() {
  if (file.exists("/proc/self/status")) {
    x <- readLines("/proc/self/status"); h <- x[grepl("^VmHWM:", x)]
    if (length(h)) return(as.numeric(gsub("[^0-9]", "", h)) / 1024^2)
  }
  r <- tryCatch(suppressWarnings(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE, ignore.stderr = TRUE))) / 1024^2, error = function(e) NA_real_)
  if (length(r) == 1) r else NA_real_
}

# What each loop used, for provenance/run_settings.yaml (the one file allowed to differ between core counts).
.par_log <- new.env()
par_log_reset <- function() { rm(list = ls(.par_log), envir = .par_log); invisible(NULL) }
par_log_get <- function() { k <- ls(.par_log); k <- k[order(vapply(k, function(n) .par_log[[n]]$order, 1))]; stats::setNames(lapply(k, function(n) .par_log[[n]][c("cores_asked", "workers_used", "reason")]), k) }
par_log_add <- function(label, asked, workers, reason) {
  .par_log[[label]] <- list(order = length(ls(.par_log)) + 1, cores_asked = asked, workers_used = workers, reason = reason)
}

# Runs fn over tasks and returns the results as a list in task order. cores = 1 (the default)
# is a plain lapply. With more cores, task 1 runs alone in this process first, its peak memory
# sizes the workers (worker_count), and the rest run in forked workers; a worker that dies, or
# a task that fails, stops the run with a clear message, never a gap in the results.
par_map <- function(tasks, fn, cores = 1L, label = "tasks") {
  cores <- check_cores(cores); n <- length(tasks)
  if (cores == 1L || n < 2L || .Platform$OS.type == "windows") {
    par_log_add(label, cores, 1L, if (cores == 1L) "you asked for 1; using 1 (as asked)" else if (n < 2L) "you asked for more than 1, but there is only one task" else "this system cannot fork workers (native Windows R): run the engine in WSL2 or Docker")
    return(lapply(tasks, fn))
  }
  load_before_seed(DIVNET_LOADS)                                    # before any seed is set (D53)
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1")
  first <- fn(tasks[[1]]); if (is.null(first)) stop_engine("An internal task returned no result.")
  wc <- worker_count(cores, parallel::detectCores(), available_ram_gb(), peak_rss_gb())
  par_log_add(label, cores, wc$workers, wc$reason); message(sprintf("%s: %s.", label, wc$reason))
  if (wc$workers == 1L) return(c(list(first), lapply(tasks[-1], fn)))
  rest <- seq_len(n)[-1]
  sh <- getOption("seqcompendium.shuffle_seed")                       # a test hook: hand the tasks out in a shuffled order
  if (!is.null(sh)) { old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv()); set.seed(sh); rest <- sample(rest); if (!is.null(old)) assign(".Random.seed", old, globalenv()) }
  got <- suppressWarnings(parallel::mclapply(tasks[rest], fn, mc.cores = wc$workers, mc.preschedule = FALSE, mc.set.seed = FALSE))
  bad <- which(vapply(got, function(x) is.null(x) || inherits(x, "try-error"), TRUE))
  if (length(bad)) {
    msg <- got[[bad[1]]]; why <- if (inherits(msg, "try-error")) sub("^Error in [^:]*: ?", "", trimws(as.character(msg))) else "the worker stopped without a result (it was probably killed for lack of memory)"
    stop_engine(sprintf("%s: %d of %d simulated data sets did not finish: %s. No partial result is written. Run again with a smaller `cores` (cores = 1 runs one after another).", label, length(bad), n, why))
  }
  out <- vector("list", n); out[[1]] <- first; out[rest] <- got
  out
}
