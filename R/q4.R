# q4.R: Q4, which features differ in abundance? (design sections 5.2 and 6)
#
# Default: DESeq2 with the layer's denominator as offset (catalogue D01) when
# the layer has one; LinDA (D09) when it has none. Residual checks per feature
# (DHARMa on a negative binomial refit, D18/X08, for count models; residual
# skewness and spread for LinDA's linear model), then the fallback ladder:
#   count models  rung 1 zero-inflated NB (R02), rung 2 permutation test on CLR (K04)
#   LinDA         rung 1 Welch t-test on CLR,   rung 2 Wilcoxon on CLR
# A feature that fails its checks moves down a rung, with a caveat; if more
# features fail than in clean simulated data (Fisher's exact test, R-EXCESS; CLAUDE.md D17, D22),
# the whole question moves a rung (design C14).
# Agreement set and describe-only methods run alongside, every time.

fit_deseq2 <- function(ud, feats) {
  cts <- t(round(ud$m[, feats, drop = FALSE]))
  cd <- if (is.null(ud$cov)) data.frame(g = ud$g) else data.frame(ud$cov, g = ud$g)
  dds <- DESeq2::DESeqDataSetFromMatrix(cts, cd, stats::as.formula(paste("~", cov_terms(ud$cov), "g")))
  off <- offset_of(ud)
  DESeq2::sizeFactors(dds) <- off / exp(mean(log(off)))
  dds <- suppressMessages(DESeq2::DESeq(dds, quiet = TRUE, minReplicatesForReplace = Inf))
  r <- DESeq2::results(dds, name = grep("^g_", DESeq2::resultsNames(dds), value = TRUE)[1], cooksCutoff = FALSE, independentFiltering = FALSE)
  data.frame(feature = rownames(r), effect = r$log2FoldChange, se = r$lfcSE, stat = r$stat, p = r$pvalue,
             effect_unit = "log2 fold change, per unit of the denominator")
}

fit_linda <- function(ud, feats) {
  res <- suppressMessages(suppressWarnings(utils::capture.output(
    out <- MicrobiomeStat::linda(feature.dat = t(ud$m[, feats, drop = FALSE]),
                                 meta.dat = if (is.null(ud$cov)) data.frame(g = ud$g, row.names = ud$samples) else data.frame(ud$cov, g = ud$g, row.names = ud$samples),
                                 formula = paste("~", cov_terms(ud$cov), "g"), feature.dat.type = "count", prev.filter = 0, mean.abund.filter = 0, max.abund.filter = 0))))
  r <- out$output[[grep("^g", names(out$output))[1]]]
  data.frame(feature = rownames(r), effect = r$log2FoldChange, se = r$lfcSE, stat = r$stat, p = r$pvalue,
             effect_unit = "log2 fold change (LinDA, bias-corrected CLR)")
}

fit_aldex2 <- function(ud, feats) {
  set.seed(seed_for(41))
  if (!is.null(ud$cov)) {
    # With covariates (D24): ALDEx2's model-matrix route, coefficient of g.
    mm <- stats::model.matrix(stats::as.formula(paste("~", cov_terms(ud$cov), "g")), data.frame(ud$cov, g = ud$g))
    cl <- suppressMessages(ALDEx2::aldex.clr(as.data.frame(t(ud$m[, feats, drop = FALSE])), mm, mc.samples = 128, denom = "all", verbose = FALSE))
    gl <- suppressMessages(ALDEx2::aldex.glm(cl, mm))
    k <- paste0("g", levels(ud$g)[2])   # ALDEx2 1.44 names: "<term>:Est", ":SE", ":t.val", ":pval"
    return(data.frame(feature = rownames(gl), effect = gl[[paste0(k, ":Est")]], se = gl[[paste0(k, ":SE")]], stat = gl[[paste0(k, ":t.val")]],
                      p = gl[[paste0(k, ":pval")]], effect_unit = "CLR coefficient (ALDEx2 GLM, adjusted)"))
  }
  x <- suppressMessages(ALDEx2::aldex(as.data.frame(t(ud$m[, feats, drop = FALSE])), as.character(ud$g), mc.samples = 128, test = "t",
                                      effect = TRUE, denom = "all", verbose = FALSE))
  data.frame(feature = rownames(x), effect = x$diff.btw, se = NA_real_, stat = x$effect, p = x$we.ep, effect_unit = "difference in median CLR")
}

