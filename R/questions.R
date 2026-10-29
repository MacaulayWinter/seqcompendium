# questions.R: Q0, Q3, Q5 and Q7 (design sections 5.2 and 6), and the Q2
# agreement set. S1 counts, each timepoint and block on its own.

bind_rows <- function(l) { l <- Filter(Negate(is.null), l); if (length(l)) do.call(rbind, l) else NULL }

# Q0: which features look like contaminants? decontam's prevalence method,
# negative controls (F8) against study samples. Flagged features are never
# removed (C24): they carry a flag, and their leads cannot reach tier 1.
q0_contaminants <- function(layers, des) {
  neg <- des$controls$sample[grepl("^negative_", des$controls$kind)]
  if (!length(neg)) return(NULL)
  bind_rows(lapply(names(layers), function(nm) {
    L <- layers[[nm]]
    if (L$spec$unit != "count") return(NULL)
    s <- c(des$study$sample, neg)
    m <- wide(L, s); m <- m[intersect(s, rownames(m)), , drop = FALSE]
    is_neg <- rownames(m) %in% neg
    x <- suppressWarnings(decontam::isContaminant(m, neg = is_neg, method = "prevalence", threshold = 0.1))
    data.frame(layer = nm, feature = rownames(x), prevalence_in_negatives = colMeans(m[is_neg, , drop = FALSE] > 0),
               prevalence_in_study_samples = colMeans(m[!is_neg, , drop = FALSE] > 0), decontam_score = x$p,
               possible_contaminant = x$contaminant %in% TRUE, row.names = NULL)
  }))
}

