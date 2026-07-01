#!/bin/bash
#===============================================================================
# ██╗   ██╗██╗  ████████╗██╗███╗   ███╗ █████╗ ████████╗███████╗
# ██║   ██║██║  ╚══██╔══╝██║████╗ ████║██╔══██╗╚══██╔══╝██╔════╝
# ██║   ██║██║     ██║   ██║██╔████╔██║███████║   ██║   █████╗  
# ██║   ██║██║     ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  
# ╚██████╔╝███████╗██║   ██║██║ ╚═╝ ██║██║  ██║   ██║   ███████╗
#  ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
# ██████╗ ██╗   ██╗ ██████╗     ██╗  ██╗██╗   ██╗███╗   ██╗████████╗███████╗██████╗ 
# ██╔══██╗██║   ██║██╔════╝     ██║  ██║██║   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
# ██████╔╝██║   ██║██║  ███╗    ███████║██║   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝
# ██╔══██╗██║   ██║██║   ██║    ██╔══██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗
# ██████╔╝╚██████╔╝╚██████╔╝    ██║  ██║╚██████╔╝██║ ╚████║   ██║   ███████╗██║  ██║
# ╚═════╝  ╚═════╝  ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
#
# ULTIMATE BUG HUNTER AUTOMATION SUITE v5.1 — NCT EDITION
# Author  : NexCore Technologies / Advanced Bug Hunter
# Usage   : sudo ./ultimate_bughunter_v5.sh [OPTIONS] <target.com>
# Version : 5.1.0
# License : For authorized security testing only
#
# NEW IN v5.0:
#   ✦ Parallel phase execution with job control
#   ✦ Subdomain Takeover detection (subjack + nuclei)
#   ✦ WAF Detection & Bypass techniques
#   ✦ API endpoint discovery (swagger, graphql, postman)
#   ✦ Cloud asset discovery (S3, GCS, Azure blobs)
#   ✦ Active XSS hunting with dalfox
#   ✦ SQLi detection with sqlmap
#   ✦ SSRF detection
#   ✦ Open Redirect hunting
#   ✦ LFI/RFI detection
#   ✦ Race condition testing
#   ✦ Prototype pollution detection
#   ✦ Host header injection
#   ✦ 403 bypass techniques
#   ✦ Interactive HTML report with charts
#   ✦ Telegram + Discord + Slack notifications
#   ✦ Resume/retry mode (skip completed phases)
#   ✦ Rate limit & stealth mode
#   ✦ Auto-dependency checker & installer
#   ✦ Custom scope file support
#   ✦ Out-of-scope filtering
#   ✦ Real-time progress dashboard
#   ✦ Severity-sorted JSON output
#   ✦ CVSS scoring integration
#===============================================================================

# Note: set -euo pipefail removed — sourced config files must not set shell options;
# individual phases use explicit error handling with || true

#======================= VERSION =======================
VERSION="5.1.0"
CODENAME="NCT-PHANTOM-X"

#======================= DEFAULT CONFIG =======================
DOMAIN=""
BASE_DIR="$HOME/bugbounty"
OUTDIR=""
THREADS=100
HTTPX_THREADS=150
NUCLEI_CONCURRENCY=25
NUCLEI_RATE_LIMIT=150
FFUF_RATE=200
MASSCAN_RATE=10000
NAABU_RATE=5000
TIMEOUT=10
RETRIES=2

# Feature Flags
SKIP_MASSCAN=0
IS_ROOT=0
STEALTH_MODE=0
RESUME_MODE=0
PARALLEL_MODE=1
SCOPE_FILE=""
OUT_OF_SCOPE=""
CUSTOM_RESOLVERS=""
AXIOM_MODE=0
AXIOM_FLEET=""
AXIOM_SPINUP=0
AXIOM_RM_WHEN_DONE=0
AXIOM_SHUTDOWN_WHEN_DONE=0
AXIOM_SELECTED_FILE="$HOME/.axiom/selected.conf"
AXIOM_NUCLEI_TEMPLATES="/home/op/nuclei-templates"

MONITOR_MODE=0
MONITOR_STATE_DIR="$HOME/.bughunter-monitor"
MONITOR_SCHEDULE="0 3 * * *"
MONITOR_WRITE_CRON=0

REPO_OSINT_MODE=1
GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN=""
GITLAB_API_URL="https://gitlab.com/api/v4"
GITLAB_TOKEN=""
REPO_SEARCH_PAGES=2
REPO_SEARCH_PER_PAGE=25
REPO_MAX_CLONES=20
REPO_CLONE_DEPTH=50
REPO_INCLUDE_FORKS=0
REPO_GITLEAKS_MODE=1
REPO_TRUFFLEHOG_MODE=1

RESPECTFUL_MODE=0
WAF_AWARE=0
AUTO_SLOW_ON_BLOCK=1
AUTO_SKIP_NOISY_ON_BLOCK=1
STATIC_PROXY=""
CONTACT_EMAIL=""
CUSTOM_USER_AGENT="UltimateBugHunter/5.0 (authorized testing)"
JITTER_MIN_MS=250
JITTER_MAX_MS=1200
BLOCK_COOLDOWN=90
BLOCK_SIGNAL_THRESHOLD=10


