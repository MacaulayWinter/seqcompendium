# override.R: checking the default Q4 method on simulated data from the
# study's own reference samples, and switching only if it fails
# (design section 5.3, choices C13 and C23; idea from nf-core/daamicrobiome
# and MIDASim, F6; CLAUDE.md D19).
#
# Nothing here sees the real data's group differences: the simulator is fitted
# to the reference samples only, and the planted differences are known.

Q4_CANDIDATES <- c("D01", "D09", "D06", "D04", "D17")

simrep <- function() getOption("seqcompendium.simrep", rule("R-SIMREP"))   # the option is a test hook only

# One simulated comparison at the real group sizes. Planted: 10% of the
# features present in at least half the reference samples, at fold change 2
# in the second group, on the absolute scale (shares shift by renormalising).
simulate_unit <- function(fit, base, libs, ratio, n1, n2, planted, seed) {
  set.seed(seed)
  n <- n1 + n2
  common <- which(colMeans(fit$ref > 0) >= 0.5)
  hit <- if (planted) sort(sample(common, max(1, round(0.1 * ncol(fit$ref))))) else integer(0)
  M <- matrix(base, n, length(base), byrow = TRUE)
  if (length(hit)) M[(n1 + 1):n, hit] <- M[(n1 + 1):n, hit] * 2
  M <- M / rowSums(M)
  lib <- sample(libs, n, replace = TRUE)
  mod <- suppressMessages(MIDASim::MIDASim.modify(fit$midas, lib.size = lib, individual.rel.abund = M))
  sim <- suppressMessages(MIDASim::MIDASim(mod))
  m <- sim$sim_count; dimnames(m) <- list(sprintf("sim%02d", seq_len(n)), colnames(fit$ref))
  g <- factor(rep(c("reference", "level"), c(n1, n2)), levels = c("reference", "level"))
  den <- if (is.null(ratio)) NULL else rowSums(m) * sample(ratio, n, replace = TRUE)
  list(ud = list(m = m, g = g, den = den, lib = rowSums(m), samples = rownames(m)), truth = colnames(m)[hit])
}

# Calibration of every candidate on one comparison.
calibrate_unit <- function(u, layer, ids, unit_index) {
  ud <- unit_data(u, layer)
  ref <- round(ud$m[u$ref_samples, , drop = FALSE])
  if (nrow(ref) < rule("R-MINSIM"))
    return(list(skipped = sprintf("not run: reference group n = %d, fewer than %d (rule R-MINSIM)", nrow(ref), rule("R-MINSIM")), n_ref = nrow(ref)))
  ref <- ref[, colSums(ref) > 0, drop = FALSE]
  set.seed(seed_for(50))
  midas <- tryCatch(suppressMessages(MIDASim::MIDASim.setup(ref, mode = "parametric")), error = function(e) conditionMessage(e))
  if (is.character(midas)) return(list(skipped = sprintf("not run: the simulator could not be fitted to the reference samples (%s)", midas), n_ref = nrow(ref)))
  fit <- list(midas = midas, ref = ref)
  base <- colMeans(ref / rowSums(ref)); base <- pmax(base, 1e-8); base <- base / sum(base)
  ratio <- if (is.null(ud$den)) NULL else (ud$den / ud$lib)[seq_along(u$ref_samples)]
  R <- simrep(); rows <- list()
  for (r in seq_len(R)) {
    planted <- r > R / 2
    seed <- seed_for(5000) + 1000L * unit_index + r
    sim <- simulate_unit(fit, base, rowSums(ref), ratio, length(u$ref_samples), length(u$level_samples), planted, seed = seed)
    feats <- prevalent(sim$ud$m, sim$ud$g)
    for (id in ids) {
      if (id == "D01" && is.null(sim$ud$den)) next
      res <- tryCatch(suppressMessages(suppressWarnings(FITS[[id]](sim$ud, feats))), error = function(e) NULL)
      if (is.null(res)) { rows[[length(rows) + 1]] <- data.frame(method_id = id, rep = r, seed = seed, planted = planted, calls = NA, false_calls = NA, true_calls = NA, n_planted = length(sim$truth), fit = "failed"); next }
      ok <- is.finite(res$p); qq <- rep(NA_real_, nrow(res)); qq[ok] <- stats::p.adjust(res$p[ok], "BH")
      call <- res$feature[!is.na(qq) & qq <= rule("R-FDR")]
      rows[[length(rows) + 1]] <- data.frame(method_id = id, rep = r, seed = seed, planted = planted, calls = length(call),
                                             false_calls = sum(!call %in% sim$truth), true_calls = sum(call %in% sim$truth),
                                             n_planted = sum(sim$truth %in% feats), fit = "ok")
    }
  }
  per_rep <- do.call(rbind, rows)
  summ <- do.call(rbind, lapply(split(per_rep, per_rep$method_id), function(d) {
    ok <- d[d$fit == "ok", ]
    data.frame(method_id = d$method_id[1], datasets = nrow(d), failed_fits = sum(d$fit != "ok"),
               fdr = if (nrow(ok)) mean(ifelse(ok$calls > 0, ok$false_calls / ok$calls, 0)) else NA_real_,
               power = if (any(ok$planted & ok$n_planted > 0)) mean((ok$true_calls / ok$n_planted)[ok$planted & ok$n_planted > 0]) else NA_real_)
  }))
  list(summary = summ, per_rep = per_rep, n_ref = nrow(ref))
}

