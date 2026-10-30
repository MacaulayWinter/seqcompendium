# longitudinal.R: designs where subjects are sampled at several timepoints
# (design section 5.2, S1 longitudinal; C8; CLAUDE.md D24, D25).
#
# One mixed model per question, subject as a random intercept. Two
# parameterisations of the same model, so no contrast is ever pooled over time:
#   A  ~ time + time:g   each timepoint's group difference is its own coefficient (Q2, Q4)
#   B  ~ g + g:time      each group's change from the first timepoint (Q6)
# Covariates (batch, other predictors) enter both, per D24. Q3, Q5 and Q7 stay
# per timepoint, where each subject appears once.

long_ready <- function(des) {
  if (des$class != "longitudinal") return("the design is not longitudinal (no subject sampled at two or more times)")
  n <- length(unique(stats::na.omit(des$study[[des$subject]])))
  if (n < rule("R-RE")) return(sprintf("only %d subjects, fewer than %d (R-RE), so a subject random effect cannot be estimated; each timepoint is analysed on its own", n, rule("R-RE")))
  NULL
}

# One unit per layer x grouping predictor x block, all timepoints together.
long_units <- function(layers, des, cells) {
  st <- des$study; out <- list()
  for (nm in names(layers)) for (p in des$grouping) {
    lv <- des$levels_of(p); if (!length(lv)) next
    ce <- merge(cells, st[, c("sample", p, des$subject), drop = FALSE], by = "sample")
    ce <- ce[!is.na(ce[[p]]) & ce$timepoint %in% des$time_order & !is.na(ce[[des$subject]]), ]
    for (blk in unique(ce$block)) {
      d <- ce[ce$block == blk, ]
      d <- d[order(match(d$timepoint, des$time_order), d[[des$subject]]), ]
      tl <- intersect(des$time_order, unique(d$timepoint))
      if (length(tl) < 2) next
      out[[length(out) + 1]] <- list(layer = nm, predictor = p, block = blk, samples = d$sample,
                                     g = factor(d[[p]], levels = intersect(lv, unique(d[[p]]))), time = factor(d$timepoint, levels = tl),
                                     subject = factor(d[[des$subject]]))
    }
  }
  out
}

long_cov <- function(lu, des) {
  base <- stats::model.matrix(~ time + time:g, data.frame(time = lu$time, g = lu$g))
  adjustment_for(lu$samples, des, lu$predictor, base)
}

# Rows of the coefficient table that are A's per-time group contrasts or B's
# per-group time changes, with readable labels.
pick_A <- function(nms, lu) {
  out <- list()
  for (t in levels(lu$time)) for (l in levels(lu$g)[-1]) {
    k <- sprintf("time%s:g%s", t, l)
    if (k %in% nms) out[[length(out) + 1]] <- data.frame(coef = k, timepoint = t, contrast = sprintf("%s vs %s", l, levels(lu$g)[1]), level = l)
  }
  do.call(rbind, out)
}
pick_B <- function(nms, lu) {
  out <- list()
  for (l in levels(lu$g)) for (t in levels(lu$time)[-1]) {
    k <- sprintf("g%s:time%s", l, t)
    if (k %in% nms) out[[length(out) + 1]] <- data.frame(coef = k, group = l, change = sprintf("%s vs %s", t, levels(lu$time)[1]), time = t)
  }
  do.call(rbind, out)
}

n_at <- function(lu, t, l) sum(lu$time == t & lu$g == l)

# ---- Q2: Hill numbers, linear mixed model (L01) -------------------------------