fit_ancombc2 <- function(ud, feats) {
  set.seed(seed_for(42))
  tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(assays = list(counts = t(ud$m[, feats, drop = FALSE])),
                                                            colData = if (is.null(ud$cov)) S4Vectors::DataFrame(g = ud$g, row.names = ud$samples) else S4Vectors::DataFrame(ud$cov, g = ud$g, row.names = ud$samples))
  out <- suppressMessages(suppressWarnings(ANCOMBC::ancombc2(data = tse, assay_name = "counts", fix_formula = paste0(cov_terms(ud$cov), "g"), p_adj_method = "BH",
                                                             prv_cut = 0, lib_cut = 0, s0_perc = 0.05, struc_zero = FALSE, neg_lb = FALSE,
                                                             alpha = rule("R-FDR"), global = FALSE, pairwise = FALSE, verbose = FALSE)))
  r <- out$res; k <- paste0("g", levels(ud$g)[2])
  data.frame(feature = r$taxon, effect = r[[paste0("lfc_", k)]] / log(2), se = r[[paste0("se_", k)]] / log(2), stat = r[[paste0("W_", k)]],
             p = r[[paste0("p_", k)]], effect_unit = "log2 fold change (ANCOM-BC2, bias-corrected)")
}

fit_wilcoxon_clr <- function(ud, feats) {
  z <- clr(ud$m)[, feats, drop = FALSE]; a <- ud$g == levels(ud$g)[1]
  do.call(rbind, lapply(feats, function(f) data.frame(feature = f, effect = mean(z[!a, f]) - mean(z[a, f]), se = NA_real_, stat = NA_real_,
                                                       p = suppressWarnings(stats::wilcox.test(z[!a, f], z[a, f])$p.value),
                                                       effect_unit = "difference in mean CLR")))
}

fit_welch_clr <- function(ud, feats) {
  z <- clr(ud$m)[, feats, drop = FALSE]; a <- ud$g == levels(ud$g)[1]
  do.call(rbind, lapply(feats, function(f) {
    t <- tryCatch(stats::t.test(z[!a, f], z[a, f]), error = function(e) NULL)
    data.frame(feature = f, effect = mean(z[!a, f]) - mean(z[a, f]), se = if (is.null(t)) NA else t$stderr, stat = if (is.null(t)) NA else unname(t$statistic),
               p = if (is.null(t)) NA else t$p.value, effect_unit = "difference in mean CLR")
  }))
}

