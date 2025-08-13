#!/usr/bin/env bash
# install-r-from-source.sh
# shellcheck shell=bash

set -Eeuo pipefail
IFS=$'\n\t'

# ---------- Config ----------
# Usage: ./install-r-from-source.sh [latest|patched|devel|<version>]
R_VERSION=${1:-${R_VERSION:-"latest"}}
PURGE_BUILDDEPS=${PURGE_BUILDDEPS:-"true"}
R_HOME=${R_HOME:-"/usr/local/lib/R"}
export DEBIAN_FRONTEND=noninteractive
: "${TZ:="UTC"}"
export TZ

# ---------- Helpers ----------
cleanup() {
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

WORKDIR="$(mktemp -d)"
cd "${WORKDIR}"

# Detect Ubuntu codename (noble for 24.04)
# shellcheck source=/dev/null
source /etc/os-release

# ---------- APT: base setup ----------
apt-get update
apt-get install -y --no-install-recommends locales tzdata

# Locale (avoid interactive prompts)
LANG=${LANG:-"en_US.UTF-8"}
/usr/sbin/locale-gen --lang "${LANG}"
/usr/sbin/update-locale --reset LANG="${LANG}"

# --- Runtime libs R itself will dynamically use ---
# Prefer OpenBLAS; keep LAPACK. Add XML and Pango/Cairo.
read -r -d '' _RUNTIME_PKGS <<'PKGS'
bash-completion
ca-certificates
file
fonts-texgyre
g++
gfortran
gsfonts
libopenblas-dev
liblapack-dev
libbz2-1.0
libcurl4
libicu74
libjpeg-turbo8
libpcre2-8-0
libpng16-16
libreadline8
libtiff6
liblzma5
libxml2
libxt6
make
tzdata
unzip
zip
zlib1g
wget
libpangocairo-1.0-0
PKGS
# Turn the newline list into a bash array
mapfile -t RUNTIME_PKGS < <(printf '%s\n' "${_RUNTIME_PKGS}")

apt-get install -y --no-install-recommends "${RUNTIME_PKGS[@]}"

# --- Build deps for configure/make (dev headers etc.) ---
read -r -d '' _BUILDDEPS <<'PKGS'
curl
devscripts
default-jdk
libbz2-dev
libcairo2-dev
libcurl4-openssl-dev
libjpeg-dev
libicu-dev
libpcre2-dev
libpng-dev
libreadline-dev
libtiff5-dev
liblzma-dev
libxml2-dev
libx11-dev
libxt-dev
libpango1.0-dev
xorg-dev
perl
rsync
subversion
tcl-dev
tk-dev
texinfo
texlive-extra-utils
texlive-fonts-recommended
texlive-fonts-extra
texlive-latex-recommended
texlive-latex-extra
xauth
xfonts-base
xvfb
zlib1g-dev
PKGS
mapfile -t BUILDDEPS < <(printf '%s\n' "${_BUILDDEPS}")

apt-get install -y --no-install-recommends "${BUILDDEPS[@]}"

# ---------- Fetch R source from CRAN (cloud mirror, fallback) ----------
download_r_src() {
  # $1 is a path segment like base/R-latest.tar.gz
  local path="$1"
  if ! wget -q "https://cloud.r-project.org/src/${path}" -O R.tar.gz; then
    wget -q "https://cran.r-project.org/src/${path}" -O R.tar.gz
  fi
}

case "${R_VERSION}" in
  devel)   download_r_src "base-prerelease/R-devel.tar.gz" ;;
  patched) download_r_src "base-prerelease/R-latest.tar.gz" ;;
  latest)  download_r_src "base/R-latest.tar.gz" ;;
  *)
    # e.g., 4.4.1 -> base/R-4/R-4.4.1.tar.gz
    download_r_src "base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz"
    ;;
esac

# Determine top-level directory from tarball safely
R_SRCDIR="$(tar -tzf R.tar.gz | head -n1 | cut -d/ -f1)"
tar -xzf R.tar.gz
cd "${R_SRCDIR}"

# ---------- Configure ----------
# Shared libR + BLAS/LAPACK + Tcl/Tk + recommended pkgs
R_PAPERSIZE=letter \
R_BATCHSAVE="--no-save --no-restore" \
R_BROWSER=xdg-open \
PAGER=/usr/bin/pager \
PERL=/usr/bin/perl \
R_UNZIPCMD=/usr/bin/unzip \
R_ZIPCMD=/usr/bin/zip \
R_PRINTCMD=/usr/bin/lpr \
LIBnn=lib \
AWK=/usr/bin/awk \
CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2" \
CXXFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2" \
./configure \
  --enable-R-shlib \
  --enable-memory-profiling \
  --with-readline \
  --with-blas \
  --with-lapack \
  --with-tcltk \
  --with-recommended-packages

# ---------- Build & install ----------
make -j"$(nproc)"
make install
make clean

# ---------- Site library with group write for shared installs ----------
mkdir -p "${R_HOME}/site-library"
chown root:staff "${R_HOME}/site-library"
chmod g+ws "${R_HOME}/site-library"

# Ensure site library appears first
{
  printf 'R_LIBS=${R_LIBS-'\''%s/site-library:%s/library'\''}\n' "${R_HOME}" "${R_HOME}"
} >>"${R_HOME}/etc/Renviron.site"

# ---------- Post-install cleanup ----------
# Keep checkbashisms for later use before purging devscripts (if desired)
if command -v checkbashisms >/dev/null 2>&1; then
  install -m 0755 "$(command -v checkbashisms)" /usr/local/bin/checkbashisms
fi

if [ "${PURGE_BUILDDEPS}" != "false" ]; then
  apt-get remove --purge -y "${BUILDDEPS[@]}"
fi
apt-get autoremove -y
apt-get autoclean -y
rm -rf /var/lib/apt/lists/*

printf 'Check the R info...\n'
R -q -e "sessionInfo()"
printf '\nInstall R from source, done!\n'
