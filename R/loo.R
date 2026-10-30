# loo.R: leave-one-out on every lead (design section 6, X03; CLAUDE.md D29a).
#
# A lead is refitted by its own method with each study sample of its
# comparison left out in turn. It is unstable if its effect changes sign, or
# if its p-value rises past the point where its q would leave R-FDR, the
# other results held fixed. The
# result names the sample. Non-leads are not refitted. (The bound is the
# Benjamini-Hochberg line, CLAUDE.md D30.)

loo_verdict <- function(effect, p, worst, rows) {
  # rows: data.frame(sample, effect, p) for each sample left out
  rows <- rows[is.finite(rows$p) & is.finite(rows$effect), , drop = FALSE]
  if (!nrow(rows)) return("not run: no refit could be made")
  flip <- rows$sample[sign(rows$effect) != sign(effect)]
  rise <- rows$sample[rows$p > worst]
  if (length(flip)) return(sprintf("no: depends on sample %s (the effect changes sign without it)", flip[1]))
  if (length(rise)) return(sprintf("no: depends on sample %s (without it p = %.3g, above %.3g)", rise[1], max(rows$p[rows$sample == rise[1]]), worst))
  "yes"
}

# The p-value up to which a lead stays a lead with the other results held
# fixed: Benjamini-Hochberg rejects every p at or below R-FDR x k / m, where
# k is the family's number of leads and m its number of tests (CLAUDE.md D30).
family_worst <- function(r, by) {
  key <- do.call(paste, c(r[by], sep = "\r"))
  k <- tapply(r$status == "lead", key, sum); m <- tapply(is.finite(r$p), key, sum)
  unname((rule("R-FDR") * k / m)[key])
}

drop_sample <- function(u, s) { u$ref_samples <- setdiff(u$ref_samples, s); u$level_samples <- setdiff(u$level_samples, s); u }

find_unit <- function(units, x) {
  for (u in units) if (isTRUE(u$testable) && u$layer == x$layer && u$predictor == x$predictor && identical(u$contrast, x$contrast) &&
                       u$timepoint == x$timepoint && u$block == x$block) return(u)
  NULL
}

# ---- snapshot questions ------------------------------------------------------

