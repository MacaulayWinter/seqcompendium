# screen.R: the prevalence screen (CLAUDE.md D70; design note criteria 1 to 10).
#
# Before Q4 runs, each count table is looked at once and the user is told how the choice of WHICH samples the
# prevalence cut is counted over changes the features that are tested. Three bases, for the same cut:
#   G  the engine's own rule: present in at least the cut's share of the samples of at least one group of the comparison (R-PREV)
#   P  pooled over the comparison's analysed samples
#   S  pooled over every study sample of the layer (controls are never counted)
# It always reports (01_profile/prevalence_screen.csv, prevalence_screen_decision.csv, a paragraph in the report). It proposes in words.
# It leaves features out of a comparison's Q4 tests by default only in the narrow case of criterion 6, always listed (prevalence_screen_removed.csv)
# and named in a caveat on every Q4 row of the comparison, and it can be switched off (`screen = "report"` or `"off"` in run_compendium()).

# Names of the three modes; "default" reports and applies where criterion 6 holds, "report" never applies, "off" does nothing.
SCREEN_MODES <- c("default", "report", "off")

screen_pass <- function(pres, ref, lvl, cut) {
  # pres: logical samples x features; ref/lvl: row indices of the two groups of the comparison. Features kept under G, P and S.
  an <- c(ref, lvl)
  g <- pmax(colMeans(pres[ref, , drop = FALSE]), colMeans(pres[lvl, , drop = FALSE])) >= cut
  p <- colMeans(pres[an, , drop = FALSE]) >= cut
  s <- colMeans(pres) >= cut
  list(G = g, P = p, S = s)
}