# Q3: does overall composition differ? PERMANOVA on robust Aitchison
# distance, always with betadisper. When spread differs and groups are
# unbalanced, location and spread cannot be separated, and mvabund is the
# primary (design section 6).
q3_composition <- function(units, layers) {
  res <- list(); agr <- list(); ord <- list(); notes <- list()
  for (i in seq_along(units)) {
    u <- units[[i]]; key <- unit_key(u); L <- layers[[u$layer]]
    if (L$spec$unit != "count") { notes[[i]] <- cbind(key, reason = sprintf("Q3 for unit %s is built at milestone E8", L$spec$unit)); next }
    if (!u$testable) { notes[[i]] <- cbind(key, reason = u$reason); next }
    ud <- unit_data(u, L); m <- ud$m[, colSums(ud$m) > 0, drop = FALSE]; g <- ud$g
    d <- vegan::vegdist(m, method = "robust.aitchison")
    set.seed(seed_for(31)); pm <- vegan::adonis2(d ~ g, data = data.frame(g = g), permutations = rule("R-PERM"))
    bd <- vegan::betadisper(d, g)
    set.seed(seed_for(32)); bp <- vegan::permutest(bd, permutations = rule("R-PERM"))$tab[1, "Pr(>F)"]
    n <- table(g); unbalanced <- max(n) / min(n) > rule("R-UNBAL"); spread <- bp < rule("R-DIAGP")
    mv <- tryCatch({
      set.seed(seed_for(33))
      fit <- mvabund::manyglm(mvabund::mvabund(round(m)) ~ g, family = "negative.binomial", offset = log(offset_of(ud)))
      a <- mvabund::anova.manyglm(fit, nBoot = rule("R-BOOT"), resamp = "pit.trap", test = "LR", show.time = "none")
      c(stat = a$table[2, "Dev"], p = a$table[2, "Pr(>Dev)"])
    }, error = function(e) c(stat = NA, p = NA))
    primary_mv <- spread && unbalanced
    res[[i]] <- cbind(key, permanova_r2 = pm$R2[1], permanova_F = pm$F[1], permanova_p = pm[["Pr(>F)"]][1],
                      betadisper_p = bp, group_sizes = paste(sprintf("%s=%d", names(n), as.vector(n)), collapse = "; "),
                      unbalanced = unbalanced, spread_differs = spread,
                      primary = if (primary_mv) "B14 mvabund" else "B06 PERMANOVA",
                      method_role = if (primary_mv) "fallback: spread differs and groups are unbalanced" else "default",
                      p = if (primary_mv) mv[["p"]] else pm[["Pr(>F)"]][1], effect = if (primary_mv) mv[["stat"]] else pm$R2[1],
                      effect_unit = if (primary_mv) "mvabund likelihood-ratio deviance" else "PERMANOVA R-squared",
                      caveat = if (primary_mv) sprintf("location and spread cannot be separated (betadisper differs and groups are unbalanced), so mvabund is the primary; betadisper fires by chance in about %.0f%% of comparisons whose spread is really equal, so this is a precaution, not proof that spread differs", 100 * rule("R-DIAGP")) else "",
                      n_reference = length(u$ref_samples), n_level = length(u$level_samples))
    # Agreement: Bray-Curtis on rarefied counts (C12), mvabund. Describe only: ANOSIM, SIMPER.
    set.seed(seed_for(34)); rr <- vegan::rrarefy(round(m), min(rowSums(round(m))))
    set.seed(seed_for(35)); bc <- vegan::adonis2(vegan::vegdist(rr, "bray") ~ g, data = data.frame(g = g), permutations = rule("R-PERM"))
    set.seed(seed_for(36)); an <- vegan::anosim(d, g, permutations = rule("R-PERM"))
    sp <- summary(vegan::simper(m, g, permutations = 0))[[1]]
    agr[[i]] <- rbind(cbind(key, method_id = "B01", role = "agreement", stat = bc$R2[1], p = bc[["Pr(>F)"]][1], note = "Bray-Curtis on rarefied counts"),
                      cbind(key, method_id = "B14", role = if (primary_mv) "primary" else "agreement", stat = mv[["stat"]], p = mv[["p"]], note = "mvabund LR test"),
                      cbind(key, method_id = "B06", role = if (primary_mv) "agreement" else "primary", stat = pm$R2[1], p = pm[["Pr(>F)"]][1], note = "PERMANOVA, robust Aitchison"),
                      cbind(key, method_id = "B09", role = "describe_only", stat = an$statistic, p = an$signif, note = "ANOSIM R; sensitive to spread"),
                      cbind(key, method_id = "B17", role = "describe_only", stat = NA, p = NA,
                            note = sprintf("SIMPER top contributors: %s (picks variable features, not differing ones)", paste(utils::head(rownames(sp), 3), collapse = ", "))))
    pc <- stats::cmdscale(d, k = 2)
    ord[[i]] <- cbind(key, sample = rownames(m), group = as.character(g), axis1 = pc[, 1], axis2 = pc[, 2], row.names = NULL)
  }
  out <- bind_rows(res)
  if (!is.null(out)) {
    grp <- paste(out$layer, out$predictor, out$timepoint, out$block)
    out$q <- stats::ave(out$p, grp, FUN = function(p) stats::p.adjust(p, "BH"))
    out$status <- ifelse(!is.finite(out$q), "not_testable", ifelse(out$q <= rule("R-FDR"), "lead", "no_evidence"))
  }
  list(results = out, agreement = bind_rows(agr), ordination = bind_rows(ord), skipped = bind_rows(notes))
}

