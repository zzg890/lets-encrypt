#!/usr/bin/env bash
# Obtain a Let's Encrypt certificate (via certbot, HTTP-01 standalone) and
# export it as a PFX (PKCS#12) file. Intended for Ubuntu 26.04.
set -euo pipefail

usage() {
  cat <<USAGE
Usage: sudo $0 -d DOMAIN [-d DOMAIN2 ...] -e EMAIL [-p PFX_PASSWORD] [-o OUTPUT_DIR] [-s] [-m MODE]

  -d  Domain name (repeatable; first one is the primary name)
  -e  Contact email for Let's Encrypt registration
  -p  PFX export password (default: prompt; empty allowed only via -p "")
  -o  Output directory (default: current directory)
  -m  Challenge mode: standalone (default, needs port 80 free) or webroot:/path
  -s  Use the Let's Encrypt staging server (for testing)
  -h  Show this help

Output: OUTPUT_DIR/<primary-domain>.pfx
USAGE
}

DOMAINS=(); EMAIL=""; PFX_PASS=""; PASS_SET=0; OUT_DIR="$PWD"; STAGING=0; MODE="standalone"
while getopts "d:e:p:o:m:sh" opt; do
  case "$opt" in
    d) DOMAINS+=("$OPTARG") ;;
    e) EMAIL="$OPTARG" ;;
    p) PFX_PASS="$OPTARG"; PASS_SET=1 ;;
    o) OUT_DIR="$OPTARG" ;;
    m) MODE="$OPTARG" ;;
    s) STAGING=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ ${#DOMAINS[@]} -gt 0 && -n "$EMAIL" ]] || { usage; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Please run as root (sudo)." >&2; exit 1; }

if [[ $PASS_SET -eq 0 ]]; then
  read -rsp "PFX password: " PFX_PASS; echo
fi

if ! command -v certbot >/dev/null || ! command -v openssl >/dev/null; then
  apt-get update
  apt-get install -y certbot openssl
fi

args=(certonly --non-interactive --agree-tos -m "$EMAIL" --cert-name "${DOMAINS[0]}")
for d in "${DOMAINS[@]}"; do args+=(-d "$d"); done
case "$MODE" in
  standalone) args+=(--standalone) ;;
  webroot:*)  args+=(--webroot -w "${MODE#webroot:}") ;;
  *) echo "Invalid mode: $MODE" >&2; exit 1 ;;
esac
[[ $STAGING -eq 1 ]] && args+=(--staging)

certbot "${args[@]}"

LIVE="/etc/letsencrypt/live/${DOMAINS[0]}"
mkdir -p "$OUT_DIR"
PFX="$OUT_DIR/${DOMAINS[0]}.pfx"
umask 077
PFX_PASS="$PFX_PASS" openssl pkcs12 -export \
  -inkey "$LIVE/privkey.pem" -in "$LIVE/cert.pem" -certfile "$LIVE/chain.pem" \
  -name "${DOMAINS[0]}" -out "$PFX" -passout env:PFX_PASS

echo "PFX written to $PFX"
echo "Renewal: certbot renew (re-run this script's export step afterwards, e.g. via --deploy-hook)."