fit_zinb <- function(ud, f) {
  d <- data.frame(y = round(ud$m[, f]), off = log(offset_of(ud)), g = ud$g); if (!is.null(ud$cov)) d <- cbind(d, ud$cov)
  fit <- tryCatch(suppressWarnings(pscl::zeroinfl(stats::as.formula(paste("y ~", cov_terms(ud$cov), "g + offset(off) | 1")), data = d, dist = "negbin")), error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  co <- summary(fit)$coefficients$count
  k <- grep("^g", rownames(co))[1]
  if (is.na(k) || !is.finite(co[k, 4])) return(NULL)
  data.frame(feature = f, effect = co[k, 1] / log(2), se = co[k, 2] / log(2), stat = co[k, 3], p = co[k, 4],
             effect_unit = "log2 fold change (zero-inflated NB, count part)")
}

fit_perm_clr <- function(ud, f) {
  z <- clr(ud$m)[, f]; a <- ud$g == levels(ud$g)[1]
  obs <- mean(z[!a]) - mean(z[a])
  set.seed(seed_for(43))
  perm <- replicate(rule("R-PERM"), { s <- sample(a); mean(z[!s]) - mean(z[s]) })
  data.frame(feature = f, effect = obs, se = NA_real_, stat = NA_real_, p = (1 + sum(abs(perm) >= abs(obs) - 1e-12)) / (rule("R-PERM") + 1),
             effect_unit = "difference in mean CLR (permutation test)")
}

# Residual checks. Count default: DHARMa on a negative binomial refit with the
# same offset. LinDA: skewness and spread of the CLR linear model's residuals.
check_nb <- function(ud, f, k) {
  d <- data.frame(y = round(ud$m[, f]), off = log(offset_of(ud)), g = ud$g); if (!is.null(ud$cov)) d <- cbind(d, ud$cov)
  fit <- tryCatch(suppressWarnings(MASS::glm.nb(stats::as.formula(paste("y ~", cov_terms(ud$cov), "g + offset(off)")), data = d)), error = function(e) NULL)
  if (is.null(fit)) return(data.frame(feature = f, check = "negative binomial refit", uniformity_p = NA, dispersion_p = NA, zero_inflation_p = NA,
                                      failed = TRUE, why = "the negative binomial refit for the check did not converge"))
  sim <- DHARMa::simulateResiduals(fit, n = 250, seed = seed_for(1000 + k), plot = FALSE)
  pu <- DHARMa::testUniformity(sim, plot = FALSE)$p.value
  pd <- DHARMa::testDispersion(sim, plot = FALSE)$p.value
  pz <- DHARMa::testZeroInflation(sim, plot = FALSE)$p.value
  a <- rule("R-DIAGP")
  why <- c(if (pu < a) "residuals not uniform", if (pd < a) "dispersion not as the model expects", if (pz < a) "more zeros than the model expects")
  data.frame(feature = f, check = "DHARMa (negative binomial refit)", uniformity_p = pu, dispersion_p = pd, zero_inflation_p = pz,
             failed = length(why) > 0, why = paste(why, collapse = "; "))
}

check_lm_clr <- function(ud, f) {
  z <- clr(ud$m)[, f]; g <- ud$g
  r <- if (is.null(ud$cov)) z - stats::ave(z, g) else stats::residuals(stats::lm(stats::as.formula(paste("z ~", cov_terms(ud$cov), "g")), data.frame(z = z, g = g, ud$cov)))
  sk <- if (stats::sd(r) > 0) mean(r^3) / stats::sd(r)^3 else 0
  v <- tapply(r, g, stats::var); vr <- if (min(v) > 0) max(v) / min(v) else Inf
  why <- c(if (abs(sk) > rule("R-SKEW")) sprintf("residual skewness %.2f", sk), if (vr > rule("R-VARRATIO")) sprintf("group variance ratio %.1f", vr))
  data.frame(feature = f, check = "linear-model residuals on CLR", residual_skewness = sk, variance_ratio = vr, failed = length(why) > 0,
             why = paste(why, collapse = "; "))
}

FITS <- list(D01 = fit_deseq2, D09 = fit_linda, D04 = fit_aldex2, D06 = fit_ancombc2, D17 = fit_wilcoxon_clr)

q4_unit <- function(u, layer, default_id, des = NULL) {
  ud <- unit_data(u, layer, des)
  if (default_id == "D01" && (anyNA(ud$den) || any(ud$den <= 0)))
    return(list(skip = "a denominator is missing or zero for a sample in this comparison"))
  feats <- prevalent(ud$m, ud$g)
  if (length(feats) < 2) return(list(skip = "fewer than 2 features pass the prevalence rule (R-PREV)"))
  base <- tryCatch(FITS[[default_id]](ud, feats), error = function(e) NULL)
  if (is.null(base)) return(list(skip = sprintf("the default method (%s) failed to fit", default_id)))
  count_model <- default_id == "D01"
  # Residual checks and a fallback ladder exist for DESeq2 (count model) and
  # LinDA (linear model) only (design section 6). A method chosen by the
  # override rule (ANCOM-BC2, ALDEx2, Wilcoxon) is used as it is.
  if (!default_id %in% c("D01", "D09")) {
    res <- base; res$rung <- 0L; res$method_role <- "override"; res$caveat <- "chosen by the override rule; the design defines no residual check for this method"
    ok <- is.finite(res$p)
    res$ci_low <- res$effect - 1.96 * res$se; res$ci_high <- res$effect + 1.96 * res$se
    res$q <- NA_real_; res$q[ok] <- stats::p.adjust(res$p[ok], "BH")
    res$status <- ifelse(!ok, "not_testable", ifelse(res$q <= rule("R-FDR"), "lead", "no_evidence"))
    res$method_id <- default_id; res$n_reference <- length(u$ref_samples); res$n_level <- length(u$level_samples)
  # D24: what the result was adjusted for; methods that cannot adjust say so.
  res$adjusted_for <- ifelse(res$method_id %in% c("D17", "K01", "K04"), "not adjusted (this method cannot adjust for covariates)", ud$adjusted_for)
    res$share_expected_by_chance <- NA_real_; res$excess_failures_p <- NA_real_
    return(list(results = res, checks = NULL, share_failed = NA_real_, whole = FALSE, feats = feats, ud = ud))
  }
  chk <- do.call(rbind, lapply(seq_along(feats), function(k) if (count_model) check_nb(ud, feats[k], k) else check_lm_clr(ud, feats[k])))
  share <- mean(chk$failed)
  # How many failures chance alone would give (stated for the user, D16), and
  # whether this comparison clearly exceeds it (D17). The chance rate is
  # measured, not assumed (CLAUDE.md D21): the same checks are run on clean
  # data simulated from this comparison's own features.
  cr <- chance_failure_rate(ud, feats, count_model)
  chance <- cr$rate
  # The whole comparison moves only when clearly more features failed than in
  # the clean simulated data: one-sided Fisher's exact test of the two
  # failure shares, so the uncertainty in the measured chance rate counts too
  # (R-EXCESS; CLAUDE.md D17, D22).
  excess_p <- stats::fisher.test(matrix(c(sum(chk$failed), sum(!chk$failed), cr$failed, cr$total - cr$failed), 2, byrow = TRUE),
                                 alternative = "greater")$p.value
  whole <- excess_p < rule("R-EXCESS")
  chance_note <- sprintf(
    "on clean data simulated from this comparison's own features, about %.1f%% of features fail these residual checks by chance; here %d of %d features failed (about %.1f expected by chance), %s. Its result is still valid: it comes from a method that assumes less",
    100 * chance, sum(chk$failed), length(feats), chance * length(feats), chance_verdict(excess_p))
  rung1 <- if (count_model) function(f) fit_zinb(ud, f) else function(f) fit_welch_clr(ud, f)
  rung2 <- if (count_model) function(f) fit_perm_clr(ud, f) else function(f) { r <- fit_wilcoxon_clr(ud, f); r$effect_unit <- "difference in mean CLR (Wilcoxon)"; r }
  rung1_name <- if (count_model) "zero-inflated negative binomial (R02)" else "Welch t-test on CLR"
  rung2_name <- if (count_model) "permutation test on CLR (K04)" else "Wilcoxon rank-sum on CLR"
  res <- list()
  for (f in feats) {
    r <- base[base$feature == f, , drop = FALSE]; rung <- 0L; cav <- character(0)
    if (whole || chk$failed[chk$feature == f] || !is.finite(r$p)) {
      r1 <- tryCatch(rung1(f), error = function(e) NULL); rung <- 1L
      cav <- c(cav, if (whole) sprintf("%d of %d features failed their residual checks, more than in clean simulated data (about %.1f expected; Fisher's exact p = %.3g < R-EXCESS), so the whole question moved to rung 1 (%s)", sum(chk$failed), length(feats), chance * length(feats), excess_p, rung1_name)
                    else sprintf("residual checks failed (%s), so refitted at rung 1 (%s)", chk$why[chk$feature == f], rung1_name), chance_note)
      if (is.null(r1) || !is.finite(r1$p)) { r1 <- tryCatch(rung2(f), error = function(e) NULL); rung <- 2L
        cav <- c(cav, sprintf("rung 1 did not fit, so rung 2 (%s)", rung2_name)) }
      r <- r1
    }
    if (is.null(r) || !nrow(r) || !is.finite(r$p)) {
      res[[f]] <- data.frame(feature = f, effect = NA, se = NA, stat = NA, p = NA, effect_unit = NA, rung = rung, method_role = "fit failed",
                             caveat = paste(c(cav, "no method in the ladder could fit this feature; listed, not dropped"), collapse = "; "))
    } else {
      res[[f]] <- cbind(r[, c("feature", "effect", "se", "stat", "p", "effect_unit")], rung = rung,
                        method_role = if (rung == 0) "default" else sprintf("fallback rung %d", rung), caveat = paste(cav, collapse = "; "))
    }
  }
  res <- do.call(rbind, res)
  ok <- is.finite(res$p)
  res$ci_low <- res$effect - 1.96 * res$se; res$ci_high <- res$effect + 1.96 * res$se
  res$q <- NA_real_; res$q[ok] <- stats::p.adjust(res$p[ok], "BH")
  res$status <- ifelse(!ok, "not_testable", ifelse(res$q <= rule("R-FDR"), "lead", "no_evidence"))
  res$method_id <- ifelse(res$rung == 0, default_id, ifelse(res$rung == 1, if (count_model) "R02" else "K01", if (count_model) "K04" else "D17"))
  res$n_reference <- length(u$ref_samples); res$n_level <- length(u$level_samples)
  # D24: what the result was adjusted for; methods that cannot adjust say so.
  res$adjusted_for <- ifelse(res$method_id %in% c("D17", "K01", "K04"), "not adjusted (this method cannot adjust for covariates)", ud$adjusted_for)
  res$share_expected_by_chance <- chance; res$excess_failures_p <- excess_p
  list(results = res, checks = chk, share_failed = share, whole = whole, feats = feats, ud = ud)
}

# Agreement and describe-only methods for one unit. Each method's own BH
# within the unit gives its calls.
q4_agreement <- function(ud, feats, ids) {
  out <- list()
  for (id in ids) {
    r <- tryCatch(FITS[[id]](ud, feats), error = function(e) NULL)
    if (is.null(r)) { out[[id]] <- data.frame(feature = feats, method_id = id, effect = NA, p = NA, q = NA, call = NA, note = "the method failed to fit"); next }
    ok <- is.finite(r$p); qq <- rep(NA_real_, nrow(r)); qq[ok] <- stats::p.adjust(r$p[ok], "BH")
    out[[id]] <- data.frame(feature = r$feature, method_id = id, effect = r$effect, p = r$p, q = qq, call = !is.na(qq) & qq <= rule("R-FDR"), note = "")
  }
  do.call(rbind, out)
}

describe_lefse <- function(ud, feats) {
  rel <- t(ud$m[, feats, drop = FALSE] / pmax(rowSums(ud$m), 1))
  se <- SummarizedExperiment::SummarizedExperiment(assays = list(rel = rel), colData = S4Vectors::DataFrame(g = ud$g, row.names = ud$samples))
  set.seed(seed_for(44))
  r <- tryCatch(suppressMessages(suppressWarnings(lefser::lefser(se, classCol = "g", assay = "rel"))), error = function(e) conditionMessage(e))
  # Always one row at least, so "LEfSe found nothing" (or failed) is on record.
  if (is.character(r)) return(data.frame(feature = NA_character_, lda_score = NA_real_, note = sprintf("LEfSe did not run: %s", r)))
  if (!nrow(r)) return(data.frame(feature = NA_character_, lda_score = NA_real_, note = "LEfSe flagged no feature"))
  data.frame(feature = r$features, lda_score = r$scores, note = "")
}

q4_abundance <- function(units, layers, choices, decisions = NULL, des = NULL) {
  res <- list(); chk <- list(); agr <- list(); desc <- list(); notes <- list(); stats_for_q7 <- list()
  for (i in seq_along(units)) {
    u <- units[[i]]; L <- layers[[u$layer]]
    ch <- choices[choices$layer == u$layer & choices$question == "Q4", ]
    key <- unit_key(u)
    if (L$spec$unit != "count") { notes[[length(notes) + 1]] <- cbind(key, reason = sprintf("Q4 for unit %s is built at milestone E8", L$spec$unit)); next }
    if (!u$testable) { notes[[length(notes) + 1]] <- cbind(key, reason = u$reason); next }
    d <- if (is.null(decisions)) NULL else merge(key, decisions, by = names(key))
    final <- if (!is.null(d) && nrow(d)) d$final_id[1] else ch$final_id
    x <- q4_unit(u, L, final, des)
    if (!is.null(x$skip)) { notes[[length(notes) + 1]] <- cbind(key, reason = x$skip); next }
    if (!is.null(d) && nrow(d)) {
      if (final != ch$final_id) x$results$method_role <- ifelse(x$results$method_role == "default", "override", x$results$method_role)
      if (nzchar(d$caveat[1])) x$results$caveat <- ifelse(nzchar(x$results$caveat), paste(x$results$caveat, d$caveat[1], sep = "; "), d$caveat[1])
    }
    res[[i]] <- cbind(key, x$results, share_failed_checks = x$share_failed, whole_question_moved = x$whole)
    chk[[i]] <- if (!is.null(x$checks)) cbind(key, x$checks)
    agr[[i]] <- cbind(key, q4_agreement(x$ud, x$feats, setdiff(union(agreement_ids("Q4", L), ch$final_id), final)))
    lf <- describe_lefse(x$ud, x$feats)
    desc[[i]] <- cbind(key, method_id = "D19", lf, role = "describe_only")
    # Q7 ranks features by a z-score from each feature's final p-value and the
    # sign of its effect, so features at any fallback rung rank on one scale.
    z <- with(x$results, sign(effect) * stats::qnorm(pmax(p, 1e-300) / 2, lower.tail = FALSE))
    stats_for_q7[[i]] <- list(unit = u, stat = stats::setNames(z, x$results$feature)[is.finite(z)], ud = x$ud, feats = x$feats)
  }
  bind <- function(l) { l <- Filter(Negate(is.null), l); if (length(l)) do.call(rbind, l) else NULL }
  list(results = bind(res), checks = bind(chk), agreement = bind(agr), describe = bind(desc), skipped = bind(notes),
       for_q7 = Filter(Negate(is.null), stats_for_q7))
}

# The share of features that fail their residual checks by chance alone,
# measured on R-CHANCEREP data sets simulated from this comparison: each
# feature negative binomial with its own mean (scaled by each sample's
# offset) and its own dispersion (method of moments, groups pooled, so no
# group difference), then the same checks as the real data (CLAUDE.md D21).
chance_failure_rate <- function(ud, feats, count_model) {
  off <- offset_of(ud); w <- off / mean(off)
  y <- round(ud$m[, feats, drop = FALSE])
  rate <- colMeans(y / w)
  v <- apply(y / w, 2, stats::var)
  size <- ifelse(v > rate, rate^2 / pmax(v - rate, 1e-8), 1e4)
  set.seed(seed_for(46))
  failed <- 0; total <- 0
  for (r in seq_len(rule("R-CHANCEREP"))) {
    sim <- vapply(seq_along(feats), function(k) stats::rnbinom(nrow(y), mu = rate[k] * w, size = size[k]), numeric(nrow(y)))
    if (is.null(dim(sim))) sim <- matrix(sim, nrow = nrow(y))
    colnames(sim) <- feats; rownames(sim) <- rownames(y)
    m2 <- ud$m; m2[, feats] <- sim
    us <- list(m = m2, g = ud$g, den = ud$den, lib = ud$lib, samples = ud$samples)
    for (k in seq_along(feats)) {
      if (sum(sim[, k]) == 0) next
      f <- if (count_model) check_nb(us, feats[k], 100000 + 1000 * r + k) else check_lm_clr(us, feats[k])
      failed <- failed + f$failed; total <- total + 1
    }
  }
  if (total == 0) return(list(rate = NA_real_, failed = 0, total = 0))
  list(rate = failed / total, failed = failed, total = total)
}

# Says whether a comparison's check failures are within chance (D16, D22).
chance_verdict <- function(excess_p) if (is.finite(excess_p) && excess_p < rule("R-EXCESS"))
  "clearly more than chance would give, so the default model does not suit these data well" else
  "which is within what chance gives, so this feature may have moved by chance"