# Q5: which features differ in presence? Logistic regression per feature;
# Firth where separation occurs (a group all present or all absent). Fisher's
# exact test is the agreement method.
q5_presence <- function(units, layers) {
  res <- list(); agr <- list(); notes <- list()
  for (i in seq_along(units)) {
    u <- units[[i]]; key <- unit_key(u); L <- layers[[u$layer]]
    if (L$spec$unit != "count") { notes[[i]] <- cbind(key, reason = sprintf("Q5 for unit %s is built at milestone E8", L$spec$unit)); next }
    if (!u$testable) { notes[[i]] <- cbind(key, reason = u$reason); next }
    ud <- unit_data(u, L); g <- ud$g
    feats <- prevalent(ud$m, g)
    pres <- ud$m[, feats, drop = FALSE] > 0
    vary <- feats[colSums(pres) > 0 & colSums(pres) < nrow(pres)]
    if (!length(vary)) { notes[[i]] <- cbind(key, reason = "no feature varies in presence (each is present in every sample or in none)"); next }
    r <- do.call(rbind, lapply(vary, function(f) {
      y <- as.integer(pres[, f]); tab <- table(g, y)
      sep <- any(tapply(y, g, function(z) all(z == 0) || all(z == 1)))
      if (sep) {
        fit <- logistf::logistf(y ~ g, data = data.frame(y = y, g = g), plconf = 2)
        data.frame(feature = f, effect = unname(fit$coefficients[2]), ci_low = unname(fit$ci.lower[2]), ci_high = unname(fit$ci.upper[2]),
                   p = unname(fit$prob[2]), method_id = "G06", method_role = "default (Firth: separation)", caveat = "separation: a group is all present or all absent, so Firth's correction was used")
      } else {
        fit <- stats::glm(y ~ g, family = stats::binomial())
        co <- summary(fit)$coefficients
        data.frame(feature = f, effect = co[2, 1], ci_low = co[2, 1] - 1.96 * co[2, 2], ci_high = co[2, 1] + 1.96 * co[2, 2],
                   p = co[2, 4], method_id = "R01", method_role = "default", caveat = "")
      }
    }))
    r$q <- stats::p.adjust(r$p, "BH")
    r$status <- ifelse(r$q <= rule("R-FDR"), "lead", "no_evidence")
    r$effect_unit <- "log odds ratio of presence"
    r$n_reference <- length(u$ref_samples); r$n_level <- length(u$level_samples)
    res[[i]] <- cbind(key, r)
    fp <- vapply(vary, function(f) stats::fisher.test(table(g, factor(pres[, f], levels = c(FALSE, TRUE))))$p.value, 1)
    fd <- vapply(vary, function(f) sign(mean(pres[g == levels(g)[2], f]) - mean(pres[g == levels(g)[1], f])), 1)
    fq <- stats::p.adjust(fp, "BH")
    agr[[i]] <- cbind(key, feature = vary, method_id = "K03", effect = fd, p = fp, q = fq, call = fq <= rule("R-FDR"), note = "")
  }
  list(results = bind_rows(res), agreement = bind_rows(agr), skipped = bind_rows(notes))
}

# Q7: which feature sets shift together? Pre-ranked fgsea over each `set`
# column, ranked by Q4's signed z-scores; camera on CLR values agrees.
q7_sets <- function(for_q7, layers) {
  res <- list(); agr <- list(); notes <- list()
  for (i in seq_along(for_q7)) {
    x <- for_q7[[i]]; u <- x$unit; key <- unit_key(u); L <- layers[[u$layer]]
    set_cols <- names(L$spec$feature_columns)[unlist(L$spec$feature_columns) == "set"]
    if (!length(set_cols)) { notes[[i]] <- cbind(key, reason = "the manifest declares no set column"); next }
    for (sc in set_cols) {
      fs <- L$features[match(names(x$stat), L$features$feature), ]
      sets <- split(fs$feature, fs[[sc]]); sets <- sets[lengths(sets) >= 2 & lengths(sets) < length(x$stat)]
      if (!length(sets)) { notes[[length(notes) + 1]] <- cbind(key, reason = sprintf("set column `%s` has no set of 2 or more features", sc)); next }
      set.seed(seed_for(71))
      fg <- suppressWarnings(fgsea::fgsea(pathways = sets, stats = sort(x$stat + seq_along(x$stat) * 1e-10, decreasing = TRUE), minSize = 2, maxSize = 1000, eps = 0, nproc = 1))
      r <- data.frame(set_column = sc, feature = fg$pathway, effect = fg$NES, p = fg$pval, size = fg$size,
                      leading_edge = vapply(fg$leadingEdge, paste, "", collapse = "|"), method_id = "E02", method_role = "default")
      r$q <- stats::p.adjust(r$p, "BH")
      r$status <- ifelse(r$q <= rule("R-FDR"), "lead", "no_evidence")
      r$effect_unit <- "normalised enrichment score"
      r$n_reference <- length(u$ref_samples); r$n_level <- length(u$level_samples)
      res[[length(res) + 1]] <- cbind(key, r)
      z <- t(clr(x$ud$m)[, x$feats, drop = FALSE])
      idx <- lapply(sets, function(s) which(rownames(z) %in% s))
      cm <- limma::camera(z, idx, design = stats::model.matrix(~ x$ud$g))
      cm <- cm[names(sets), , drop = FALSE]
      cq <- stats::p.adjust(cm$PValue, "BH")
      agr[[length(agr) + 1]] <- cbind(key, set_column = sc, feature = rownames(cm), method_id = "E03", effect = ifelse(cm$Direction == "Up", 1, -1),
                                      p = cm$PValue, q = cq, call = cq <= rule("R-FDR"), note = "")
    }
  }
  list(results = bind_rows(res), agreement = bind_rows(agr), skipped = bind_rows(notes))
}