# The decision (design 5.3 step 4, C13): keep the default if its simulated
# FDR is within R-CAL x R-FDR; otherwise the first method in priority order
# that is; otherwise keep the default with a caveat. A method that failed the
# mock test cannot be chosen.
decide_override <- function(summary, default_id, mock_failed = character(0)) {
  limit <- rule("R-CAL") * rule("R-FDR")
  pass <- function(id) { f <- summary$fdr[summary$method_id == id]; length(f) == 1 && is.finite(f) && f <= limit && !id %in% mock_failed }
  if (pass(default_id)) return(list(final = default_id, decision = "kept", caveat = ""))
  cat <- catalogue(); pr <- cat[cat$id %in% summary$method_id & nzchar(cat$priority), c("id", "priority")]
  pr <- pr[order(as.integer(pr$priority)), "id"]
  for (id in setdiff(pr, default_id)) if (pass(id)) return(list(final = id, decision = "switched", caveat = ""))
  list(final = default_id, decision = "kept, none calibrated", caveat = "no method was calibrated on simulated data like yours")
}

# Step 0, the mock check (C23; CLAUDE.md D19a). Recovery needs a known
# composition in the manifest; the shuffled-label test needs 2 x R-MINGRP mocks.
mock_check <- function(layers, des, manifest_dir, ids) {
  mocks <- des$controls$sample[des$controls$kind == "positive_mock"]
  out <- list(recovery = NULL, test = NULL, failed = character(0), note = NULL)
  if (length(mocks) < 2) { out$note <- sprintf("not run: %d positive_mock sample(s), at least 2 needed", length(mocks)); return(out) }
  rec <- list(); tst <- list()
  for (nm in names(layers)) {
    L <- layers[[nm]]; m <- wide(L, mocks)
    comp <- L$spec$mock_composition
    if (is.null(comp)) rec[[nm]] <- data.frame(layer = nm, sample = rownames(m), known_members = NA, detected = NA, unexpected_read_share = NA, largest_proportion_error = NA,
                                              note = "no mock composition in the manifest (layers: mock_composition), so recovery cannot be measured")
    else {
      kc <- read_table(file.path(manifest_dir, comp)); kc$proportion <- as.numeric(kc$proportion)
      rec[[nm]] <- do.call(rbind, lapply(rownames(m), function(s) {
        x <- m[s, ]; tot <- sum(x); known <- intersect(kc$feature, names(x))
        data.frame(layer = nm, sample = s, known_members = nrow(kc), detected = sum(x[known] > 0),
                   unexpected_read_share = if (tot > 0) sum(x[!names(x) %in% kc$feature]) / tot else NA,
                   # Largest gap between a known member's observed share (among the
                   # known members) and its known proportion; works for any
                   # composition, including equal ones, where a correlation cannot.
                   largest_proportion_error = if (sum(x[known]) > 0) max(abs(x[known] / sum(x[known]) - kc$proportion[match(known, kc$feature)] / sum(kc$proportion))) else NA,
                   note = "")
      }))
    }
    if (length(mocks) < 2 * rule("R-MINGRP")) {
      tst[[nm]] <- data.frame(layer = nm, method_id = NA, calls = NA, result = sprintf("not testable: %d mocks; a shuffled-label test needs at least %d (2 x R-MINGRP)", length(mocks), 2 * rule("R-MINGRP")))
      next
    }
    set.seed(seed_for(60)); half <- sample(rep(c("a", "b"), length.out = length(mocks)))
    g <- factor(half, levels = c("a", "b")); o <- order(g)
    ud <- list(m = round(m[o, , drop = FALSE]), g = g[o], den = NULL, lib = rowSums(m[o, , drop = FALSE]), samples = rownames(m)[o])
    feats <- prevalent(ud$m, ud$g)
    tst[[nm]] <- do.call(rbind, lapply(setdiff(ids, "D01"), function(id) {
      r <- tryCatch(suppressMessages(suppressWarnings(FITS[[id]](ud, feats))), error = function(e) NULL)
      if (is.null(r)) return(data.frame(layer = nm, method_id = id, calls = NA, result = "the method failed to fit"))
      ok <- is.finite(r$p); qq <- rep(NA_real_, nrow(r)); qq[ok] <- stats::p.adjust(r$p[ok], "BH")
      k <- sum(!is.na(qq) & qq <= rule("R-FDR"))
      data.frame(layer = nm, method_id = id, calls = k, result = if (k > 0) "fails: reported differences between mock replicates" else "passes")
    }))
  }
  out$recovery <- do.call(rbind, rec); out$test <- do.call(rbind, tst)
  out$failed <- unique(stats::na.omit(out$test$method_id[out$test$result == sprintf("fails: reported differences between mock replicates")]))
  out
}

