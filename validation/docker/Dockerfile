# Validation image (CLAUDE.md D33, D34): the engine image plus the two
# Bioconductor 3.23 packages the data-choice rule reads its templates from
# (validation/PREREGISTRATION.md §2), from the same 2026-10-14 snapshot.
# Build from the repository root, after the engine image:
#   docker build -t seqcompendium:e7 .
#   docker build -f validation/docker/Dockerfile --build-arg ENGINE=seqcompendium:e7 -t seqcompendium-validation:e7 .
ARG ENGINE=seqcompendium:e7
FROM ${ENGINE}
ARG SNAPSHOT=2026-10-14
RUN Rscript -e "s <- '${SNAPSHOT}'; \
  options(Ncpus = 4, repos = c(CRAN = sprintf('https://p3m.dev/cran/__linux__/noble/%s', s), \
    BioCsoft = sprintf('https://p3m.dev/bioconductor/__linux__/noble/%s/packages/3.23/bioc', s), \
    BioCann = sprintf('https://p3m.dev/bioconductor/__linux__/noble/%s/packages/3.23/data/annotation', s), \
    BioCexp = sprintf('https://p3m.dev/bioconductor/__linux__/noble/%s/packages/3.23/data/experiment', s))); \
  install.packages(c('curatedMetagenomicData', 'MicrobiomeBenchmarkData')); \
  stopifnot(packageVersion('curatedMetagenomicData') == '3.20.0', packageVersion('MicrobiomeBenchmarkData') == '1.14.0')"
