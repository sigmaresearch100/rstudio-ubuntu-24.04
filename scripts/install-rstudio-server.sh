#!/usr/bin/env bash
# install-rstudio-server.sh
# shellcheck shell=bash

set -Eeuo pipefail
IFS=$'\n\t'

# -------------------- Config --------------------
# Usage:
#   ./install-rstudio-server.sh                # installs latest stable
#   ./install-rstudio-server.sh preview        # latest preview
#   ./install-rstudio-server.sh 2025.05.1+513  # exact version
#
# Env overrides:
#   RSTUDIO_VERSION=stable|preview|daily|<ver>
#   DEFAULT_USER=rstudio (optional; only used to ensure a login-capable user)

RSTUDIO_VERSION=${1:-${RSTUDIO_VERSION:-stable}}
DEFAULT_USER=${DEFAULT_USER:-rstudio}

# -------------------- Root check --------------------
if [[ ${EUID:-0} -ne 0 ]]; then
  printf 'Please run as root (sudo).\n' >&2
  exit 1
fi

# -------------------- OS / arch --------------------
# shellcheck source=/dev/null
source /etc/os-release

ARCH="$(dpkg --print-architecture)"     # e.g., amd64 or arm64
UBU="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

# Normalize codename for download endpoints
# Stable/preview/daily redirect lacks a "noble" path; use jammy builds on 24.04.
if [[ "${UBU}" == "noble" ]]; then
  UBU_DL="jammy"
else
  UBU_DL="${UBU}"
fi

# -------------------- Helpers --------------------
WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

apt_update_if_needed() {
  # Update only if apt lists are empty or missing
  if [[ ! -d /var/lib/apt/lists ]] || \
     [[ "$(find /var/lib/apt/lists -maxdepth 1 -type f 2>/dev/null | wc -l)" = "0" ]]; then
    apt-get update
  fi
}

apt_install() {
  # Install only missing packages; avoid word-splitting with arrays
  local -a want missing
  want=("$@")
  missing=()
  local pkg
  for pkg in "${want[@]}"; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
      missing+=("${pkg}")
    fi
  done
  if ((${#missing[@]})); then
    apt_update_if_needed
    apt-get install -y --no-install-recommends "${missing[@]}"
  fi
}

safe_append_kv() {
  # Append key=value to a file if the key is not already present (or replace it)
  # Usage: safe_append_kv /path/to/file key value
  local file key value tmp
  file="$1"; key="$2"; value="$3"
  tmp="$(mktemp)"
  touch "${file}"
  if grep -qE "^[[:space:]]*${key}=" "${file}"; then
    # Replace existing line
    sed -E "s|^[[:space:]]*${key}=.*|${key}=${value}|" "${file}" > "${tmp}"
  else
    # Append new line
    cat "${file}" > "${tmp}"
    printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
  fi
  install -m 0644 "${tmp}" "${file}"
  rm -f "${tmp}"
}

# -------------------- Base deps --------------------
apt_install ca-certificates gdebi-core git libssl-dev lsb-release psmisc sudo wget

# -------------------- Download --------------------
DEB="${WORKDIR}/rstudio-server.deb"

download_latest_channel() {
  # channel = stable | preview | daily
  local channel="$1"
  wget -q -O "${DEB}" \
    "https://rstudio.org/download/latest/${channel}/server/${UBU_DL}/rstudio-server-latest-${ARCH}.deb"
}

download_exact_version() {
  # ver like 2025.05.1+513 ; upstream uses "-" instead of "+"
  local ver="$1"
  local ver_dash="${ver//+/-}"
  local -a urls=(
    "https://download2.rstudio.org/server/${UBU_DL}/${ARCH}/rstudio-server-${ver_dash}-${ARCH}.deb"
    "https://s3.amazonaws.com/rstudio-ide-build/server/${UBU_DL}/${ARCH}/rstudio-server-${ver_dash}-${ARCH}.deb"
  )
  local u
  for u in "${urls[@]}"; do
    if wget -q -O "${DEB}" "${u}"; then
      return 0
    fi
  done
  printf 'Could not fetch RStudio Server version %s for %s/%s\n' "${ver}" "${UBU_DL}" "${ARCH}" >&2
  exit 2
}

case "${RSTUDIO_VERSION}" in
  latest) RSTUDIO_VERSION="stable" ;;
esac

if [[ "${RSTUDIO_VERSION}" =~ ^(stable|preview|daily)$ ]]; then
  download_latest_channel "${RSTUDIO_VERSION}"
else
  download_exact_version "${RSTUDIO_VERSION}"
fi

# -------------------- Install --------------------
gdebi --non-interactive "${DEB}"

# Make sure binaries are on PATH for convenience (idempotent)
install -d -m 0755 /usr/local/bin
ln -sfn /usr/lib/rstudio-server/bin/rstudio-server /usr/local/bin/rstudio-server
ln -sfn /usr/lib/rstudio-server/bin/rserver        /usr/local/bin/rserver

# -------------------- R / RStudio config --------------------
# Ensure /etc/R exists (RStudio expects it)
install -d -m 0755 /etc/R

# Point RStudio to the active R if found (useful with /usr/local builds)
install -d -m 0755 /etc/rstudio
if R_BIN="$(command -v R)"; then
  safe_append_kv "/etc/rstudio/rserver.conf" "rsession-which-r" "${R_BIN}"
fi

# Use advisory locks (helps on shared volumes/NFS)
safe_append_kv "/etc/rstudio/file-locks" "lock-type" "advisory"

# Optional: create a no-auth config (ONLY for trusted networks; disabled by default)
# We keep a copy you can swap in manually.
if [[ -f /etc/rstudio/rserver.conf ]]; then
  install -m 0644 /etc/rstudio/rserver.conf /etc/rstudio/disable_auth_rserver.conf
else
  : > /etc/rstudio/disable_auth_rserver.conf
  chmod 0644 /etc/rstudio/disable_auth_rserver.conf
fi
safe_append_kv "/etc/rstudio/disable_auth_rserver.conf" "auth-none" "1"

# -------------------- Clean apt lists --------------------
# (do this after all apt operations)
rm -rf /var/lib/apt/lists/*

# -------------------- Ensure a login-capable user --------------------
if ! id -u "${DEFAULT_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEFAULT_USER}"
  usermod -aG sudo "${DEFAULT_USER}"
fi

# -------------------- Enable & start service --------------------
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now rstudio-server.service
else
  # Fallback for systems without systemd
  if command -v rstudio-server >/dev/null 2>&1; then
    rstudio-server restart || rstudio-server start || true
  fi
fi

printf 'RStudio Server version:\n'
if command -v rstudio-server >/dev/null 2>&1; then
  rstudio-server version || true
else
  printf '(rstudio-server not in PATH?)\n' >&2
fi

printf 'Done. Visit: http://<server-ip>:8787\n'
