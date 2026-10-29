# seqcompendium container (CLAUDE.md D3, D13). Every version is pinned and was
# at least two weeks old when pinned:
#   R 4.6.1, rocker/r-ver image pushed 2026-10-15, pinned by digest;
#   every R package from renv.lock: CRAN and Bioconductor 3.23 from the Posit
#     Package Manager snapshots of 2026-10-14, DivNet from GitHub at commit
#     57fbdc2 (2026-06-16); inst/scripts/check_package_ages.R confirms it;
#   pandoc 3.12.1 (released 2026-10-08), for the HTML report.
# System libraries come from Ubuntu 24.04's archive (security updates only).
FROM docker.io/rocker/r-ver:4.6.1@sha256:bafb3b9a72791eeeb810f0bc0472e74c7f4939b20b46c96cb7ebc6838b6a25ef

ARG PANDOC_VERSION=3.12.1
ARG SNAPSHOT=2026-10-14

RUN apt-get update \
 && apt-get install -y --no-install-recommends libgsl-dev libglpk-dev libgmp-dev libmpfr-dev libxml2-dev libcurl4-openssl-dev \
      libssl-dev zlib1g-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev cmake \
 && rm -rf /var/lib/apt/lists/* \
 && /rocker_scripts/install_pandoc.sh "${PANDOC_VERSION}" \
 && sed -i "s#https://p3m.dev/cran/__linux__/noble/latest#https://p3m.dev/cran/__linux__/noble/${SNAPSHOT}#" /usr/local/lib/R/etc/Rprofile.site

COPY renv.lock /opt/seqcompendium-renv.lock
RUN Rscript -e "install.packages('renv', repos = 'https://p3m.dev/cran/__linux__/noble/${SNAPSHOT}')" \
 && Rscript -e "options(renv.config.ppm.enabled = TRUE, Ncpus = 4); renv::restore(lockfile = '/opt/seqcompendium-renv.lock', library = .libPaths()[1], prompt = FALSE)" \
 && Rscript -e "for (p in c('DESeq2', 'ANCOMBC', 'ALDEx2', 'MicrobiomeStat', 'DivNet', 'mvabund', 'vegan', 'iNEXT', 'lefser', 'decontam', 'fgsea', 'rmarkdown', 'testthat')) loadNamespace(p)"

COPY . /opt/seqcompendium
RUN R CMD INSTALL --no-test-load /opt/seqcompendium \
 && Rscript -e "library(seqcompendium); cat('seqcompendium', as.character(packageVersion('seqcompendium')), 'installed\n')"

WORKDIR /work
