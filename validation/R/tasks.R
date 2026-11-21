# tasks.R: the task table of the validation grid (one row per array task: scenario, first run, last run).
# fresh = FALSE is the ordinary list (V-E1 excluded; it runs with the Mac marks, PREREGISTRATION.md 7), unchanged.
# fresh = TRUE is the V-E7(c) planted-truth list (PREREGISTRATION.md 9.4): V-E3 and V-E4 on the first template of each pair
# whose fresh template differs (shotgun1 -> shotgun4, shotgun2 -> shotgun5, 16S1 -> 16S3), 39 scenarios of 200 runs.
# Shotgun tasks take `per` runs; 16S tasks take 1 run (their runs are long). Shotgun tasks come first, so each memory class is one range.
make_task_table <- function(sc, per = 2L, fresh = FALSE) {
  sc <- sc[sc$mark != "V-E1", ]
  if (fresh) {
    sc <- sc[sc$mark %in% c("V-E3", "V-E4") & sc$template %in% c("shotgun1", "shotgun2", "16S1"), ]
    sc <- sc[order(sc$template == "16S1", sc$scenario), ]
  }
  do.call(rbind, lapply(seq_len(nrow(sc)), function(i) {
    p <- if (fresh && sc$template[i] == "16S1") 1L else per
    n <- sc$runs[i] + sc$fdr_runs[i]; a <- seq(1, n, by = p)
    # The FDR runs are quick: one block per 50.
    if (sc$fdr_runs[i] > 0) a <- c(seq(1, sc$runs[i], by = p), seq(sc$runs[i] + 1, n, by = 50))
    b <- c(a[-1] - 1, n)
    data.frame(scenario = sc$scenario[i], first = a, last = b)
  }))
}
