# versions.R: which installed packages differ from the locks (CLAUDE.md D46).
# Versions are compared as versions, not strings: packageVersion() prints
# "1.2-2" as "1.2.2", which is the same version.
# want: named character vector of locked versions; got: installed versions as
# strings, "missing" when not installed. Returns the names that differ.
versions_differ <- function(want, got) {
  same <- vapply(names(want), function(p) {
    g <- got[[p]]
    if (is.na(g) || identical(g, "missing")) return(FALSE)
    w <- tryCatch(package_version(want[[p]]), error = function(e) NULL); h <- tryCatch(package_version(g), error = function(e) NULL)
    if (is.null(w) || is.null(h)) identical(want[[p]], g) else w == h
  }, TRUE)
  names(want)[!same]
}