# Q2 agreement set (design C12): plug-in Hill numbers on rarefied counts, and
# DivNet (Shannon and Simpson, F3, pinned). Each compared with its own test;
# directions are on the Hill scale (higher = more diverse).
q2_agreement <- function(units, layers) {
  out <- list()
  for (u in units) {
    if (!u$testable || layers[[u$layer]]$spec$unit != "count") next
    key <- unit_key(u); ud <- unit_data(u, layers[[u$layer]]); m <- round(ud$m); g <- ud$g; a <- g == levels(g)[1]
    m <- m[rowSums(m) > 0, , drop = FALSE]; g <- g[rownames(ud$m) %in% rownames(m)]; a <- g == levels(g)[1]
    set.seed(seed_for(21)); rr <- vegan::rrarefy(m, min(rowSums(m)))
    h <- cbind(`0` = rowSums(rr > 0), `1` = exp(vegan::diversity(rr, "shannon")), `2` = vegan::diversity(rr, "invsimpson"))
    for (qq in 0:2) {
      t <- tryCatch(stats::t.test(h[!a, qq + 1], h[a, qq + 1]), error = function(e) NULL)
      out[[length(out) + 1]] <- cbind(key, q_order = qq, method_id = "A01", effect = mean(h[!a, qq + 1]) - mean(h[a, qq + 1]),
                                      p = if (is.null(t)) NA else t$p.value, note = "plug-in on rarefied counts, Welch test")
    }
    dv <- tryCatch({
      set.seed(seed_for(22))
      X <- stats::model.matrix(~ g)
      utils::capture.output(x <- suppressMessages(suppressWarnings(DivNet::divnet(W = m, X = X, tuning = "fast", ncores = 1))))
      sh <- breakaway::betta(chats = vapply(x$shannon, function(e) e$estimate, 1), ses = vapply(x$shannon, function(e) e$error, 1), X = X)$table
      si <- breakaway::betta(chats = vapply(x$simpson, function(e) e$estimate, 1), ses = vapply(x$simpson, function(e) e$error, 1), X = X)$table
      # Simpson's index falls as diversity rises: its sign is flipped onto the Hill scale.
      list(c(effect = sh[2, 1], p = sh[2, 3]), c(effect = -si[2, 1], p = si[2, 3]))
    }, error = function(e) NULL)
    for (j in 1:2) out[[length(out) + 1]] <- cbind(key, q_order = j, method_id = "A04",
                                                   effect = if (is.null(dv)) NA else dv[[j]][["effect"]], p = if (is.null(dv)) NA else dv[[j]][["p"]],
                                                   note = if (is.null(dv)) "DivNet did not fit" else if (j == 1) "DivNet Shannon, betta test" else "DivNet Simpson (sign flipped), betta test")
  }
  r <- bind_rows(out)
  if (is.null(r)) return(NULL)
  grp <- paste(r$layer, r$predictor, r$contrast, r$timepoint, r$block, r$method_id)
  r$q <- stats::ave(r$p, grp, FUN = function(p) { q <- rep(NA_real_, length(p)); ok <- is.finite(p); q[ok] <- stats::p.adjust(p[ok], "BH"); q })
  r$call <- !is.na(r$q) & r$q <= rule("R-FDR")
  r
}
