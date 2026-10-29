# seqcompendium container (CLAUDE.md D3). Every version is pinned and was at
# least two weeks old when pinned:
#   R 4.6.1, rocker/r-ver image pushed 2026-10-15, pinned by digest;
#   CRAN packages from the Posit Package Manager snapshot of 2026-10-14
#     (every package is the version CRAN held that day);
#   pandoc 3.12.1 (released 2026-10-08), for the HTML report.
FROM docker.io/rocker/r-ver:4.6.1@sha256:bafb3b9a72791eeeb810f0bc0472e74c7f4939b20b46c96cb7ebc6838b6a25ef

ARG CRAN_SNAPSHOT=https://p3m.dev/cran/__linux__/noble/2026-10-14
ARG PANDOC_VERSION=3.12.1

# Point every later install at the dated snapshot, not "latest".
RUN sed -i "s#https://p3m.dev/cran/__linux__/noble/latest#${CRAN_SNAPSHOT}#" /usr/local/lib/R/etc/Rprofile.site \
 && grep -q "${CRAN_SNAPSHOT}" /usr/local/lib/R/etc/Rprofile.site \
 && /rocker_scripts/install_pandoc.sh "${PANDOC_VERSION}" \
 && Rscript -e "install.packages(c('yaml', 'iNEXT', 'ggplot2', 'digest', 'rmarkdown', 'testthat', 'pkgload'), repos = '${CRAN_SNAPSHOT}', Ncpus = 4)" \
 && Rscript -e "for (p in c('yaml', 'iNEXT', 'ggplot2', 'digest', 'rmarkdown', 'testthat')) library(p, character.only = TRUE)"

COPY . /opt/seqcompendium
RUN R CMD INSTALL --no-test-load /opt/seqcompendium \
 && Rscript -e "library(seqcompendium); cat('seqcompendium', as.character(packageVersion('seqcompendium')), 'installed\n')"

WORKDIR /work