loo_q2_snapshot <- function(r, units, per_sample, des) {
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  worst <- family_worst(r, c("layer", "predictor", "contrast", "timepoint", "block"))
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; u <- find_unit(units, x); if (is.null(u)) { r$loo_stable[i] <- "not run: comparison not found"; next }
    ps <- per_sample[per_sample$layer == x$layer & per_sample$q_order == x$q_order, ]
    rows <- do.call(rbind, lapply(c(u$ref_samples, u$level_samples), function(s) {
      a <- ps$hill[match(setdiff(u$ref_samples, s), ps$sample)]; b <- ps$hill[match(setdiff(u$level_samples, s), ps$sample)]
      if (x$method_id == "K02") return(data.frame(sample = s, effect = mean(b) - mean(a), p = suppressWarnings(stats::wilcox.test(b, a)$p.value)))
      if (x$method_id == "A02lm") {
        sa <- setdiff(u$ref_samples, s); sb <- setdiff(u$level_samples, s); gg <- factor(rep(c(u$reference, u$level), c(length(sa), length(sb))), levels = c(u$reference, u$level))
        adj <- adjustment_for(c(sa, sb), des, x$predictor, stats::model.matrix(~ gg))
        f <- stats::lm(stats::as.formula(paste("h ~", cov_terms(adj$cov), "gg")), data.frame(h = c(a, b), if (!is.null(adj$cov)) adj$cov, gg = gg))
        co <- summary(f)$coefficients; k <- paste0("gg", u$level); return(data.frame(sample = s, effect = co[k, 1], p = co[k, 4]))
      }
      t <- tryCatch(stats::t.test(b, a), error = function(e) NULL)
      data.frame(sample = s, effect = mean(b) - mean(a), p = if (is.null(t)) NA else t$p.value)
    }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}

loo_q3 <- function(r, units, layers, des) {
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  worst <- family_worst(r, c("layer", "predictor", "timepoint", "block"))
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; u <- find_unit(units, x); if (is.null(u)) next
    rows <- do.call(rbind, lapply(c(u$ref_samples, u$level_samples), function(s) {
      ud <- unit_data(drop_sample(u, s), layers[[u$layer]], des); m <- ud$m[, colSums(ud$m) > 0, drop = FALSE]
      dat <- if (is.null(ud$cov)) data.frame(g = ud$g) else data.frame(ud$cov, g = ud$g)
      if (x$primary == "B14 mvabund") {
        set.seed(seed_for(33)); dat$Y <- mvabund::mvabund(round(m))
        fit <- mvabund::manyglm(stats::as.formula(paste("Y ~", cov_terms(ud$cov), "g")), data = dat, family = "negative.binomial", offset = log(offset_of(ud)))
        a <- mvabund::anova.manyglm(fit, nBoot = rule("R-BOOT"), resamp = "pit.trap", test = "LR", show.time = "none"); k <- nrow(a$table)
        return(data.frame(sample = s, effect = a$table[k, "Dev"], p = a$table[k, "Pr(>Dev)"]))
      }
      d <- vegan::vegdist(m, method = "robust.aitchison")
      set.seed(seed_for(31)); pm <- vegan::adonis2(stats::as.formula(paste("d ~", cov_terms(ud$cov), "g")), data = dat, permutations = rule("R-PERM"), by = "margin")
      data.frame(sample = s, effect = pm["g", "R2"], p = pm["g", "Pr(>F)"])
    }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}

# Q4 (snapshot): the lead's own method refitted without each sample. Methods
# that fit all features at once are refitted once per left-out sample for all
# of a comparison's leads together.
loo_q4_snapshot <- function(r, units, layers, des) {
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  worst <- family_worst(r, c("layer", "predictor", "contrast", "timepoint", "block"))
  key <- paste(r$layer, r$predictor, r$contrast, r$timepoint, r$block)
  for (k in unique(key[r$status == "lead"])) {
    idx <- which(key == k & r$status == "lead"); x <- r[idx[1], ]
    u <- find_unit(units, x); if (is.null(u)) next
    feats <- r$feature[key == k]
    per <- lapply(c(u$ref_samples, u$level_samples), function(s) {
      ud <- unit_data(drop_sample(u, s), layers[[u$layer]], des); ids <- unique(r$method_id[idx]); out <- list()
      for (id in ids) {
        fi <- r$feature[idx][r$method_id[idx] == id]
        res <- if (id %in% names(FITS)) tryCatch(suppressMessages(suppressWarnings(FITS[[id]](ud, feats))), error = function(e) NULL)
               else do.call(rbind, lapply(fi, function(f) tryCatch(switch(id, R02 = fit_zinb(ud, f), K04 = fit_perm_clr(ud, f), K01 = fit_welch_clr(ud, f)), error = function(e) NULL)))
        if (!is.null(res)) out[[id]] <- cbind(sample = s, res[res$feature %in% fi, c("feature", "effect", "p")])
      }
      do.call(rbind, out)
    })
    per <- do.call(rbind, per)
    for (i in idx) r$loo_stable[i] <- loo_verdict(r$effect[i], r$p[i], worst[i], if (is.null(per)) data.frame(sample = character(0), effect = numeric(0), p = numeric(0)) else per[per$feature == r$feature[i], ])
  }
  r
}

loo_q5 <- function(r, units, layers, des) {
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  worst <- family_worst(r, c("layer", "predictor", "contrast", "timepoint", "block"))
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; u <- find_unit(units, x); if (is.null(u)) next
    rows <- do.call(rbind, lapply(c(u$ref_samples, u$level_samples), function(s) {
      ud <- unit_data(drop_sample(u, s), layers[[u$layer]], des); y <- as.integer(ud$m[, x$feature] > 0)
      dat <- if (is.null(ud$cov)) data.frame(y = y, g = ud$g) else data.frame(y = y, ud$cov, g = ud$g)
      fml <- stats::as.formula(paste("y ~", cov_terms(ud$cov), "g")); k <- paste0("g", u$level)
      if (length(unique(y)) < 2) return(data.frame(sample = s, effect = NA, p = NA))
      if (x$method_id == "G06") { j <- which(colnames(stats::model.matrix(fml, dat)) == k); f <- logistf::logistf(fml, data = dat, plconf = j)
        return(data.frame(sample = s, effect = unname(f$coefficients[j]), p = unname(f$prob[j]))) }
      co <- summary(suppressWarnings(stats::glm(fml, data = dat, family = stats::binomial())))$coefficients
      data.frame(sample = s, effect = co[k, 1], p = co[k, 4])
    }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}

# Q7 (snapshot): Q4's final method refitted without each sample, the same
# signed z-scores, fgsea again.
loo_q7 <- function(r, units, layers, des, q4, long) {
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  if (long) { r$loo_stable[r$status == "lead"] <- "not run: in a longitudinal design this needs every feature's mixed model refitted for each left-out sample"; return(r) }
  worst <- family_worst(r, c("layer", "predictor", "contrast", "timepoint", "block", "set_column"))
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; u <- find_unit(units, x); if (is.null(u)) next
    q4u <- q4$results[q4$results$layer == x$layer & q4$results$predictor == x$predictor & q4$results$contrast == x$contrast &
                      q4$results$timepoint == x$timepoint & q4$results$block == x$block, ]
    id <- names(sort(table(q4u$method_id), decreasing = TRUE))[1]
    if (!id %in% names(FITS)) { r$loo_stable[i] <- "not run: Q4 used a fallback for most features here"; next }
    L <- layers[[x$layer]]; fs <- L$features
    rows <- do.call(rbind, lapply(c(u$ref_samples, u$level_samples), function(s) {
      ud <- unit_data(drop_sample(u, s), L, des)
      res <- tryCatch(suppressMessages(suppressWarnings(FITS[[id]](ud, q4u$feature))), error = function(e) NULL)
      if (is.null(res)) return(data.frame(sample = s, effect = NA, p = NA))
      z <- stats::setNames(sign(res$effect) * stats::qnorm(pmax(res$p, 1e-300) / 2, lower.tail = FALSE), res$feature); z <- z[is.finite(z)]
      sets <- split(fs$feature[match(names(z), fs$feature)], fs[[x$set_column]][match(names(z), fs$feature)])
      set.seed(seed_for(71))
      fg <- suppressWarnings(fgsea::fgsea(pathways = sets[x$feature], stats = sort(z + seq_along(z) * 1e-10, decreasing = TRUE), minSize = 2, maxSize = 1000, eps = 0, nproc = 1))
      data.frame(sample = s, effect = if (nrow(fg)) fg$NES[1] else NA, p = if (nrow(fg)) fg$pval[1] else NA)
    }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}

# ---- longitudinal questions ----------------------------------------------------

lu_minus <- function(lu, s) { k <- lu$samples != s
  list(layer = lu$layer, predictor = lu$predictor, block = lu$block, samples = lu$samples[k], g = droplevels(lu$g[k]),
       time = droplevels(lu$time[k]), subject = droplevels(lu$subject[k])) }
find_lu <- function(lus, x) { for (lu in lus) if (lu$layer == x$layer && lu$predictor == x$predictor && lu$block == x$block) return(lu); NULL }

# One mixed-model coefficient for one feature (or the Hill numbers) without sample s.
long_refit <- function(lu, s, y, coef, des, family = c("lmer", "nb", "zinb"), den = NULL, param = c("A", "B")) {
  family <- match.arg(family); param <- match.arg(param)
  l2 <- lu_minus(lu, s); k <- lu$samples != s
  adj <- long_cov(l2, des); ct <- cov_terms(adj$cov)
  d <- data.frame(y = y[k], time = l2$time, g = l2$g, subject = l2$subject); if (!is.null(adj$cov)) d <- cbind(d, adj$cov)
  rhs <- if (param == "A") "time + time:g" else "g + g:time"
  if (family == "lmer") {
    f <- tryCatch(suppressMessages(lmerTest::lmer(stats::as.formula(paste("y ~", ct, rhs, "+ (1 | subject)")), d)), error = function(e) NULL)
    co <- if (is.null(f)) NULL else summary(f)$coefficients
    if (is.null(co) || !coef %in% rownames(co)) return(c(effect = NA, p = NA))
    return(c(effect = co[coef, "Estimate"], p = co[coef, "Pr(>|t|)"]))
  }
  d$off <- log(den[k])
  co <- glmm_coefs(fit_glmm_nb(d, stats::as.formula(paste("y ~", ct, rhs, "+ offset(off) + (1 | subject)")), zi = family == "zinb"))
  if (is.null(co) || !coef %in% rownames(co)) return(c(effect = NA, p = NA))
  c(effect = co[coef, 1] / log(2), p = co[coef, ncol(co)])
}

loo_long <- function(r, lus, layers, des, q2_per_sample, kind = c("q2", "q4", "q6a", "q6f")) {
  kind <- match.arg(kind)
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  by <- if (kind %in% c("q2", "q4")) c("layer", "predictor", "contrast", "timepoint", "block") else c("layer", "predictor", "group", "change", "block")
  worst <- family_worst(r, by)
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; lu <- find_lu(lus, x); if (is.null(lu)) next
    param <- if (kind %in% c("q2", "q4")) "A" else "B"
    coef <- if (param == "A") sprintf("time%s:g%s", x$timepoint, sub(" vs .*$", "", x$contrast)) else sprintf("g%s:time%s", x$group, sub(" vs .*$", "", x$change))
    if (kind %in% c("q2", "q6a")) {
      ps <- q2_per_sample[q2_per_sample$layer == x$layer & q2_per_sample$q_order == x$q_order, ]
      y <- ps$hill[match(lu$samples, ps$sample)]; fam <- "lmer"; den <- NULL
      if (!x$method_id %in% c("L01")) { r$loo_stable[i] <- "not run: this result came from a fallback test"; next }
    } else {
      L <- layers[[x$layer]]; m <- round(wide(L, lu$samples)[lu$samples, , drop = FALSE]); y <- m[, x$feature]
      den <- if (!is.null(L$spec$denominators)) as.numeric(L$denominators[[names(L$spec$denominators$columns)[1]]][match(lu$samples, L$denominators$sample)]) else rowSums(m)
      fam <- switch(x$method_id, L02 = "nb", R02mm = "zinb", NA)
      if (is.na(fam)) { r$loo_stable[i] <- sprintf("not run: leave-one-out for %s is built for the mixed models only", x$method_id); next }
    }
    rows <- do.call(rbind, lapply(lu$samples, function(s) { v <- long_refit(lu, s, y, coef, des, fam, den, param); data.frame(sample = s, effect = v[["effect"]], p = v[["p"]]) }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}

loo_q6_composition <- function(r, lus, layers) {
  if (is.null(r) || !nrow(r)) return(r)
  r$loo_stable <- "not needed (not a lead)"
  if (is.null(r) || !any(r$status == "lead")) return(r)
  worst <- family_worst(r, c("layer", "predictor", "group", "block"))
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; lu <- find_lu(lus, x); if (is.null(lu)) next
    t <- sub(" vs .*$", "", x$change)
    rows <- do.call(rbind, lapply(lu$samples[lu$g == x$group & lu$time %in% c(levels(lu$time)[1], t)], function(s) {
      q <- q6_composition(list(lu_minus(lu, s)), layers)
      q <- if (is.null(q)) NULL else q[q$group == x$group & q$change == x$change, ]
      data.frame(sample = s, effect = if (is.null(q) || !nrow(q)) NA else q$effect, p = if (is.null(q) || !nrow(q)) NA else q$p)
    }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}
