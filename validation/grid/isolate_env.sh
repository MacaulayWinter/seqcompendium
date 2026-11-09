# isolate_env.sh: sourced right after `conda activate "$ENV_DIR"` by every grid
# script (CLAUDE.md D39, D44). A shared machine's shell can carry another conda
# base or system libraries through search-path variables; then a package builds
# against one library and loads another (seen on a cluster: stringi compiled
# against the base install's ICU 73, and systemfonts found no freetype headers).
# This keeps every build and every run to the environment's own libraries.
: "${ENV_DIR:?ENV_DIR must be set before isolate_env.sh}"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH LD_RUN_PATH DYLD_LIBRARY_PATH DYLD_FALLBACK_LIBRARY_PATH
unset R_HOME R_LIBS R_LIBS_SITE R_ENVIRON R_PROFILE R_MAKEVARS_SITE
# The user's own ~/.Renviron, ~/.Rprofile and ~/.R/Makevars are not read.
export R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null R_MAKEVARS_USER=/dev/null
# renv's package cache lives inside the environment, so a rebuild never reuses
# a package built in another shell.
export RENV_PATHS_ROOT="$ENV_DIR/renv"
export PATH="$ENV_DIR/bin:$PATH"
export PKG_CONFIG="$ENV_DIR/bin/pkg-config"
export PKG_CONFIG_PATH="$ENV_DIR/lib/pkgconfig:$ENV_DIR/share/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"      # no other .pc files are searched
# stringi uses the ICU it ships with, never one found on the machine.
export STRINGI_DISABLE_PKG_CONFIG=1
export R_LIBS_USER="$ENV_DIR/Rlib"