q2_long <- function(lus, q2_per_sample, des) {
  A <- list(); B <- list(); diag <- list()
  for (lu in lus) {
    ps <- q2_per_sample[q2_per_sample$layer == lu$layer, ]
    adj <- long_cov(lu, des)
    for (qq in 0:2) {
      h <- ps$hill[ps$q_order == qq][match(lu$samples, ps$sample[ps$q_order == qq])]
      ok <- !is.na(h)
      dat <- data.frame(h = h, time = lu$time, g = lu$g, subject = lu$subject)
      if (!is.null(adj$cov)) dat <- cbind(dat, adj$cov)
      dat <- dat[ok, ]
      fA <- tryCatch(suppressMessages(lmerTest::lmer(stats::as.formula(paste("h ~", cov_terms(adj$cov), "time + time:g + (1 | subject)")), dat)), error = function(e) NULL)
      fB <- tryCatch(suppressMessages(lmerTest::lmer(stats::as.formula(paste("h ~", cov_terms(adj$cov), "g + g:time + (1 | subject)")), dat)), error = function(e) NULL)
      if (is.null(fA) || is.null(fB)) next
      res <- stats::residuals(fA); sk <- if (stats::sd(res) > 0) mean(res^3) / stats::sd(res)^3 else 0
      fail <- abs(sk) > rule("R-SKEW")
      diag[[length(diag) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, block = lu$block, q_order = qq, model = "L01 linear mixed model",
                                             residual_skewness = sk, failed = fail, action = if (fail) "moved to Wilcoxon tests per timepoint (group) and paired Wilcoxon (change)" else "none needed")
      cA <- summary(fA)$coefficients; cB <- summary(fB)$coefficients
      ka <- pick_A(rownames(cA), lu); kb <- pick_B(rownames(cB), lu)
      for (i in seq_len(nrow(ka))) {
        x <- ka[i, ]; e <- cA[x$coef, ]
        r <- data.frame(layer = lu$layer, predictor = lu$predictor, contrast = x$contrast, timepoint = x$timepoint, block = lu$block, q_order = qq,
                        n_reference = n_at(lu, x$timepoint, levels(lu$g)[1]), n_level = n_at(lu, x$timepoint, x$level),
                        mean_reference = NA, mean_level = NA, effect = e[["Estimate"]], ci_low = e[["Estimate"]] - 1.96 * e[["Std. Error"]],
                        ci_high = e[["Estimate"]] + 1.96 * e[["Std. Error"]], p = e[["Pr(>|t|)"]], status = NA, reason = NA,
                        method_id = "L01", method_role = "default", caveat = "", adjusted_for = adj$adjusted_for)
        if (fail) {
          a <- dat$h[dat$time == x$timepoint & dat$g == levels(lu$g)[1]]; b <- dat$h[dat$time == x$timepoint & dat$g == x$level]
          r$p <- suppressWarnings(stats::wilcox.test(b, a)$p.value); r$effect <- mean(b) - mean(a); r$ci_low <- NA; r$ci_high <- NA
          r$method_id <- "K02"; r$method_role <- "fallback rung 1"; r$adjusted_for <- "not adjusted (rank test)"
          r$caveat <- sprintf("the mixed model's residual skewness %.2f exceeds R-SKEW, so a Wilcoxon rank-sum test at this timepoint was used", sk)
        }
        A[[length(A) + 1]] <- r
      }
      for (i in seq_len(nrow(kb))) {
        x <- kb[i, ]; e <- cB[x$coef, ]
        r <- data.frame(layer = lu$layer, predictor = lu$predictor, group = x$group, change = x$change, block = lu$block, q_order = qq,
                        n_subjects = length(intersect(lu$subject[lu$g == x$group & lu$time == levels(lu$time)[1]], lu$subject[lu$g == x$group & lu$time == x$time])),
                        effect = e[["Estimate"]], ci_low = e[["Estimate"]] - 1.96 * e[["Std. Error"]], ci_high = e[["Estimate"]] + 1.96 * e[["Std. Error"]],
                        p = e[["Pr(>|t|)"]], method_id = "L01", method_role = "default", caveat = "", adjusted_for = adj$adjusted_for)
        if (fail) {
          pr <- paired_values(dat$h, lu, ok, x$group, x$time)
          r$p <- if (nrow(pr) >= 2) suppressWarnings(stats::wilcox.test(pr$b, pr$a, paired = TRUE)$p.value) else NA
          r$effect <- mean(pr$b - pr$a); r$ci_low <- NA; r$ci_high <- NA
          r$method_id <- "K02p"; r$method_role <- "fallback rung 1"; r$adjusted_for <- "not adjusted (rank test)"
          r$caveat <- sprintf("the mixed model's residual skewness %.2f exceeds R-SKEW, so a paired Wilcoxon test was used", sk)
        }
        B[[length(B) + 1]] <- r
      }
    }
  }
  A <- bind_rows(A); B <- bind_rows(B)
  if (!is.null(A)) { A$q <- stats::ave(A$p, paste(A$layer, A$predictor, A$contrast, A$timepoint, A$block), FUN = bh); A$status <- status_of(A$q) }
  if (!is.null(B)) { B$q <- stats::ave(B$p, paste(B$layer, B$predictor, B$group, B$change, B$block), FUN = bh); B$status <- status_of(B$q) }
  list(results = A, change = B, diagnostics = bind_rows(diag))
}

bh <- function(p) { q <- rep(NA_real_, length(p)); ok <- is.finite(p); q[ok] <- stats::p.adjust(p[ok], "BH"); q }
status_of <- function(q) ifelse(!is.finite(q), "not_testable", ifelse(q <= rule("R-FDR"), "lead", "no_evidence"))

# The same subjects at the first timepoint and at time t, within group l.
paired_values <- function(v, lu, ok, l, t) {
  t0 <- levels(lu$time)[1]
  a <- data.frame(s = lu$subject, v = v, time = lu$time, g = lu$g)[ok, ]
  x <- a[a$g == l & a$time == t0, c("s", "v")]; y <- a[a$g == l & a$time == t, c("s", "v")]
  m <- merge(x, y, by = "s"); names(m) <- c("s", "a", "b"); m
}

# ---- Q4: per feature, NB mixed model with offset (L02) or LinDA with a subject random effect -----

fit_glmm_nb <- function(dat, form, zi = FALSE) {
  tryCatch(suppressWarnings(suppressMessages(glmmTMB::glmmTMB(form, data = dat, family = glmmTMB::nbinom2(), ziformula = if (zi) ~1 else ~0))),
           error = function(e) NULL)
}
glmm_coefs <- function(fit) {
  if (is.null(fit)) return(NULL)
  co <- tryCatch(summary(fit)$coefficients$cond, error = function(e) NULL)
  if (is.null(co) || any(!is.finite(co[, 2]))) NULL else co
}

check_glmm <- function(fit, k) {
  if (is.null(fit)) return(list(failed = TRUE, why = "the mixed model did not converge"))
  sim <- DHARMa::simulateResiduals(fit, n = 250, seed = seed_for(2000 + k), plot = FALSE)
  pu <- DHARMa::testUniformity(sim, plot = FALSE)$p.value; pd <- DHARMa::testDispersion(sim, plot = FALSE)$p.value
  pz <- DHARMa::testZeroInflation(sim, plot = FALSE)$p.value; a <- rule("R-DIAGP")
  why <- c(if (pu < a) "residuals not uniform", if (pd < a) "dispersion not as the model expects", if (pz < a) "more zeros than the model expects")
  list(failed = length(why) > 0, why = paste(why, collapse = "; "), uniformity_p = pu, dispersion_p = pd, zero_inflation_p = pz)
}

chancerep <- function() getOption("seqcompendium.chancerep", rule("R-CHANCEREP"))   # the option is a test hook only

# Chance failure rate of the mixed-model checks (D21, D22): clean NB data from
# each feature's own mean and dispersion (no group or time difference), at
# most R-CHANCEFEAT features, the same model and checks.
glmm_chance <- function(dat_base, y, form) {
  feats <- colnames(y); set.seed(seed_for(47))
  use <- if (length(feats) > rule("R-CHANCEFEAT")) sort(sample(feats, rule("R-CHANCEFEAT"))) else feats
  w <- exp(dat_base$off) / mean(exp(dat_base$off))
  failed <- 0; total <- 0
  for (r in seq_len(chancerep())) for (f in use) {
    rate <- mean(y[, f] / w); v <- stats::var(y[, f] / w); size <- if (v > rate) rate^2 / (v - rate) else 1e4
    d <- dat_base; d$y <- stats::rnbinom(nrow(d), mu = rate * w, size = size)
    if (sum(d$y) == 0) next
    ck <- check_glmm(fit_glmm_nb(d, form), 300000 + 1000 * r + match(f, feats))
    failed <- failed + ck$failed; total <- total + 1
  }
  list(rate = if (total) failed / total else NA_real_, failed = failed, total = total)
}

q4_long <- function(lus, layers, des, choices) {
  res <- list(); chg <- list(); chk <- list(); agr <- list(); desc <- list(); skipped <- list()
  for (lu in lus) {
    L <- layers[[lu$layer]]
    if (L$spec$unit != "count") { skipped[[length(skipped) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, contrast = NA, timepoint = "all", block = lu$block, reason = "Q4 for this unit is built at milestone E8"); next }
    m <- round(wide(L, lu$samples)[lu$samples, , drop = FALSE])
    denom <- !is.null(L$spec$denominators)
    den <- if (denom) as.numeric(L$denominators[[names(L$spec$denominators$columns)[1]]][match(lu$samples, L$denominators$sample)]) else rowSums(m)
    feats <- colnames(m)[vapply(seq_len(ncol(m)), function(k) any(tapply(m[, k] > 0, interaction(lu$g, lu$time), mean) >= rule("R-PREV")), TRUE)]
    adj <- long_cov(lu, des)
    base <- data.frame(time = lu$time, g = lu$g, subject = lu$subject, off = log(den))
    if (!is.null(adj$cov)) base <- cbind(base, adj$cov)
    ct <- cov_terms(adj$cov)
    if (denom) {
      formA <- stats::as.formula(paste("y ~", ct, "time + time:g + offset(off) + (1 | subject)"))
      formB <- stats::as.formula(paste("y ~", ct, "g + g:time + offset(off) + (1 | subject)"))
      fits <- lapply(feats, function(f) { d <- base; d$y <- m[, f]; list(A = fit_glmm_nb(d, formA), B = fit_glmm_nb(d, formB), d = d) })
      names(fits) <- feats
      cks <- lapply(seq_along(feats), function(k) check_glmm(fits[[k]]$A, k))
      failed <- vapply(cks, `[[`, TRUE, "failed")
      cr <- glmm_chance(base, m[, feats, drop = FALSE], formA)
      excess_p <- stats::fisher.test(matrix(c(sum(failed), sum(!failed), cr$failed, cr$total - cr$failed), 2, byrow = TRUE), alternative = "greater")$p.value
      whole <- excess_p < rule("R-EXCESS")
      chk[[length(chk) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, block = lu$block, feature = feats, check = "DHARMa (negative binomial mixed model)",
                                           uniformity_p = vapply(cks, function(x) x$uniformity_p %||% NA_real_, 1), dispersion_p = vapply(cks, function(x) x$dispersion_p %||% NA_real_, 1),
                                           zero_inflation_p = vapply(cks, function(x) x$zero_inflation_p %||% NA_real_, 1), failed = failed, why = vapply(cks, `[[`, "", "why"))
      note <- sprintf("on clean data simulated from this comparison's own features, about %.1f%% of features fail these residual checks by chance; here %d of %d features failed (about %.1f expected by chance), %s. Its result is still valid: it comes from a method that assumes less",
                      100 * cr$rate, sum(failed), length(feats), cr$rate * length(feats), chance_verdict(excess_p))
      for (k in seq_along(feats)) {
        f <- feats[k]; rung <- 0L; cav <- character(0); fA <- fits[[f]]$A; fB <- fits[[f]]$B
        # A default that cannot give usable estimates also goes to rung 1 first.
        unusable <- is.null(glmm_coefs(fA)) || is.null(glmm_coefs(fB))
        if (whole || failed[k] || unusable) {
          rung <- 1L
          if (unusable && !whole && !failed[k]) cav <- c(cav, "the mixed model gave no usable estimates (often a group with no counts at a timepoint), so refitted at rung 1 (zero-inflated negative binomial mixed model)")
          else
          cav <- c(cav, if (whole) sprintf("%d of %d features failed their residual checks, more than in clean simulated data (Fisher's exact p = %.3g < R-EXCESS), so the whole comparison moved to rung 1 (zero-inflated negative binomial mixed model)", sum(failed), length(feats), excess_p)
                        else sprintf("residual checks failed (%s), so refitted at rung 1 (zero-inflated negative binomial mixed model)", cks[[k]]$why), note)
          fA <- fit_glmm_nb(fits[[f]]$d, formA, zi = TRUE); fB <- fit_glmm_nb(fits[[f]]$d, formB, zi = TRUE)
        }
        cA <- glmm_coefs(fA); cB <- glmm_coefs(fB)
        if (rung == 1L && (is.null(cA) || is.null(cB))) { rung <- 2L; cav <- c(cav, "rung 1 did not fit, so rung 2 (permutation tests on CLR at each timepoint, and paired sign-flip permutation for change)") }

        res[[length(res) + 1]] <- long_feature_rows(lu, f, m, cA, rung, cav, "L02", "log2 fold change (negative binomial mixed model), per unit of the denominator", adj, failed[k], sum(failed) / length(feats), cr$rate, excess_p, whole)
        chg[[length(chg) + 1]] <- long_change_rows(lu, f, m, cB, rung, cav, "L02", adj)
      }
    } else {
      fl <- function(form) {
        utils::capture.output(o <- suppressMessages(suppressWarnings(MicrobiomeStat::linda(feature.dat = t(m[, feats, drop = FALSE]),
          meta.dat = data.frame(base[, setdiff(names(base), "off"), drop = FALSE], row.names = lu$samples), formula = form, feature.dat.type = "count",
          prev.filter = 0, mean.abund.filter = 0, max.abund.filter = 0))))
        o$output
      }
      oA <- tryCatch(fl(paste("~", ct, "time + time:g + (1 | subject)")), error = function(e) NULL)
      oB <- tryCatch(fl(paste("~", ct, "g + g:time + (1 | subject)")), error = function(e) NULL)
      ud <- list(m = m, g = interaction(lu$g, lu$time), den = NULL, lib = rowSums(m), samples = lu$samples, cov = NULL)
      cks <- do.call(rbind, lapply(feats, function(f) check_lm_clr(ud, f)))
      cr <- chance_failure_rate(ud, feats, FALSE)
      excess_p <- stats::fisher.test(matrix(c(sum(cks$failed), sum(!cks$failed), cr$failed, cr$total - cr$failed), 2, byrow = TRUE), alternative = "greater")$p.value
      whole <- excess_p < rule("R-EXCESS")
      chk[[length(chk) + 1]] <- cbind(data.frame(layer = lu$layer, predictor = lu$predictor, block = lu$block), cks)
      for (k in seq_along(feats)) {
        f <- feats[k]; moved <- whole || cks$failed[k] || is.null(oA) || is.null(oB)
        cA <- if (!moved) lin_coefs(oA, f) else NULL; cB <- if (!moved) lin_coefs(oB, f) else NULL
        cav <- if (moved) c(if (whole) sprintf("%d of %d features failed their residual checks, more than in clean simulated data (Fisher's exact p = %.3g < R-EXCESS), so the whole comparison moved", sum(cks$failed), length(feats), excess_p)
                            else if (cks$failed[k]) sprintf("residual checks failed (%s)", cks$why[k]) else "LinDA did not fit",
                            "refitted by Welch tests on CLR at each timepoint (rung 1) and paired t-tests for change") else character(0)
        res[[length(res) + 1]] <- long_feature_rows(lu, f, m, cA, if (moved) 1L else 0L, cav, "D09re", "log2 fold change (LinDA, subject random effect)", adj, cks$failed[k], mean(cks$failed), cr$rate, excess_p, whole, linda = TRUE)
        chg[[length(chg) + 1]] <- long_change_rows(lu, f, m, cB, if (moved) 1L else 0L, cav, "D09re", adj, linda = TRUE)
      }
    }
    agr[[length(agr) + 1]] <- long_agreement(lu, m, feats, adj, des)
    for (t in levels(lu$time)) {
      i <- lu$time == t
      if (length(unique(lu$g[i])) < 2) next
      lf <- describe_lefse(list(m = m[i, , drop = FALSE], g = droplevels(lu$g[i]), samples = lu$samples[i]), feats)
      desc[[length(desc) + 1]] <- cbind(data.frame(layer = lu$layer, predictor = lu$predictor, contrast = sprintf("%s vs %s", levels(lu$g)[2], levels(lu$g)[1]), timepoint = t, block = lu$block),
                                        method_id = "D19", lf, role = "describe_only")
    }
  }
  r <- bind_rows(res); cg <- bind_rows(chg)
  if (!is.null(r)) { r$q <- stats::ave(r$p, paste(r$layer, r$predictor, r$contrast, r$timepoint, r$block), FUN = bh); r$status <- status_of(r$q) }
  if (!is.null(cg)) { cg$q <- stats::ave(cg$p, paste(cg$layer, cg$predictor, cg$group, cg$change, cg$block), FUN = bh); cg$status <- status_of(cg$q) }
  list(results = r, change = cg, checks = bind_rows(chk), agreement = bind_rows(agr), describe = bind_rows(desc), skipped = bind_rows(skipped))
}

lin_coefs <- function(o, f) {
  if (is.null(o)) return(NULL)
  do.call(rbind, lapply(names(o), function(k) { x <- o[[k]]; if (!f %in% rownames(x)) return(NULL)
    data.frame(row.names = k, Estimate = x[f, "log2FoldChange"], SE = x[f, "lfcSE"], p = x[f, "pvalue"]) }))
}

# Per-timepoint group contrasts for one feature, from the model (rung 0/1) or
# from per-timepoint tests on CLR (rung 2 for the NB model; rung 1 for LinDA).
long_feature_rows <- function(lu, f, m, co, rung, cav, mid, unit, adj, failed, share, chance, excess_p, whole, linda = FALSE) {
  z <- clr(m)[, f]; out <- list()
  for (t in levels(lu$time)) for (l in levels(lu$g)[-1]) {
    k <- sprintf("time%s:g%s", t, l); a <- lu$time == t & lu$g == levels(lu$g)[1]; b <- lu$time == t & lu$g == l
    if (!any(b) || !any(a)) next
    use_model <- !is.null(co) && k %in% rownames(co)
    if (use_model) {
      e <- co[k, 1]; se <- co[k, 2]; p <- co[k, ncol(co)]
      if (!linda) { e <- e / log(2); se <- se / log(2) }
      role <- if (rung == 0) "default" else "fallback rung 1"; id <- if (rung == 0) mid else if (linda) "K01" else "R02mm"
    } else {
      if (linda || rung >= 1) {
        tt <- tryCatch(stats::t.test(z[b], z[a]), error = function(e) NULL)
        e <- mean(z[b]) - mean(z[a]); se <- if (is.null(tt)) NA else tt$stderr; p <- if (is.null(tt)) NA else tt$p.value
        id <- if (linda) "K01" else "K04"; role <- sprintf("fallback rung %d", if (linda) 1 else 2)
        if (!linda) { set.seed(seed_for(48)); obs <- e; ab <- c(which(a), which(b)); perm <- replicate(rule("R-PERM"), { s <- sample(ab); mean(z[s[seq_len(sum(b))]]) - mean(z[s[-seq_len(sum(b))]]) })
          p <- (1 + sum(abs(perm) >= abs(obs) - 1e-12)) / (rule("R-PERM") + 1); se <- NA }
      }
    }
    out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, contrast = sprintf("%s vs %s", l, levels(lu$g)[1]), timepoint = t, block = lu$block,
                                         feature = f, effect = e, se = se, stat = NA_real_, p = p,
                                         effect_unit = if (use_model) unit else "difference in mean CLR", rung = if (use_model) rung else max(rung, 1L),
                                         method_role = role, caveat = paste(cav, collapse = "; "), ci_low = e - 1.96 * se, ci_high = e + 1.96 * se,
                                         method_id = id, n_reference = sum(a), n_level = sum(b), share_expected_by_chance = chance, excess_failures_p = excess_p,
                                         adjusted_for = if (use_model) adj$adjusted_for else "not adjusted (per-timepoint test on CLR)",
                                         share_failed_checks = share, whole_question_moved = whole)
  }
  bind_rows(out)
}

# Change from the first timepoint within each group, for one feature.
long_change_rows <- function(lu, f, m, co, rung, cav, mid, adj, linda = FALSE) {
  z <- clr(m)[, f]; out <- list()
  for (l in levels(lu$g)) for (t in levels(lu$time)[-1]) {
    k <- sprintf("g%s:time%s", l, t)
    pr <- paired_values(z, lu, rep(TRUE, length(z)), l, t)
    use_model <- !is.null(co) && k %in% rownames(co)
    if (use_model) {
      e <- co[k, 1]; se <- co[k, 2]; p <- co[k, ncol(co)]; if (!linda) { e <- e / log(2); se <- se / log(2) }
      id <- if (rung == 0) mid else "R02mm"; role <- if (rung == 0) "default" else "fallback rung 1"
    } else if (nrow(pr) >= 2) {
      dlt <- pr$b - pr$a; e <- mean(dlt); se <- stats::sd(dlt) / sqrt(length(dlt))
      if (linda) { p <- tryCatch(stats::t.test(dlt)$p.value, error = function(e) NA); id <- "K01p"; role <- "fallback rung 1" }
      else { set.seed(seed_for(49)); perm <- replicate(rule("R-PERM"), mean(dlt * sample(c(-1, 1), length(dlt), TRUE)))
             p <- (1 + sum(abs(perm) >= abs(e) - 1e-12)) / (rule("R-PERM") + 1); id <- "K04p"; role <- "fallback rung 2" }
    } else next
    out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, group = l, change = sprintf("%s vs %s", t, levels(lu$time)[1]), block = lu$block,
                                         feature = f, effect = e, ci_low = e - 1.96 * se, ci_high = e + 1.96 * se, p = p, n_subjects = nrow(pr),
                                         effect_unit = if (use_model) (if (linda) "log2 fold change (LinDA)" else "log2 fold change (NB mixed model)") else "mean paired change in CLR",
                                         method_id = id, method_role = role, caveat = paste(cav, collapse = "; "),
                                         adjusted_for = if (use_model) adj$adjusted_for else "not adjusted (paired test)")
  }
  bind_rows(out)
}

# Alternatives: Wilcoxon on CLR within each timepoint (group contrasts),
# paired Wilcoxon (change), GEE when subjects >= R-GEE (C8).
long_agreement <- function(lu, m, feats, adj, des) {
  z <- clr(m); out <- list(); nsub <- length(unique(lu$subject))
  for (f in feats) {
    for (t in levels(lu$time)) for (l in levels(lu$g)[-1]) {
      a <- lu$time == t & lu$g == levels(lu$g)[1]; b <- lu$time == t & lu$g == l
      if (sum(a) < 2 || sum(b) < 2) next
      out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, contrast = sprintf("%s vs %s", l, levels(lu$g)[1]), timepoint = t, block = lu$block,
                                           feature = f, method_id = "D17", effect = mean(z[b, f]) - mean(z[a, f]), p = suppressWarnings(stats::wilcox.test(z[b, f], z[a, f])$p.value), note = "")
    }
    if (nsub >= rule("R-GEE")) {
      d <- data.frame(y = z[, f], time = lu$time, g = lu$g, subject = as.integer(lu$subject)); if (!is.null(adj$cov)) d <- cbind(d, adj$cov)
      d <- d[order(d$subject), ]
      ge <- tryCatch(summary(geepack::geeglm(stats::as.formula(paste("y ~", cov_terms(adj$cov), "time + time:g")), id = subject, data = d, corstr = "exchangeable"))$coefficients, error = function(e) NULL)
      for (t in levels(lu$time)) for (l in levels(lu$g)[-1]) {
        k <- sprintf("time%s:g%s", t, l)
        out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, contrast = sprintf("%s vs %s", l, levels(lu$g)[1]), timepoint = t, block = lu$block,
                                             feature = f, method_id = "L03", effect = if (!is.null(ge) && k %in% rownames(ge)) ge[k, 1] else NA,
                                             p = if (!is.null(ge) && k %in% rownames(ge)) ge[k, 4] else NA, note = if (is.null(ge)) "GEE did not fit" else "")
      }
    }
  }
  r <- bind_rows(out)
  if (!is.null(r)) { r$q <- stats::ave(r$p, paste(r$layer, r$predictor, r$contrast, r$timepoint, r$block, r$method_id), FUN = bh); r$call <- !is.na(r$q) & r$q <= rule("R-FDR") }
  r
}

