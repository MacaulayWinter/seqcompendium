# E7-M7 evidence: the portable environment against the reference container

`validation/grid/rehearse.sh` with `POLLUTE=1`, commit 1bc0abe, 2026-11-11. The grid
environment was built from source in a clean Miniforge container with a polluted shell
(CPATH, LIBRARY_PATH, LD_LIBRARY_PATH and PKG_CONFIG_PATH pointing at a decoy ICU), then the
engine's toy bundle was run there and in the engine's reference container.

- `leads_conda_env.csv`: leads from the built environment
- `leads_reference.csv`: leads from the reference container
- `e7m7_summary.txt`: the comparison. Status and tier are identical, the largest relative
  difference is 8.64e-08, and the missing values are the same. PASS (CLAUDE.md D47, D51).

Toy data only, made by `make_toy_bundle()`; no research data.
