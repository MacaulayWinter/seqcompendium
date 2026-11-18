# ve7c_score.R: the scorer of V-E7(c) (validation/PREREGISTRATION.md section 9). Pure functions on tables; no file is read here, so the
# tests (validation/tests/test-ve7c.R) use hand-made tables only. The scoring script feeds it the engine's frozen tables and a reference's
# numbers, once, after the freeze (section 9.12 and the run plan). Every number below is the pre-registered one (9.5), not a choice.

# 9.5 rule 1: allowance = max(t_rel x the reference's count, t_abs), never below twice a reading error (9.6).
VE7C_TOL <- data.frame(method_id = c("D09", "D06", "D17", "D19", "D04"), t_rel = c(0.05, 0.05, 0.05, 0.05, 0.08),
                       t_abs = c(0, 0, 0, 0, 2), stringsAsFactors = FALSE)
VE7C_SIGN_MIN <- 0.95     # 9.5 rule 2
VE7C_RHO_MIN <- 0.8       # 9.5 rule 3
VE7C_Q <- 0.05

ve7c_allowance <- function(method_id, ref_count, reading_error = 0) {
  t <- VE7C_TOL[VE7C_TOL$method_id == method_id, ]
  if (nrow(t) != 1) stop("no allowance fixed for method ", method_id)
  max(t$t_rel * ref_count, t$t_abs, 2 * reading_error)
}

ve7c_count_ok <- function(method_id, ref_count, engine_count, reading_error = 0) {
  if (is.na(engine_count) || is.na(ref_count)) return(FALSE)   # a method that did not run is never agreement
  abs(engine_count - ref_count) <= ve7c_allowance(method_id, ref_count, reading_error) + 1e-9
}

# Feature-level tables: feature, effect, q. Features significant at BH q < 0.05.
.ve7c_sig <- function(x) x$feature[!is.na(x$q) & x$q < VE7C_Q]

# 9.5 rule 2: of the features significant in both, the share with the same sign of effect. flip = TRUE when the reference's sign convention is the opposite.
ve7c_sign_agreement <- function(eng, ref, flip = FALSE) {
  both <- intersect(.ve7c_sig(eng), .ve7c_sig(ref))
  if (!length(both)) return(NA_real_)
  e <- eng$effect[match(both, eng$feature)]; r <- ref$effect[match(both, ref$feature)]
  if (flip) r <- -r
  mean(sign(e) == sign(r))
}
# NA (nothing significant in both) is not specified in section 9.5. Applied here and said in the PR: met if neither side has any significant
# feature (nothing to disagree about); not met if either side has some but they share none.
ve7c_rule2 <- function(eng, ref, flip = FALSE) {
  s <- ve7c_sign_agreement(eng, ref, flip)
  if (is.na(s)) return(length(.ve7c_sig(eng)) == 0 && length(.ve7c_sig(ref)) == 0)
  s >= VE7C_SIGN_MIN - 1e-9
}

# 9.5 rule 3: Spearman of effects over features significant in either, among features present in both tables. NULL reference table = counts only: not applicable.
ve7c_spearman <- function(eng, ref) {
  if (is.null(ref)) return(NA_real_)
  u <- union(.ve7c_sig(eng), .ve7c_sig(ref)); u <- u[u %in% eng$feature & u %in% ref$feature]
  if (length(u) < 3) return(NA_real_)
  stats::cor(eng$effect[match(u, eng$feature)], ref$effect[match(u, ref$feature)], method = "spearman")
}
ve7c_rule3 <- function(eng, ref) {
  if (is.null(ref)) return(NA)
  r <- ve7c_spearman(eng, ref)
  if (is.na(r)) return(NA)
  r >= VE7C_RHO_MIN - 1e-9
}

# A method line: every rule that applies must hold. NA (not applicable) is skipped; a count that could not be compared makes the line not confirmed (NA).
ve7c_method_ok <- function(count_ok, rule2, rule3) {
  if (is.na(count_ok)) return(NA)
  all(c(count_ok, rule2, rule3)[!is.na(c(count_ok, rule2, rule3))])
}

# A reference is congruent if every method other than LinDA meets its rules; LinDA's line counts only for a reference NOT by LinDA's authors.
# m: data.frame(method_id, ok). NA anywhere that counts makes the reference not confirmed (NA), never a pass.
ve7c_reference_congruent <- function(m, linda_authors) {
  if (!nrow(m)) stop("no methods to judge")
  keep <- if (linda_authors) m$method_id != "D09" else rep(TRUE, nrow(m))
  ok <- m$ok[keep]
  if (!length(ok)) stop("no methods to judge")
  if (any(!is.na(ok) & !ok)) return(FALSE)
  if (anyNA(ok)) return(NA)
  TRUE
}

# 9.7 outcomes. refs: data.frame(reference, congruent, published, author_free); congruent NA = could not be run or scored.
ve7c_outcome <- function(refs) {
  n <- nrow(refs)
  planted <- refs$congruent[!refs$published]; pub <- refs[refs$published, ]
  af <- refs$congruent[refs$author_free]
  if (n < 3 || !any(refs$author_free) || anyNA(af) || length(planted) != 1 || is.na(planted) || anyNA(pub$congruent))
    return("Not confirmed: fewer than three references were run and scored, or the method-author-free reference could not be run, or a reference was not confirmed. Never a pass.")
  if (!planted) return("Fail: planted truth fails, whatever the papers say. The engine is wrong on known truth.")
  if (!any(pub$congruent)) return("Fail: planted truth is congruent but no published reference is. The engine agrees only with itself.")
  if (all(pub$congruent) && all(af)) return("Pass: every reference is congruent, including the method-author-free one. The engine works on Q4; the first reference (Nearing 2022) was a poor reference for it.")
  "Unresolved, not a pass: planted truth is congruent and some published reference is not. Each failure is reported by name; the mark stays failed until the user decides."
}
