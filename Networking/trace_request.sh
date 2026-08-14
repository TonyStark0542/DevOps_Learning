#!/usr/bin/env bash
#
# trace-request.sh — walk one domain through every network layer in order:
# DNS -> routing -> TCP reachability -> TLS cert -> HTTP status.
#
# Usage: ./trace-request.sh example.com

set -uo pipefail
# Deliberately NOT using 'set -e' — a failed check (e.g. port closed) is an
# expected, informative outcome here, not a bug that should kill the script.

# ---------- colors (fall back to plain text if not a terminal) ----------
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

section() { printf "\n${BOLD}== %s ==${RESET}\n" "$1"; }
ok()      { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
fail()    { printf "  ${RED}✗${RESET} %s\n" "$1"; }

# ---------- argument check ----------
if [ $# -ne 1 ]; then
  echo "Usage: $0 <domain>" >&2
  echo "Example: $0 example.com" >&2
  exit 1
fi
DOMAIN="$1"

# ---------- required-command check, up front, before any real work ----------
# This is the whole point of checking early: fail with one clear message now,
# instead of dying mid-script with a cryptic "command not found" three stages in.
REQUIRED_CMDS=(dig curl openssl)
OPTIONAL_CMDS=(ping traceroute nc)
missing=()

for cmd in "${REQUIRED_CMDS[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if [ ${#missing[@]} -gt 0 ]; then
  fail "Missing required command(s): ${missing[*]}"
  echo "  Install them first, e.g.: sudo apt install dnsutils curl openssl" >&2
  exit 1
fi

# Track which optional tools are present so later sections can skip cleanly
# instead of guessing and failing halfway through a check.
HAVE_PING=0;  command -v ping        >/dev/null 2>&1 && HAVE_PING=1
HAVE_TRACE=0; command -v traceroute  >/dev/null 2>&1 && HAVE_TRACE=1
HAVE_NC=0;    command -v nc          >/dev/null 2>&1 && HAVE_NC=1

for cmd in "${OPTIONAL_CMDS[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || warn "Optional command '$cmd' not found — its section will be skipped."
done

echo -e "\n${BOLD}Tracing: $DOMAIN${RESET}"

# ============================================================
# STAGE 1 — DNS: resolve the name, show the record and its TTL
# ============================================================
section "1. DNS resolution"

DIG_OUT=$(dig +noall +answer "$DOMAIN" A 2>/dev/null)

if [ -z "$DIG_OUT" ]; then
  fail "No A record found for $DOMAIN — resolution failed. Stopping here, nothing downstream can work without an address."
  exit 1
fi

echo "$DIG_OUT" | while read -r name ttl class type ip; do
  ok "$name -> $ip  (type $type, TTL ${ttl}s = $((ttl/60))m $((ttl%60))s remaining before this is re-checked)"
done

# Grab the first resolved IP for the stages below
RESOLVED_IP=$(dig +short "$DOMAIN" A | head -n1)
if [ -z "$RESOLVED_IP" ]; then
  fail "Could not extract a usable IP from the DNS answer. Stopping."
  exit 1
fi

# ============================================================
# STAGE 2 — Routing: is there a path there at all
# ============================================================
section "2. Network path"

if [ "$HAVE_PING" -eq 1 ]; then
  if PING_OUT=$(ping -c 3 -W 2 "$DOMAIN" 2>&1); then
    LOSS=$(echo "$PING_OUT" | grep -oE '[0-9]+% packet loss' || echo "unknown loss")
    AVG=$(echo "$PING_OUT" | tail -1 | grep -oE 'min/avg/max[^=]*= [0-9.]+/[0-9.]+' | grep -oE '[0-9.]+ms?$|[0-9.]+$' | tail -1)
    ok "ping reachable — $LOSS"
  else
    warn "ping got no reply (packet loss or ICMP blocked — common on cloud/firewalled hosts, not necessarily a real problem)"
  fi
else
  warn "ping not installed — skipping reachability check"
fi

if [ "$HAVE_TRACE" -eq 1 ]; then
  echo "  Route (first 8 hops):"
  timeout 10 traceroute -m 8 -w 1 "$DOMAIN" 2>/dev/null | tail -n +2 | sed 's/^/    /'
else
  warn "traceroute not installed — skipping path trace"
fi

# ============================================================
# STAGE 3 — TCP reachability on 80 and 443
# ============================================================
section "3. TCP reachability (ports 80 / 443)"

check_port() {
  local port="$1"
  local start end elapsed
  start=$(date +%s%N)
  if [ "$HAVE_NC" -eq 1 ]; then
    if timeout 5 nc -z -w 4 "$DOMAIN" "$port" 2>/dev/null; then
      end=$(date +%s%N); elapsed=$(( (end - start) / 1000000 ))
      ok "port $port open (connected in ${elapsed}ms)"
      return 0
    else
      end=$(date +%s%N); elapsed=$(( (end - start) / 1000000 ))
      if [ "$elapsed" -ge 3900 ]; then
        fail "port $port — timeout (no response at all — likely a firewall dropping silently, not the app)"
      else
        fail "port $port — refused (something answered and said no — host is up, nothing listening on $port)"
      fi
      return 1
    fi
  else
    # Fallback with bash's own /dev/tcp if nc isn't available
    if timeout 5 bash -c "echo > /dev/tcp/$DOMAIN/$port" 2>/dev/null; then
      ok "port $port open"
      return 0
    else
      fail "port $port — unreachable (refused or timed out; install 'nc' for a clearer distinction)"
      return 1
    fi
  fi
}

check_port 80
PORT_443_OPEN=1
check_port 443 || PORT_443_OPEN=0

# ============================================================
# STAGE 4 — TLS certificate: issuer and expiry
# ============================================================
section "4. TLS certificate"

if [ "$PORT_443_OPEN" -eq 0 ]; then
  warn "Skipping TLS check — port 443 wasn't reachable in stage 3."
else
  CERT_TEXT=$(echo | timeout 8 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | \
              openssl x509 -noout -issuer -subject -dates 2>/dev/null)

  if [ -z "$CERT_TEXT" ]; then
    fail "Could not retrieve a certificate — TLS handshake may have failed"
  else
    ISSUER=$(echo "$CERT_TEXT" | grep '^issuer=' | sed 's/^issuer=//')
    SUBJECT=$(echo "$CERT_TEXT" | grep '^subject=' | sed 's/^subject=//')
    NOT_AFTER=$(echo "$CERT_TEXT" | grep '^notAfter=' | sed 's/^notAfter=//')
    NOT_BEFORE=$(echo "$CERT_TEXT" | grep '^notBefore=' | sed 's/^notBefore=//')

    ok "Subject : $SUBJECT"
    ok "Issuer  : $ISSUER"
    ok "Valid   : $NOT_BEFORE  ->  $NOT_AFTER"

    # Work out days until expiry so this is actually actionable, not just decorative
    EXP_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    if [ -n "$EXP_EPOCH" ]; then
      DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))
      if [ "$DAYS_LEFT" -lt 0 ]; then
        fail "Certificate EXPIRED $(( -DAYS_LEFT )) day(s) ago"
      elif [ "$DAYS_LEFT" -lt 14 ]; then
        warn "Certificate expires in $DAYS_LEFT day(s) — renew soon"
      else
        ok "Certificate expires in $DAYS_LEFT day(s)"
      fi
    fi
  fi
fi

# ============================================================
# STAGE 5 — HTTP: fetch headers, report status code
# ============================================================
section "5. HTTP response"

for scheme in https http; do
  URL="$scheme://$DOMAIN"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -I "$URL" 2>/dev/null)

  if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
    fail "$URL — no response (connection failed or timed out)"
    continue
  fi

  case "$HTTP_CODE" in
    2??) ok "$URL -> $HTTP_CODE" ;;
    3??) LOCATION=$(curl -s -o /dev/null -D - --max-time 8 -I "$URL" 2>/dev/null | grep -i '^location:' | tr -d '\r')
         warn "$URL -> $HTTP_CODE (redirect) $LOCATION" ;;
    4??) warn "$URL -> $HTTP_CODE (client error)" ;;
    5??) fail "$URL -> $HTTP_CODE (server error)" ;;
    *)   warn "$URL -> $HTTP_CODE" ;;
  esac
done

section "Done"
echo "Traced $DOMAIN through DNS, routing, TCP, TLS, and HTTP."