# Q6 agreement: paired Wilcoxon on CLR (features) or on Hill numbers (Q2);
# GAMM for Q2 when there are 4 or more timepoints (L04).
change_agreement_features <- function(lus, layers) {
  out <- list()
  for (lu in lus) {
    L <- layers[[lu$layer]]; if (L$spec$unit != "count") next
    m <- round(wide(L, lu$samples)[lu$samples, , drop = FALSE]); z <- clr(m)
    for (f in colnames(m)) for (l in levels(lu$g)) for (t in levels(lu$time)[-1]) {
      pr <- paired_values(z[, f], lu, rep(TRUE, nrow(z)), l, t); if (nrow(pr) < 3) next
      out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, group = l, change = sprintf("%s vs %s", t, levels(lu$time)[1]), block = lu$block,
                                           feature = f, method_id = "K02p", effect = mean(pr$b - pr$a), p = suppressWarnings(stats::wilcox.test(pr$b, pr$a, paired = TRUE)$p.value), note = "")
    }
  }
  r <- bind_rows(out)
  if (!is.null(r)) { r$q <- stats::ave(r$p, paste(r$layer, r$predictor, r$group, r$change, r$block), FUN = bh); r$call <- !is.na(r$q) & r$q <= rule("R-FDR") }
  r
}