# Runs steps 0-5 for every Q4 comparison. Returns the per-unit decision, the
# calibration tables and the mock check.
run_override <- function(units, layers, choices, considered, des, bundle_dir) {
  mk <- mock_check(layers, des, bundle_dir, Q4_CANDIDATES)
  dec <- list(); cal <- list(); reps <- list()
  for (i in seq_along(units)) {
    u <- units[[i]]; L <- layers[[u$layer]]
    if (!u$testable || L$spec$unit != "count") next
    ch <- choices[choices$layer == u$layer & choices$question == "Q4", ]
    elig <- considered$id[considered$layer == u$layer & considered$eligible == "yes"]
    ids <- intersect(Q4_CANDIDATES, elig)
    x <- calibrate_unit(u, L, ids, i)
    key <- unit_key(u)
    if (!is.null(x$skipped)) {
      dec[[i]] <- cbind(key, default_id = ch$final_id, final_id = ch$final_id, decision = x$skipped, n_reference = x$n_ref,
                        default_fdr = NA, limit = rule("R-CAL") * rule("R-FDR"), datasets = 0,
                        caveat = sprintf("the default could not be checked on simulated data from your controls (%s); it was kept on the strength of published benchmarks only", sub("^not run: ", "", x$skipped)))
      next
    }
    d <- decide_override(x$summary, ch$final_id, mk$failed)
    cal[[i]] <- cbind(key, n_reference = x$n_ref, x$summary)
    reps[[i]] <- cbind(key, x$per_rep)
    dec[[i]] <- cbind(key, default_id = ch$final_id, final_id = d$final, decision = d$decision, n_reference = x$n_ref,
                      default_fdr = x$summary$fdr[x$summary$method_id == ch$final_id], limit = rule("R-CAL") * rule("R-FDR"),
                      datasets = simrep(), caveat = d$caveat)
  }
  bind <- function(l) { l <- Filter(Negate(is.null), l); if (length(l)) do.call(rbind, l) else NULL }
  list(decisions = bind(dec), calibration = bind(cal), per_rep = bind(reps), mock = mk)
}