# One comparison: the report rows, the decision and (when default-apply fires) the features to leave out.
screen_unit <- function(u, L, des, mode, long = FALSE) {
  st <- des$study; all_s <- st$sample[st$sample %in% L$data$sample]
  m <- wide(L, all_s); pres <- m > 0
  ref <- match(u$ref_samples, rownames(m)); lvl <- match(u$level_samples, rownames(m))
  key <- unit_key(u)
  cuts <- unlist(rule("R-SCREENCUTS")); sens <- rule("R-SCREENSENS"); apply_cut <- rule("R-SCREENAPPLYCUT")
  share_an <- length(c(ref, lvl)) / nrow(m)
  prevP <- colMeans(pres[c(ref, lvl), , drop = FALSE])
  rows <- list(); add <- function(item, cut, value, note = "") rows[[length(rows) + 1]] <<- cbind(key, scope = "comparison", item = item, cut = cut, value = as.character(value), note = note)
  for (b in c(0.05, 0.10, 0.20, 0.50)) add("share_of_features_present_in_fewer_than", b, round(mean(prevP < b), 4), "of the comparison's analysed samples (basis P)")
  add("analysed_samples", NA, length(c(ref, lvl))); add("study_samples_in_layer", NA, nrow(m)); add("analysed_share_of_study_samples", NA, round(share_an, 4))
  fl <- list()
  for (cut in cuts) {
    k <- screen_pass(pres, ref, lvl, cut); kp <- sum(k$P); ks <- sum(k$S); hi <- max(kp, ks); lo <- min(kp, ks)
    ratio <- if (hi == 0) NA_real_ else if (lo == 0) Inf else hi / lo
    flagged <- !is.na(ratio) && ratio >= sens          # Inf (one basis keeps nothing, the other something) counts
    add("kept_G_engine_rule", cut, sum(k$G), "present in at least this share of the samples of at least one group of the comparison")
    add("kept_P_pooled_analysed", cut, kp); add("kept_S_pooled_all_study_samples", cut, ks)
    add("features_differing_between_P_and_S", cut, sum(k$P != k$S)); add("ratio_larger_over_smaller_of_P_and_S", cut, round(ratio, 3))
    add("sample_set_sensitivity_flagged", cut, flagged, sprintf("ratio at least %g", sens))
    fl[[as.character(cut)]] <- list(k = k, flagged = flagged, ratio = ratio)
  }
  # Criterion 5: the proposal, in words. It never changes a number.
  at <- fl[[as.character(apply_cut)]]
  G10 <- screen_pass(pres, ref, lvl, rule("R-PREV"))$G; sparse_tail <- if (sum(G10)) mean(prevP[G10] < 0.20) else 0
  proposal <- if (!is.null(at) && at$flagged) sprintf("propose counting the %g%% prevalence cut over all %d study samples (basis S): it keeps %d features where the engine's own rule keeps %d; the choice of sample set changes the tested family by a factor of %s",
                                                      100 * apply_cut, nrow(m), sum(at$k$S), sum(at$k$G), format(round(at$ratio, 2)))
              else if (sparse_tail > 0.5) sprintf("%.0f%% of the features that pass the engine's own rule are present in fewer than 20%% of the comparison's samples; a 20%% cut would keep %d features (an option, not applied)", 100 * sparse_tail, if (is.null(fl[["0.2"]])) NA_integer_ else sum(fl[["0.2"]]$k$P))
              else "no change proposed"
  # Criteria 6 and 7: default-apply, only in the narrow case.
  count_layer <- identical(L$spec$unit, "count")
  c_flag <- !is.null(at) && sum(at$k$P) > 0 && sum(at$k$P) >= sens * sum(at$k$S)
  c_share <- share_an <= rule("R-SCREENSHARE")
  would_remove <- if (!is.null(at)) names(which(at$k$G & !at$k$S)) else character(0)
  keep_after <- if (!is.null(at)) sum(at$k$G & at$k$S) else 0
  c_keep <- keep_after >= rule("R-SCREENMINKEEP")
  fires <- count_layer && c_flag && c_share && c_keep && length(would_remove) > 0
  applied <- identical(mode, "default") && fires
  why <- if (applied) "applied" else if (long) "not applied: a longitudinal design (Q4 uses mixed models there; the screen reports only)" else if (identical(mode, "report")) "not applied (report mode)" else if (!count_layer) "not applied: not a count layer"
         else if (!c_flag) "not applied: criterion 6 not met (the pooled analysed samples do not keep at least 2 times as many features as all study samples)"
         else if (!c_share) "not applied: criterion 6 not met (the analysed samples are more than 60% of the study samples)"
         else if (!c_keep) "not applied: it would leave fewer than the smallest set of features a model can use"
         else "not applied: nothing to leave out"
  dec <- cbind(key, mode = mode, flagged_at_apply_cut = isTRUE(at$flagged), analysed_share = round(share_an, 4), proposal = proposal, would_leave_out = length(would_remove),
               applied = applied, why = why)
  removed <- if (applied) cbind(key[rep(1, length(would_remove)), , drop = FALSE], feature = would_remove, prevalence_P = round(prevP[would_remove], 4),
                                prevalence_S = round(colMeans(pres)[would_remove], 4), cut = apply_cut) else NULL
  list(rows = do.call(rbind, rows), decision = dec, removed = removed, drop = if (applied) would_remove else NULL, key = paste(unlist(key), collapse = "\r"))
}

# Depth distribution per layer (criterion 2).
screen_depth <- function(L, des) {
  st <- des$study; s <- st$sample[st$sample %in% L$data$sample]; m <- wide(L, s); lib <- rowSums(m); fl <- rule("R-LINDAFLOOR")
  near <- names(lib)[lib < fl]
  add <- function(item, value, note = "") data.frame(layer = NA_character_, scope = "layer", item = item, cut = NA_real_, value = as.character(value), note = note)
  rbind(add("library_size_min", min(lib)), add("library_size_p5", unname(stats::quantile(lib, 0.05))), add("library_size_median", stats::median(lib)),
        add("library_size_max", max(lib)), add("library_size_max_over_min", if (min(lib) > 0) round(max(lib) / min(lib), 2) else Inf),
        add("near_empty_samples", length(near), sprintf("fewer than %g reads (R-LINDAFLOOR)%s", fl, if (length(near) && length(near) <= 20) paste0(": ", paste(near, collapse = ", ")) else "")),
        add("near_empty_share", round(length(near) / length(lib), 4)))
}