change_agreement_alpha <- function(lus, q2_per_sample) {
  out <- list()
  for (lu in lus) {
    ps <- q2_per_sample[q2_per_sample$layer == lu$layer, ]
    for (qq in 0:2) {
      h <- ps$hill[ps$q_order == qq][match(lu$samples, ps$sample[ps$q_order == qq])]; ok <- !is.na(h)
      for (l in levels(lu$g)) for (t in levels(lu$time)[-1]) {
        pr <- paired_values(h, lu, ok, l, t); if (nrow(pr) < 3) next
        out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, group = l, change = sprintf("%s vs %s", t, levels(lu$time)[1]), block = lu$block,
                                             q_order = qq, method_id = "K02p", effect = mean(pr$b - pr$a), p = suppressWarnings(stats::wilcox.test(pr$b, pr$a, paired = TRUE)$p.value), note = "")
      }
      if (nlevels(lu$time) >= 4) {
        d <- data.frame(h = h, tn = as.integer(lu$time), g = lu$g, subject = lu$subject)[ok, ]
        gm <- tryCatch(suppressWarnings(mgcv::gamm(h ~ g + s(tn, by = g, k = min(4, nlevels(lu$time))), random = list(subject = ~1), data = d)), error = function(e) NULL)
        st <- if (is.null(gm)) NULL else summary(gm$gam)$s.table
        for (l in levels(lu$g)) for (t in levels(lu$time)[-1]) {
          k <- sprintf("s(tn):g%s", l)
          pr <- paired_values(h, lu, ok, l, t)
          out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, group = l, change = sprintf("%s vs %s", t, levels(lu$time)[1]), block = lu$block,
                                               q_order = qq, method_id = "L04", effect = if (nrow(pr)) mean(pr$b - pr$a) else NA,
                                               p = if (!is.null(st) && k %in% rownames(st)) st[k, "p-value"] else NA,
                                               note = if (is.null(st)) "GAMM did not fit" else "GAMM smooth of time within the group (one test per group, shown at each change)")
        }
      }
    }
  }
  r <- bind_rows(out)
  if (!is.null(r)) { r$q <- stats::ave(r$p, paste(r$layer, r$predictor, r$group, r$change, r$block, r$method_id), FUN = bh); r$call <- !is.na(r$q) & r$q <= rule("R-FDR") }
  r
}

