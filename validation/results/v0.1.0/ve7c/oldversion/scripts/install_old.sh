#!/usr/bin/env bash
# Section 11: try to install the paper's older versions, each in its OWN library under /work/oldlibs/<name>. Reports installed / not testable per method.
mkdir -p /work/oldlibs/ALDEx2_1.22.0 /work/oldlibs/ANCOMBC_1.0.5 /work/oldlibs/lefse_1.0.8
R --version | head -1; python3 --version 2>&1; which conda mamba pip3 2>&1 | head
try() { name=$1; url=$2; echo "=== $name from $url"; f=/tmp/$(basename $url); Rscript -e "options(timeout=300); download.file('$url', '$f', quiet=TRUE)" 2>/dev/null && ls -l $f | awk '{print "downloaded", $5, "bytes"}' || { echo "RESULT $name: NOT TESTABLE (download failed)"; return; }
  R CMD INSTALL -l /work/oldlibs/$name $f > /work/oldlibs/$name.install.log 2>&1 && Rscript -e "library(${3}, lib.loc='/work/oldlibs/$name'); cat('loaded', as.character(packageVersion('${3}', lib.loc='/work/oldlibs/$name')), '\n')" 2>&1 | tail -2 && echo "RESULT $name: INSTALLED AND LOADS" || { echo "RESULT $name: NOT TESTABLE (install or load failed)"; tail -8 /work/oldlibs/$name.install.log; }; }
try ALDEx2_1.22.0 https://bioconductor.org/packages/3.12/bioc/src/contrib/ALDEx2_1.22.0.tar.gz ALDEx2
try ANCOMBC_1.0.5 https://bioconductor.org/packages/3.12/bioc/src/contrib/ANCOMBC_1.0.5.tar.gz ANCOMBC
echo "=== LEfSe 1.0.8 (the Huttenhower tool, python, not the R lefser the engine uses)"
python3 - <<'PY'
import json, urllib.request
for pkg in ("lefse",):
    try:
        d = json.load(urllib.request.urlopen("https://pypi.org/pypi/%s/json" % pkg, timeout=60))
        print("PyPI", pkg, "versions:", sorted(d["releases"].keys())[:20])
        print("RESULT lefse_1.0.8:", "AVAILABLE on PyPI" if "1.0.8" in d["releases"] else "NOT TESTABLE here (1.0.8 not on PyPI; the tool is distributed through conda/bioconda and Galaxy, not installable in this R image)")
    except Exception as e:
        print("RESULT lefse_1.0.8: NOT TESTABLE (PyPI lookup failed:", e, ")")
PY
echo "FINISHED"