# The screen for a whole run. Returns the rows, the decisions, the removed features, and a named list of features to leave out per comparison.
prevalence_screen <- function(units, layers, des, mode = "default", long = FALSE) {
  if (long) mode <- "report"
  rows <- list(); dec <- list(); rem <- list(); drop <- list(); depth_done <- character(0)
  for (u in units) {
    L <- layers[[u$layer]]
    if (!isTRUE(u$testable) || !identical(L$spec$unit, "count")) next
    if (!u$layer %in% depth_done) { d <- screen_depth(L, des); d$layer <- u$layer; rows[[length(rows) + 1]] <- cbind(d[, "layer", drop = FALSE], predictor = NA, contrast = NA, timepoint = NA, block = NA, d[, c("scope", "item", "cut", "value", "note")]); depth_done <- c(depth_done, u$layer) }
    x <- screen_unit(u, L, des, mode, long)
    rows[[length(rows) + 1]] <- x$rows; dec[[length(dec) + 1]] <- x$decision; if (!is.null(x$removed)) rem[[length(rem) + 1]] <- x$removed
    if (!is.null(x$drop)) drop[[x$key]] <- x$drop
  }
  list(rows = bind_rows(rows), decision = bind_rows(dec), removed = bind_rows(rem), drop = drop)
}

screen_unit_key <- function(u) paste(unlist(unit_key(u)), collapse = "\r")

# The caveat every Q4 row of a comparison carries when default-apply left features out.
screen_caveat <- function(n_left_out) sprintf("the prevalence screen left %d feature(s) out of this comparison's tests: they pass the engine's own prevalence rule but are present in fewer than %g%% of all study samples of the layer (rule R-SCREENAPPLYCUT; listed in 01_profile/prevalence_screen_removed.csv; switch off with screen = \"report\" or \"off\")",
                                              n_left_out, 100 * rule("R-SCREENAPPLYCUT"))

# The paragraph of the report (a part of section 4): what the screen saw, what it proposes, whether it left anything out.
screen_report_lines <- function(scr) {
  if (is.null(scr) || is.null(scr$decision) || !nrow(scr$decision)) return(character(0))   # no testable count comparison: nothing to say
  d <- scr$decision; r <- scr$rows
  lines <- c("**Prevalence screen** (`01_profile/prevalence_screen.csv`, `01_profile/prevalence_screen_decision.csv`). Before Q4 each count table is looked at once: how many features each prevalence cut keeps depending on which samples the share is counted over (the engine's own rule, the comparison's analysed samples pooled, or every study sample pooled), and the near-empty samples. It proposes in words; it leaves features out only in the narrow case described in the rules (R-SCREENSENS, R-SCREENSHARE), and says so here and in a caveat on every Q4 row it touched. It can be switched off with `screen = \"report\"` or `\"off\"`.", "")
  for (i in seq_len(nrow(d))) {
    x <- d[i, ]; near <- r$value[r$item == "near_empty_samples" & r$layer == x$layer & r$scope == "layer"]
    lines <- c(lines, sprintf("- %s, %s at timepoint %s, block %s: %s. %s%s", x$layer, x$contrast, x$timepoint, x$block, x$proposal,
                              if (isTRUE(x$applied)) sprintf("**%d feature(s) were left out of the Q4 tests of this comparison** (`01_profile/prevalence_screen_removed.csv`).", x$would_leave_out) else sprintf("Nothing was left out (%s).", x$why),
                              if (length(near) && !is.na(near[1]) && as.numeric(near[1]) > 0) sprintf(" %s near-empty sample(s) in this layer (see the table).", near[1]) else ""))
  }
  c(lines, "")
}
