# engine_bits.R: the default Q4 method alone on a simulated bundle, through
# the engine's own functions (the same path the override rule's simulation
# uses), for V-E5's FDR with known truth.

default_q4_calls <- function(bundle, truth) {
  e <- asNamespace("seqcompendium")
  out <- tryCatch({
    b <- e$read_bundle(bundle); gc <- e$check_guide(b$md, b$guide); lc <- e$check_layers(b$layers, gc$md)
    des <- e$read_design(gc$md, b$guide, gc$info); cells <- e$design_cells(des)
    u <- Filter(function(u) u$testable, e$contrast_units(lc$layers, des, cells))[[1]]
    L <- lc$layers[[u$layer]]
    id <- if (is.null(L$spec$denominators)) "D09" else "D01"
    ud <- e$unit_data(u, L, des)
    res <- e$FITS[[id]](ud, e$prevalent(ud$m, ud$g))
    ok <- is.finite(res$p); q <- rep(NA_real_, nrow(res)); q[ok] <- stats::p.adjust(res$p[ok], "BH")
    call <- res$feature[ok & q <= e$rule("R-FDR")]
    list(error = NA_character_, default_id = id, calls = length(call), false_calls = length(setdiff(call, truth$planted)))
  }, error = function(err) list(error = conditionMessage(err), default_id = NA_character_, calls = NA_integer_, false_calls = NA_integer_))
  out
}

# FDR per scenario: mean over runs of false calls / max(calls, 1); a scenario
# is miscalibrated when it exceeds R-CAL x R-FDR = 0.20.
fdr_table <- function(rows, limit = 0.20) {
  r <- rows[rows$mark == "V-E5 fdr" & is.na(rows$error), , drop = FALSE]
  do.call(rbind, lapply(unique(r$scenario), function(s) {
    x <- r[r$scenario == s, ]; f <- mean(x$false_calls / pmax(x$calls, 1))
    data.frame(scenario = s, fdr = f, runs = nrow(x), miscalibrated = f > limit)
  }))
}
