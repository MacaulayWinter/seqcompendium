# agreement.R: did the alternatives agree? (design section 7, choice C15)
#
# For a lead: agreement methods that give the same direction AND a call at
# R-FDR. For a no-evidence row: agreement methods that make no call either.
# k of n eligible methods; "agreed" when k/n >= R-AGREE, "partly agreed"
# when 0 < k/n < R-AGREE, "disagreed" when k = 0, "not testable" when no
# alternative ran. Describe-only methods (F1) are never counted. Agreement is
# not correctness: methods that agree can share a bias.

agreement_labels <- function(primary, alt, by, directional = TRUE) {
  primary$agreement <- "0/0"; primary$agreement_label <- "not testable"
  if (is.null(alt) || is.null(primary) || !nrow(primary)) return(primary)
  pk <- do.call(paste, c(primary[by], sep = "\r")); ak <- do.call(paste, c(alt[by], sep = "\r"))
  for (i in seq_len(nrow(primary))) {
    a <- alt[ak == pk[i] & is.finite(as.numeric(alt$p)), , drop = FALSE]
    n <- nrow(a)
    if (!n || !primary$status[i] %in% c("lead", "no_evidence")) next
    call <- if ("call" %in% names(a)) as.logical(a$call) else as.numeric(a$p) <= rule("R-FDR")
    same <- if (directional) sign(as.numeric(a$effect)) == sign(primary$effect[i]) else rep(TRUE, n)
    k <- if (primary$status[i] == "lead") sum(call & same, na.rm = TRUE) else sum(!call, na.rm = TRUE)
    primary$agreement[i] <- sprintf("%d/%d", k, n)
    primary$agreement_label[i] <- if (k / n >= rule("R-AGREE")) "agreed" else if (k > 0) "partly agreed" else "disagreed"
  }
  primary
}