# Q6 composition: PERMANOVA of each later timepoint against the first, within
# each group, permutations restricted within subject (design section 5.2).
q6_composition <- function(lus, layers) {
  out <- list()
  for (lu in lus) {
    L <- layers[[lu$layer]]; if (L$spec$unit != "count") next
    m <- round(wide(L, lu$samples)[lu$samples, , drop = FALSE])
    for (l in levels(lu$g)) for (t in levels(lu$time)[-1]) {
      t0 <- levels(lu$time)[1]
      s0 <- lu$subject[lu$g == l & lu$time == t0]; s1 <- lu$subject[lu$g == l & lu$time == t]; both <- intersect(s0, s1)
      if (length(both) < 3) next
      i <- lu$g == l & lu$time %in% c(t0, t) & lu$subject %in% both
      mm <- m[i, colSums(m[i, , drop = FALSE]) > 0, drop = FALSE]; tt <- droplevels(lu$time[i]); sj <- droplevels(lu$subject[i])
      d <- vegan::vegdist(mm, "robust.aitchison")
      set.seed(seed_for(61))
      pm <- suppressMessages(vegan::adonis2(d ~ tt, data = data.frame(tt = tt), permutations = permute::how(blocks = sj, nperm = rule("R-PERM"))))
      out[[length(out) + 1]] <- data.frame(layer = lu$layer, predictor = lu$predictor, group = l, change = sprintf("%s vs %s", t, t0), block = lu$block,
                                           n_subjects = length(both), effect = pm$R2[1], p = pm[["Pr(>F)"]][1], effect_unit = "PERMANOVA R-squared (permutations within subject)",
                                           method_id = "B06s", method_role = "default", caveat = "", adjusted_for = "not adjusted (PERMANOVA within subject)")
    }
  }
  r <- bind_rows(out)
  if (!is.null(r)) { r$q <- stats::ave(r$p, paste(r$layer, r$predictor, r$group, r$block), FUN = bh); r$status <- status_of(r$q) }
  r
}
