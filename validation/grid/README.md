# Running the validation grid on any machine

The v0.1.0 validation grid (marks V-E2b contaminants, V-E3, V-E4, V-E5, V-E6;
`validation/PREREGISTRATION.md`) is **17,606 engine runs**, about **10,000–30,000
CPU-hours** (CLAUDE.md D40). That is a job for a cluster or a cloud batch service, not a
laptop. Nothing here depends on one cluster or one scheduler (D39): the grid brings its
own R and packages, and work is split into numbered tasks that any launcher can run.

## What you need

- Linux or macOS with `conda` (Miniforge is enough) and `bash`.
  `conda` must be on PATH in the shell you run or submit from (load or install it
  however your machine provides it); jobs inherit it with `--export=ALL`. Every grid
  script checks this first and stops with a message if it is missing.
  After activating the grid's environment, every script also clears the shell's
  compiler and library search paths (CPATH, LIBRARY_PATH, LD_LIBRARY_PATH, other
  pkg-config folders, your own R start-up files), so nothing is built or run against
  libraries from outside the environment (`isolate_env.sh`).
- Internet on the machine that runs steps 1 and 2 (packages, then the template data).
  The tasks themselves need no internet.
- Disk: about 6 GB for the environment, 3 GB for templates and results.
- Per task: **1 CPU** and **6 GB memory** (shotgun templates; the 16S figure is being
  checked and will be written here). One run takes 35–50 minutes on shotgun templates;
  a task is 2 runs by default.

## Steps

Run every command from the repository root. `VAL` is a work folder of your choice,
outside the repository (results and data are never committed).

1. **Build the environment** (once; on a cluster, as a job, not on the login node):

   ```bash
   VAL=/path/to/work bash validation/grid/setup_env.sh
   ```

   It creates a conda R 4.6.1 in `$VAL/env` and builds every R package at the pinned
   version in `validation/renv-validation.lock`. It stops if any version differs. To keep
   the environment elsewhere, set `SEQCOMP_ENV=/other/path` here and in every later step.

2. **Fetch and fit the templates, and write the task list** (once):

   ```bash
   VAL=/path/to/work bash validation/grid/prepare.sh
   ```

   It prints the number of tasks, N.

3. **Run tasks 1..N**, with whatever launcher suits the machine. Every launcher only
   calls `run_task.sh <number>`:

   - One machine, J tasks at a time (restartable; finished tasks are skipped):

     ```bash
     VAL=/path/to/work J=8 bash validation/grid/run_local.sh
     ```

   - SLURM (an example; add your own account and partition on the command line):

     ```bash
     VAL=/path/to/work sbatch --export=ALL --array=1-N%200 validation/grid/slurm_example.sbatch
     ```

   - Anything else (PBS/SGE arrays, a cloud batch service, a plain loop): run
     `VAL=/path/to/work bash validation/grid/run_task.sh <i>` for each i from 1 to N.

   A task that fails can simply be run again; each task writes its own file under
   `$VAL/results/rows/`.

4. **Collect the marks**, using the grid's own R:

   ```bash
   conda activate /path/to/work/env && R_LIBS_USER=/path/to/work/env/Rlib Rscript validation/collect.R /path/to/work/results /path/to/work/marks.csv
   ```

   Then bring back `$VAL/results/` (the `rows/` folder) and `marks.csv`. The Mac marks
   (V-E1, V-E2, V-E7, V-E8, V-E10) are run separately and merged in by `collect.R`.

## V-E7b: the engine against Nearing et al. 2022

Two tasks, one per data set (ArcticFireSoils, ArcticFreshwaters), using the same
environment (step 1). Each takes tens of hours on 1 CPU; give each 32 GB of memory.

```bash
VAL=/path/to/work bash validation/grid/prepare_ve7b.sh
VAL=/path/to/work sbatch --export=ALL --array=1-2 validation/grid/slurm_ve7b_example.sbatch
```

Without SLURM: `VAL=/path/to/work bash validation/grid/run_ve7b.sh 1` and `... run_ve7b.sh 2`.
Results land in `$VAL/results_ve7b/`: `ve7b_<data set>.csv` per task, then
`ve7b_nearing.csv` and `ve7b_marks.csv` once both are done. Bring back that folder.

## Checking the environment first (optional)

`validation/grid/rehearse.sh` builds the environment inside a clean Miniforge container and
checks that a toy run gives the same leads as the engine's reference container.