# Notification
DISCORD_WEBHOOK=""
SLACK_WEBHOOK=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# ── OOB / Out-of-Band Detection ──
INTERACTSH_SERVER="oast.pro"          # interactsh public server
BURP_COLLABORATOR=""                  # optional: your Burp Collaborator domain
OOB_DOMAIN=""                         # auto-set at runtime
OOB_WAIT_SECONDS=60                   # how long to wait for callbacks

# ── Intelligence APIs ──
SHODAN_API_KEY=""                     # https://account.shodan.io
CENSYS_API_ID=""                      # https://censys.io/account
CENSYS_API_SECRET=""
FOFA_EMAIL=""                         # https://fofa.info
FOFA_KEY=""
HUNTER_API_KEY=""                     # https://hunter.io
VIRUSTOTAL_API_KEY=""                 # https://virustotal.com
SECURITYTRAILS_API_KEY=""            # https://securitytrails.com
FULLHUNT_API_KEY=""                   # https://fullhunt.io
NVD_API_KEY=""                        # https://nvd.nist.gov/developers

# ── AI Analysis — multi-provider ──
# AI_PROVIDER: codex | openrouter
AI_PROVIDER="codex"
AI_ANALYSIS_ENABLED=0

# Universal model override — set this to use the same model regardless of provider.
# Leave empty to use the provider-specific model below.
AI_ANALYSIS_MODEL=""

# Codex (ChatGPT Plus) — no API key; run `codex login` once
CODEX_MODEL="gpt-5.4-mini"           # gpt-5.4-mini | gpt-5.4-pro | gpt-5.5-pro

# OpenRouter — https://openrouter.ai/keys
OPENROUTER_API_KEY=""
OPENROUTER_MODEL="anthropic/claude-haiku-4-5"  # any model at openrouter.ai/models

# ── Network Recon ──
BGPVIEW_API="https://api.bgpview.io"
ASN_LOOKUP_ENABLED=1
CDN_BYPASS_ENABLED=1
PASSIVE_DNS_ENABLED=1

# ── Infrastructure Exposure ──
DB_PORTS=(6379 27017 5432 3306 9200 9300 5984 8086 11211 7474 9042)
K8S_PORTS=(6443 8080 10250 10255 2379 2380 4194)
DOCKER_PORTS=(2375 2376 2377 4243)

# ── Feature Toggles (new phases) ──
OOB_MODE=1
NETWORK_RECON_MODE=1
SSTI_XXE_MODE=1
GRAPHQL_AUDIT_MODE=1
WEBSOCKET_MODE=1
SMUGGLING_MODE=1
INTEL_API_MODE=1
INFRA_EXPOSURE_MODE=1
AI_MODE=0                             # disabled by default (needs API key)
CVE_CORRELATION_MODE=1

# ── Self-hosted interactsh (optional — most reliable OOB) ──
INTERACTSH_SELF_HOST=""           # e.g. oob.yourdomain.com (requires DNS control)
INTERACTSH_IP=""                  # public IP of your server
INTERACTSH_TOKEN=""               # auth token for self-hosted server

# Wordlists
WORDLIST_DNS="/usr/share/wordlists/seclists/Discovery/DNS/dns-Jhaddix.txt"
WORDLIST_DNS_FALLBACK="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
WORDLIST_DIR="/usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt"
WORDLIST_PARAMS="/usr/share/wordlists/seclists/Discovery/Web-Content/burp-parameter-names.txt"
RESOLVERS="$HOME/tools/resolvers.txt"

# Tool paths (auto-detected)
NUCLEI_TEMPLATES="$HOME/nuclei-templates"
GHAURI_PATH=$(which ghauri 2>/dev/null || echo "")
SQLMAP_PATH=$(which sqlmap 2>/dev/null || echo "")
DALFOX_PATH=$(which dalfox 2>/dev/null || echo "")
WEBSOCAT_PATH=$(which websocat 2>/dev/null || echo "")
PUREDNS_PATH=$(which puredns 2>/dev/null || echo "")
DNSX_PATH=$(which dnsx 2>/dev/null || echo "")
WAYMORE_PATH=$(which waymore 2>/dev/null || echo "")
ARJUN_PATH=$(which arjun 2>/dev/null || echo "")
CARIDDI_PATH=$(which cariddi 2>/dev/null || echo "")
GRAPHW00F_PATH=$(which graphw00f 2>/dev/null || echo "")
CHAOS_PATH=$(which chaos 2>/dev/null || echo "")
SQLMC_PATH=$(which sqlmc 2>/dev/null || echo "")

#======================= COLORS & SYMBOLS =======================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'

TICK="✓"
CROSS="✗"
WARN="!"
INFO="i"
SKULL="☠"
TARGET="◉"
FIRE="🔥"
KEY="🔑"
BUG="🐛"
LOCK="🔒"
GLOBE="🌐"
SCAN="⚡"

#======================= PHASE TRACKING =======================
declare -A PHASE_STATUS
declare -A PHASE_DURATION
COMPLETED_PHASES_FILE=""
