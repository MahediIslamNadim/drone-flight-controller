banner() {
    clear
    echo -e "${CYAN}"
    cat << 'ASCIIEOF'
 ██╗   ██╗██████╗ ██╗  ████████╗██╗███╗   ███╗ █████╗ ████████╗███████╗
 ██║   ██║██╔══██╗██║  ╚══██╔══╝██║████╗ ████║██╔══██╗╚══██╔══╝██╔════╝
 ██║   ██║██║  ██║██║     ██║   ██║██╔████╔██║███████║   ██║   █████╗  
 ██║   ██║██║  ██║██║     ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  
 ╚██████╔╝██████╔╝███████╗██║   ██║██║ ╚═╝ ██║██║  ██║   ██║   ███████╗
  ╚═════╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
ASCIIEOF
    echo -e "${NC}"
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${GREEN}   ULTIMATE BUG HUNTER AUTOMATION SUITE v5.1 — NCT-PHANTOM-X   ${WHITE}║${NC}"
    echo -e "${WHITE}║${CYAN}    Subdomain→Alive→Ports→URLs→Dorks→Vulns→XSS→SQLi→Report    ${WHITE}║${NC}"
    echo -e "${WHITE}║${YELLOW}              ⚡ PARALLEL · STEALTHY · SMART ⚡                ${WHITE}║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#======================= USAGE =======================
usage() {
    echo -e "${WHITE}USAGE:${NC}"
    echo -e "  sudo $0 [OPTIONS] <target.com>"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo -e "  -d, --domain       Target domain (required)"
    echo -e "  -o, --output       Output directory (default: ~/bugbounty/DOMAIN-DATE)"
    echo -e "  -t, --threads      Thread count (default: 100)"
    echo -e "  -s, --scope        Scope file (list of in-scope domains)"
    echo -e "  -x, --exclude      Out-of-scope domains file"
    echo -e "  -r, --resume       Resume from last completed phase"
    echo -e "  -S, --stealth      Stealth mode (slower, less noisy)"
    echo -e "  -P, --no-parallel  Disable parallel execution"
    echo -e "  -R, --respectful-scan Enable WAF-aware low-noise scan mode"
    echo -e "  --waf-aware        Auto-slow or skip noisy phases on WAF/block signals"
    echo -e "  --proxy            Route supported tools through one approved proxy"
    echo -e "  --contact          Contact email for audit-friendly request headers"
    echo -e "  --user-agent       Custom User-Agent for scan traffic"
    echo -e "  --jitter-ms        Random per-request delay range, format min:max"
    echo -e "  --block-cooldown   Cooldown seconds after repeated 403/429/503 signals"
    echo -e "  -M, --monitor      Enable continuous monitoring diff mode"
    echo -e "  --monitor-state    Monitoring state directory"
    echo -e "  --monitor-schedule Cron schedule for generated monitor job"
    echo -e "  --monitor-write-cron Generate cron helper files in reports/"
    echo -e "  --no-repo-osint    Disable GitHub/GitLab repository OSINT checks"
    echo -e "  --github-token     GitHub API token for higher-rate repo search"
    echo -e "  --gitlab-token     GitLab API token for repo/group search"
    echo -e "  --repo-max         Maximum repositories to clone and scan"
    echo -e "  --repo-depth       Git clone depth for repo leak scanning"
    echo -e "  --repo-pages       Search pages to request per provider"
    echo -e "  --repo-include-forks Include public forks in repo inventory"
    echo -e "  --discord          Discord webhook URL"
    echo -e "  --slack            Slack webhook URL"
    echo -e "  --telegram-token   Telegram bot token"
    echo -e "  --telegram-chat    Telegram chat ID"
    echo -e "  --skip-masscan     Skip masscan (no root needed)"
    echo -e "  -A, --axiom        Enable Axiom distributed scanning mode"
    echo -e "  --fleet            Specify Axiom fleet name (optional)"
    echo -e "  --axiom-spinup     Auto-create N Axiom instances before scan"
    echo -e "  --axiom-rm         Destroy spun-up Axiom instances after scan"
    echo -e "  --axiom-shutdown   Shut down Axiom instances after scan"
    echo -e "  --axiom-templates  Remote nuclei templates path on Axiom nodes"
    echo -e "  -h, --help         Show this help"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo -e "  sudo $0 -d hackerone.com"
    echo -e "  sudo $0 -d target.com --stealth --discord https://hooks.slack.com/..."
    echo -e "  sudo $0 -d target.com -R --waf-aware --contact security@example.com"
    echo -e "  sudo $0 -d target.com -A --fleet myfleet"
    echo -e "  sudo $0 -d target.com -A --fleet recon --axiom-spinup 8 --axiom-rm"
    echo -e "  sudo $0 -d target.com --github-token ghp_xxx --repo-max 30"
    echo -e "  sudo $0 -d target.com -M --monitor-write-cron"
    echo -e "  $0 -d target.com --skip-masscan"
    exit 0
}

#======================= ARGUMENT PARSER =======================
parse_args() {
    if [ $# -eq 0 ]; then
        usage
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain) DOMAIN="$2"; shift 2 ;;
            -o|--output) OUTDIR="$2"; shift 2 ;;
            -t|--threads) THREADS="$2"; shift 2 ;;
            -s|--scope) SCOPE_FILE="$2"; shift 2 ;;
            -x|--exclude) OUT_OF_SCOPE="$2"; shift 2 ;;
            -r|--resume) RESUME_MODE=1; shift ;;
            -S|--stealth) STEALTH_MODE=1; shift ;;
            -P|--no-parallel) PARALLEL_MODE=0; shift ;;
            -R|--respectful-scan) RESPECTFUL_MODE=1; WAF_AWARE=1; shift ;;
            --waf-aware) WAF_AWARE=1; shift ;;
            --proxy)
                if ! [[ "$2" =~ ^(https?|socks[45])://[^[:space:]].* ]]; then
                    echo -e "${RED}[ERROR]${NC} --proxy must be a valid URL (http://, https://, socks4://, socks5://)"
                    exit 1
                fi
                STATIC_PROXY="$2"; shift 2 ;;
            --contact) CONTACT_EMAIL="$2"; shift 2 ;;
            --user-agent) CUSTOM_USER_AGENT="$2"; shift 2 ;;
            --jitter-ms)
                IFS=':' read -r JITTER_MIN_MS JITTER_MAX_MS <<< "$2"
                shift 2
                ;;
            --block-cooldown) BLOCK_COOLDOWN="$2"; shift 2 ;;
            -M|--monitor) MONITOR_MODE=1; shift ;;
            --monitor-state) MONITOR_STATE_DIR="$2"; MONITOR_MODE=1; shift 2 ;;
            --monitor-schedule) MONITOR_SCHEDULE="$2"; MONITOR_MODE=1; shift 2 ;;
            --monitor-write-cron) MONITOR_WRITE_CRON=1; MONITOR_MODE=1; shift ;;
            --no-repo-osint) REPO_OSINT_MODE=0; shift ;;
            --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
            --gitlab-token) GITLAB_TOKEN="$2"; shift 2 ;;
            --repo-max) REPO_MAX_CLONES="$2"; shift 2 ;;
            --repo-depth) REPO_CLONE_DEPTH="$2"; shift 2 ;;
            --repo-pages) REPO_SEARCH_PAGES="$2"; shift 2 ;;
            --repo-include-forks) REPO_INCLUDE_FORKS=1; shift ;;
            --discord) DISCORD_WEBHOOK="$2"; shift 2 ;;
            --slack) SLACK_WEBHOOK="$2"; shift 2 ;;
            --telegram-token) TELEGRAM_BOT_TOKEN="$2"; shift 2 ;;
            --telegram-chat) TELEGRAM_CHAT_ID="$2"; shift 2 ;;
            --skip-masscan) SKIP_MASSCAN=1; shift ;;
            --wordlist-dns) WORDLIST_DNS="$2"; shift 2 ;;
            -A|--axiom) AXIOM_MODE=1; shift ;;
            --fleet) AXIOM_FLEET="$2"; shift 2 ;;
            --axiom-spinup) AXIOM_SPINUP="$2"; AXIOM_MODE=1; shift 2 ;;
            --axiom-rm) AXIOM_RM_WHEN_DONE=1; AXIOM_MODE=1; shift ;;
            --axiom-shutdown) AXIOM_SHUTDOWN_WHEN_DONE=1; AXIOM_MODE=1; shift ;;
            --axiom-templates) AXIOM_NUCLEI_TEMPLATES="$2"; AXIOM_MODE=1; shift 2 ;;
            -h|--help) usage ;;
            *)
                # Positional argument = domain
                if [ -z "$DOMAIN" ]; then DOMAIN="$1"; fi
                shift ;;
        esac
    done

    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}[ERROR]${NC} No target domain specified!"
        echo -e "Usage: $0 -d <domain.com> OR $0 <domain.com>"
        exit 1
    fi

    if ! [[ "$AXIOM_SPINUP" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[ERROR]${NC} --axiom-spinup must be a non-negative integer"
        exit 1
    fi

    if [ "$AXIOM_RM_WHEN_DONE" -eq 1 ] && [ "$AXIOM_SHUTDOWN_WHEN_DONE" -eq 1 ]; then
        echo -e "${RED}[ERROR]${NC} Choose either --axiom-rm or --axiom-shutdown, not both"
        exit 1
    fi

    if ! [[ "$JITTER_MIN_MS" =~ ^[0-9]+$ ]] || ! [[ "$JITTER_MAX_MS" =~ ^[0-9]+$ ]] || [ "$JITTER_MIN_MS" -gt "$JITTER_MAX_MS" ]; then
        echo -e "${RED}[ERROR]${NC} --jitter-ms must be in min:max format with min <= max"
        exit 1
    fi

    if ! [[ "$BLOCK_COOLDOWN" =~ ^[0-9]+$ ]] || ! [[ "$BLOCK_SIGNAL_THRESHOLD" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[ERROR]${NC} block cooldown and signal threshold must be non-negative integers"
        exit 1
    fi

    if ! [[ "$REPO_MAX_CLONES" =~ ^[0-9]+$ ]] || ! [[ "$REPO_CLONE_DEPTH" =~ ^[0-9]+$ ]] || ! [[ "$REPO_SEARCH_PAGES" =~ ^[0-9]+$ ]] || ! [[ "$REPO_SEARCH_PER_PAGE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[ERROR]${NC} repo OSINT numeric settings must be non-negative integers"
        exit 1
    fi

    if [ -z "$MONITOR_STATE_DIR" ]; then
        echo -e "${RED}[ERROR]${NC} --monitor-state cannot be empty"
        exit 1
    fi

    if [ "$MONITOR_MODE" -eq 1 ] && [ -z "$MONITOR_SCHEDULE" ]; then
        echo -e "${RED}[ERROR]${NC} --monitor-schedule cannot be empty in monitor mode"
        exit 1
    fi

    if [ "$RESPECTFUL_MODE" -eq 1 ]; then
        THREADS=20
        HTTPX_THREADS=30
        NUCLEI_CONCURRENCY=6
        NUCLEI_RATE_LIMIT=20
        MASSCAN_RATE=0
        NAABU_RATE=300
        FFUF_RATE=15
        RETRIES=1
        TIMEOUT=15
        SKIP_MASSCAN=1
    fi

    # Set stealth parameters
    if [ "$STEALTH_MODE" -eq 1 ]; then
        THREADS=30
        HTTPX_THREADS=50
        NUCLEI_CONCURRENCY=10
        NUCLEI_RATE_LIMIT=30
        MASSCAN_RATE=1000
        NAABU_RATE=500
        FFUF_RATE=30
        warning "STEALTH MODE ACTIVE — reduced rates for low noise"
    fi
}

#======================= LOGGING =======================
write_log_line() {
    local LINE="$1"
    local LOG_FILE="${2:-}"

    if [ -n "${OUTDIR:-}" ] && [ -d "$OUTDIR/logs" ] && [ -n "$LOG_FILE" ]; then
        echo -e "$LINE" | tee -a "$LOG_FILE"
    else
        echo -e "$LINE"
    fi
}

log()     { write_log_line "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" "$OUTDIR/logs/master.log"; }
success() { write_log_line "${GREEN}[${TICK}]${NC} $1" "$OUTDIR/logs/master.log"; }
warning() { write_log_line "${YELLOW}[${WARN}]${NC} $1" "$OUTDIR/logs/master.log"; }
error()   {
    local LINE="${RED}[${CROSS}]${NC} $1"
    if [ -n "${OUTDIR:-}" ] && [ -d "$OUTDIR/logs" ]; then
        echo -e "$LINE" | tee -a "$OUTDIR/logs/errors.log" | tee -a "$OUTDIR/logs/master.log"
    else
        echo -e "$LINE"
    fi
}
info()    { write_log_line "${CYAN}[${INFO}]${NC} $1" "$OUTDIR/logs/master.log"; }
vuln()    { write_log_line "${BG_RED}${WHITE}[${SKULL} VULN]${NC} $1" "$OUTDIR/logs/master.log"; }
phase_banner() {
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  ${SCAN} $1"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
}

#======================= NOTIFICATIONS =======================
notify() {
    local MSG="$1"
    local EMOJI="${2:-🎯}"
    local FULL_MSG="$EMOJI BugHunter v5: $MSG"

    # Discord — use jq to safely encode JSON
    if [ -n "$DISCORD_WEBHOOK" ]; then
        local DISCORD_PAYLOAD
        DISCORD_PAYLOAD=$(jq -n --arg content "$FULL_MSG" '{"content": $content}')
        curl -s -X POST -H 'Content-Type: application/json' \
            --data "$DISCORD_PAYLOAD" \
            "$DISCORD_WEBHOOK" > /dev/null 2>&1 &
    fi

    # Slack — use jq to safely encode JSON
    if [ -n "$SLACK_WEBHOOK" ]; then
        local SLACK_PAYLOAD
        SLACK_PAYLOAD=$(jq -n --arg text "$FULL_MSG" '{"text": $text}')
        curl -s -X POST -H 'Content-Type: application/json' \
            --data "$SLACK_PAYLOAD" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1 &
    fi

    # Telegram — use jq to safely encode JSON
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        local TG_PAYLOAD
        TG_PAYLOAD=$(jq -n --arg chat_id "$TELEGRAM_CHAT_ID" --arg text "$FULL_MSG" \
            '{"chat_id": $chat_id, "text": $text}')
        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -H 'Content-Type: application/json' \
            --data "$TG_PAYLOAD" \
            > /dev/null 2>&1 &
    fi
}

notify_vuln() {
    local SEVERITY="$1"
    local FINDING="$2"
    local EMOJI="🚨"
    [ "$SEVERITY" = "critical" ] && EMOJI="💀"
    [ "$SEVERITY" = "high" ]     && EMOJI="🔴"
    [ "$SEVERITY" = "medium" ]   && EMOJI="🟡"
    notify "[$SEVERITY] $FINDING" "$EMOJI"
}

#======================= RESPECTFUL NETWORK HELPERS =======================
sleep_with_jitter() {
    if [ "$JITTER_MAX_MS" -le 0 ]; then
        return
    fi

    local RANGE=$((JITTER_MAX_MS - JITTER_MIN_MS + 1))
    local DELAY_MS="$JITTER_MIN_MS"

    if [ "$RANGE" -gt 1 ]; then
        DELAY_MS=$((JITTER_MIN_MS + RANDOM % RANGE))
    fi

    local SLEEP_SECS
    SLEEP_SECS=$(awk "BEGIN{printf \"%.3f\", $DELAY_MS / 1000}")
    sleep "$SLEEP_SECS" 2>/dev/null || true
}

network_run() {
    sleep_with_jitter

    if [ -n "$STATIC_PROXY" ]; then
        HTTP_PROXY="$STATIC_PROXY" HTTPS_PROXY="$STATIC_PROXY" ALL_PROXY="$STATIC_PROXY" \
        http_proxy="$STATIC_PROXY" https_proxy="$STATIC_PROXY" all_proxy="$STATIC_PROXY" "$@"
    else
        "$@"
    fi
}

curl_safe() {
    sleep_with_jitter

    local CMD=(curl -skL --max-time "$TIMEOUT" --connect-timeout "$TIMEOUT")

    if [ -n "$STATIC_PROXY" ]; then
        CMD+=(--proxy "$STATIC_PROXY")
    fi

    if [ -n "$CUSTOM_USER_AGENT" ]; then
        CMD+=(-A "$CUSTOM_USER_AGENT")
    fi

    if [ -n "$CONTACT_EMAIL" ]; then
        CMD+=(-H "From: $CONTACT_EMAIL")
    fi

    CMD+=("$@")
    "${CMD[@]}"
}

# Use for external API calls (Anthropic, GitHub, Stripe, etc.) — enforces TLS verification
curl_api() {
    local CMD=(curl -sL --max-time 30 --connect-timeout 15)

    if [ -n "$STATIC_PROXY" ]; then
        CMD+=(--proxy "$STATIC_PROXY")
    fi

    CMD+=("$@")
    "${CMD[@]}"
}

# Atomic append for shared output files written by parallel subshells
atomic_append() {
    local FILE="$1"; shift
    (
        flock -w 5 200 2>/dev/null || true
        printf '%s\n' "$*" >> "$FILE"
    ) 200>"${FILE}.lk" 2>/dev/null || printf '%s\n' "$*" >> "$FILE"
}

record_block_signal() {
    local STATUS="$1"
    local TARGET="$2"
    local BLOCK_FILE="$OUTDIR/alive/block_signals.txt"

    case "$STATUS" in
        403|429|503)
            mkdir -p "$OUTDIR/alive"
            echo "[$STATUS] $TARGET" >> "$BLOCK_FILE"
            ;;
    esac
}

current_block_signal_count() {
    wc -l < "$OUTDIR/alive/block_signals.txt" 2>/dev/null || echo 0
}

cooldown_if_waf_pressure() {
    if [ "$AUTO_SLOW_ON_BLOCK" -ne 1 ] || [ "$BLOCK_COOLDOWN" -le 0 ]; then
        return
    fi

    local COUNT
    COUNT=$(current_block_signal_count)

    if [ "$COUNT" -ge "$BLOCK_SIGNAL_THRESHOLD" ]; then
        warning "Block/WAF pressure detected ($COUNT signals). Cooling down for ${BLOCK_COOLDOWN}s"
        sleep "$BLOCK_COOLDOWN"
        : > "$OUTDIR/alive/block_signals.txt"
    fi
}

should_skip_noisy_phase() {
    if [ "$AUTO_SKIP_NOISY_ON_BLOCK" -ne 1 ]; then
        return 1
    fi

    local BLOCK_COUNT
    BLOCK_COUNT=$(current_block_signal_count)

    if [ "$WAF_AWARE" -eq 1 ] && { [ -s "$OUTDIR/alive/waf_detected.txt" ] || [ "$BLOCK_COUNT" -ge "$BLOCK_SIGNAL_THRESHOLD" ]; }; then
        warning "$1 skipped in WAF-aware mode to avoid noisy traffic"
        return 0
    fi

    return 1
}

prepare_respectful_mode() {
    if [ "$RESPECTFUL_MODE" -ne 1 ] && [ "$WAF_AWARE" -ne 1 ] && [ -z "$STATIC_PROXY" ]; then
        return
    fi

    mkdir -p "$OUTDIR/alive"
    : > "$OUTDIR/alive/block_signals.txt"

    [ "$RESPECTFUL_MODE" -eq 1 ] && info "Respectful scan mode enabled"
    [ "$WAF_AWARE" -eq 1 ] && info "WAF-aware throttling enabled"
    [ -n "$STATIC_PROXY" ] && info "Static proxy configured for supported tools"
}

#======================= AXIOM HELPERS =======================
axiom_scan() {
    local INPUT_FILE="$1"
    local MODULE="$2"
    local OUTPUT_FILE="$3"
    shift 3

    local CMD=(axiom-scan "$INPUT_FILE" -m "$MODULE")

    if [ -n "$AXIOM_FLEET" ]; then
        CMD+=(--fleet "$AXIOM_FLEET")
    fi

    if [ "$AXIOM_SPINUP" -gt 0 ]; then
        CMD+=(--spinup "$AXIOM_SPINUP")
    fi

    if [ "$AXIOM_RM_WHEN_DONE" -eq 1 ]; then
        CMD+=(--rm-when-done)
    fi

    if [ "$AXIOM_SHUTDOWN_WHEN_DONE" -eq 1 ]; then
        CMD+=(--shutdown-when-done)
    fi

    if [ -n "$OUTPUT_FILE" ]; then
        CMD+=(-o "$OUTPUT_FILE")
    fi

    CMD+=("$@")
    "${CMD[@]}"
}

prepare_axiom_mode() {
    if [ "$AXIOM_MODE" -ne 1 ]; then
        return
    fi

    log "AXIOM distributed mode enabled"

    if [ -z "$AXIOM_FLEET" ] && [ ! -s "$AXIOM_SELECTED_FILE" ]; then
        error "Axiom mode requires --fleet or an existing selected fleet at $AXIOM_SELECTED_FILE"
        exit 1
    fi

    if [ "$SKIP_MASSCAN" -eq 0 ]; then
        SKIP_MASSCAN=1
        warning "AXIOM MODE ACTIVE - local masscan disabled to avoid burning your local IP; distributed naabu will be used instead"
    fi

    mkdir -p "$OUTDIR/axiom"
    cat > "$OUTDIR/axiom/runtime.env" << EOF
AXIOM_MODE=$AXIOM_MODE
AXIOM_FLEET=$AXIOM_FLEET
AXIOM_SPINUP=$AXIOM_SPINUP
AXIOM_RM_WHEN_DONE=$AXIOM_RM_WHEN_DONE
AXIOM_SHUTDOWN_WHEN_DONE=$AXIOM_SHUTDOWN_WHEN_DONE
AXIOM_SELECTED_FILE=$AXIOM_SELECTED_FILE
AXIOM_NUCLEI_TEMPLATES=$AXIOM_NUCLEI_TEMPLATES
EOF

    if [ -n "$AXIOM_FLEET" ]; then
        info "Axiom fleet: $AXIOM_FLEET"
    else
        info "Axiom fleet: using selected fleet from $AXIOM_SELECTED_FILE"
    fi

    if [ "$AXIOM_SPINUP" -gt 0 ]; then
        info "Axiom auto-spinup: $AXIOM_SPINUP instances"
    fi
}

#======================= DEPENDENCY CHECK =======================
check_dependencies() {
    phase_banner "DEPENDENCY CHECK"

    # Core tools: warn-and-skip if missing (do NOT exit)
    local CORE=(subfinder httpx nuclei ffuf curl jq)
    # Important but skippable
    local IMPORTANT=(assetfinder amass findomain naabu katana gau waybackurls masscan)
    # Optional tools
    local OPTIONAL=(dalfox sqlmap ghauri hakrawler trufflehog gitleaks interactsh-client wscat git whatweb massdns dnsgen subjack arjun anew crontab sourcemapper)

    [ "$AXIOM_MODE" -eq 1 ] && CORE+=("axiom-scan")

    local MISSING_CORE=()
    local MISSING_IMP=()
    local MISSING_OPT=()

    log "Checking core tools..."
    for tool in "${CORE[@]}"; do
        if command -v "$tool" &>/dev/null; then
            success "$tool → $(command -v "$tool")"
        else
            warning "$tool NOT FOUND — related features will be skipped"
            MISSING_CORE+=("$tool")
        fi
    done

    log "Checking important tools..."
    for tool in "${IMPORTANT[@]}"; do
        if command -v "$tool" &>/dev/null; then
            success "$tool → $(command -v "$tool")"
        else
            info "$tool not found (some features disabled)"
            MISSING_IMP+=("$tool")
        fi
    done

    log "Checking optional tools..."
    for tool in "${OPTIONAL[@]}"; do
        if command -v "$tool" &>/dev/null; then
            info "$tool found"
        else
            MISSING_OPT+=("$tool")
        fi
    done

    # Print summary — warn but NEVER exit
    if [ ${#MISSING_CORE[@]} -gt 0 ]; then
        warning "Missing core tools (features degraded): ${MISSING_CORE[*]}"
        echo ""
        echo -e "${YELLOW}Install missing tools:${NC}"
        for tool in "${MISSING_CORE[@]}"; do
            case "$tool" in
                subfinder)   echo "  go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" ;;
                httpx)       echo "  go install github.com/projectdiscovery/httpx/cmd/httpx@latest" ;;
                nuclei)      echo "  go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" ;;
                ffuf)        echo "  go install github.com/ffuf/ffuf/v2@latest" ;;
                naabu)       echo "  go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest" ;;
                katana)      echo "  go install github.com/projectdiscovery/katana/cmd/katana@latest" ;;
                gau)         echo "  go install github.com/lc/gau/v2/cmd/gau@latest" ;;
                waybackurls) echo "  go install github.com/tomnomnom/waybackurls@latest" ;;
                assetfinder) echo "  go install github.com/tomnomnom/assetfinder@latest" ;;
            esac
        done
        echo ""
        warning "Continuing anyway — missing tools will be skipped per-phase"
    fi

    [ ${#MISSING_OPT[@]} -gt 0 ] && \
        info "Optional not installed (${#MISSING_OPT[@]}): ${MISSING_OPT[*]}"

    # Auto-update nuclei templates if nuclei is available
    if command -v nuclei &>/dev/null && [ ! -d "$NUCLEI_TEMPLATES" ]; then
        log "Downloading Nuclei templates..."
        nuclei -ut -silent 2>/dev/null || true
    fi

    local TOTAL_MISS=$(( ${#MISSING_CORE[@]} + ${#MISSING_IMP[@]} + ${#MISSING_OPT[@]} ))
    success "Dependency check complete — missing: $TOTAL_MISS (scan will proceed with available tools)"
    echo ""
}

#======================= ROOT CHECK =======================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        warning "Not root — masscan disabled. Run with sudo for full power."
        SKIP_MASSCAN=1
        IS_ROOT=0
    else
        IS_ROOT=1
        success "Running as root — full scan enabled"
    fi
}

#======================= SETUP =======================
setup_environment() {
    log "Setting up environment..."

    if [ -z "$OUTDIR" ]; then
        OUTDIR="$BASE_DIR/$DOMAIN-$(date +%Y%m%d-%H%M%S)"
    fi

    COMPLETED_PHASES_FILE="$OUTDIR/.completed_phases"

    mkdir -p "$OUTDIR"/{subdomains,alive,ports,screenshots,urls,dorking,analysis,vulns,reports,logs,wordlists,tmp,api,cloud,bypass,injections,takeover,backup,repos}
    # Advanced phase directories (phases 12-22)
    mkdir -p "$OUTDIR"/advanced/{injections,graphql,websocket,smuggling}
    mkdir -p "$OUTDIR"/{oob,network_recon,intelligence,infrastructure,cve_correlation,ai_analysis}
    touch "$OUTDIR/logs/master.log" "$OUTDIR/logs/errors.log" "$OUTDIR/logs/timing.log"

    # Setup resolvers
    if [ ! -f "$RESOLVERS" ]; then
        log "Downloading fast resolvers..."
        mkdir -p "$(dirname "$RESOLVERS")"
        wget -q "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -O "$RESOLVERS" 2>/dev/null || \
        echo -e "8.8.8.8\n8.8.4.4\n1.1.1.1\n1.0.0.1\n9.9.9.9\n208.67.222.222" > "$RESOLVERS"
    fi

    # DNS wordlist fallback
    if [ ! -f "$WORDLIST_DNS" ]; then
        if [ -f "$WORDLIST_DNS_FALLBACK" ]; then
            WORDLIST_DNS="$WORDLIST_DNS_FALLBACK"
        else
            warning "DNS wordlist not found, creating minimal one..."
            echo -e "www\nmail\nftp\napi\nadmin\ndev\nstaging\ntest\nbeta\napp\nmobile\ncdn\nblog\nshop\nportal\nauth\nlogin\ndashboard\nstatic\nassets" > "$OUTDIR/wordlists/mini_dns.txt"
            WORDLIST_DNS="$OUTDIR/wordlists/mini_dns.txt"
        fi
    fi

    # Save config
    cat > "$OUTDIR/scan_config.txt" << EOF
TARGET=$DOMAIN
DATE=$(date)
VERSION=$VERSION
CODENAME=$CODENAME
THREADS=$THREADS
STEALTH=$STEALTH_MODE
PARALLEL=$PARALLEL_MODE
RESPECTFUL_MODE=$RESPECTFUL_MODE
WAF_AWARE=$WAF_AWARE
STATIC_PROXY=$STATIC_PROXY
CONTACT_EMAIL=$CONTACT_EMAIL
CUSTOM_USER_AGENT=$CUSTOM_USER_AGENT
JITTER_MIN_MS=$JITTER_MIN_MS
JITTER_MAX_MS=$JITTER_MAX_MS
BLOCK_COOLDOWN=$BLOCK_COOLDOWN
BLOCK_SIGNAL_THRESHOLD=$BLOCK_SIGNAL_THRESHOLD
MONITOR_MODE=$MONITOR_MODE
MONITOR_STATE_DIR=$MONITOR_STATE_DIR
MONITOR_SCHEDULE=$MONITOR_SCHEDULE
MONITOR_WRITE_CRON=$MONITOR_WRITE_CRON
REPO_OSINT_MODE=$REPO_OSINT_MODE
GITHUB_API_URL=$GITHUB_API_URL
GITLAB_API_URL=$GITLAB_API_URL
REPO_SEARCH_PAGES=$REPO_SEARCH_PAGES
REPO_SEARCH_PER_PAGE=$REPO_SEARCH_PER_PAGE
REPO_MAX_CLONES=$REPO_MAX_CLONES
REPO_CLONE_DEPTH=$REPO_CLONE_DEPTH
REPO_INCLUDE_FORKS=$REPO_INCLUDE_FORKS
REPO_GITLEAKS_MODE=$REPO_GITLEAKS_MODE
REPO_TRUFFLEHOG_MODE=$REPO_TRUFFLEHOG_MODE
AXIOM_MODE=$AXIOM_MODE
AXIOM_FLEET=$AXIOM_FLEET
AXIOM_SPINUP=$AXIOM_SPINUP
AXIOM_RM_WHEN_DONE=$AXIOM_RM_WHEN_DONE
AXIOM_SHUTDOWN_WHEN_DONE=$AXIOM_SHUTDOWN_WHEN_DONE
AXIOM_NUCLEI_TEMPLATES=$AXIOM_NUCLEI_TEMPLATES
OUTDIR=$OUTDIR
EOF

    success "Environment ready: $OUTDIR"
    echo ""
}

#======================= PHASE RESUME CHECK =======================
phase_done() {
    local PHASE="$1"
    if [ "$RESUME_MODE" -eq 1 ] && grep -q "^$PHASE$" "$COMPLETED_PHASES_FILE" 2>/dev/null; then
        info "Skipping $PHASE (already completed — resume mode)"
        return 0
    fi
    return 1
}

mark_done() {
    echo "$1" >> "$COMPLETED_PHASES_FILE"
}

#======================= TIMING WRAPPER =======================
timed_phase() {
    local PHASE_NAME="$1"
    shift
    local START_T
    START_T=$(date +%s)
    # Run phase — catch non-zero exit so script continues regardless
    "$@" || {
        local _EC=$?
        warning "$PHASE_NAME exited with code $_EC — continuing"
    }
    local END_T
    END_T=$(date +%s)
    local DUR=$(( END_T - START_T ))
    # File-based logging works in both sequential and parallel (background) subshells
    echo "$PHASE_NAME: ${DUR}s" >> "$OUTDIR/logs/timing.log" 2>/dev/null || true
    # File-based IPC so parent can reload durations after parallel phases finish
    echo "${PHASE_NAME}=${DUR}" >> "$OUTDIR/logs/phase_durations.env" 2>/dev/null || true
    if ! grep -q "^$PHASE_NAME$" "$COMPLETED_PHASES_FILE" 2>/dev/null; then
        mark_done "$PHASE_NAME" 2>/dev/null || true
    fi
}

# Call after wait() in parallel blocks to populate PHASE_DURATION from file
load_phase_durations() {
    local DUR_FILE="$OUTDIR/logs/phase_durations.env"
    [ -f "$DUR_FILE" ] || return
    while IFS='=' read -r PNAME PDUR; do
        [[ "$PNAME" =~ ^[a-zA-Z0-9_]+$ ]] && PHASE_DURATION["$PNAME"]="$PDUR"
    done < "$DUR_FILE"
}

#======================= CONTROLLED JOB POOL =======================
# Limits concurrency to avoid overwhelming the target or local CPU.
# Usage:  job_pool_run <max_jobs> <cmd> [args...]
declare -ga JOB_POOL_PIDS=()

job_pool_run() {
    local MAX="$1"; shift
    # Reap finished jobs, block until capacity is available
    while true; do
        local LIVE=()
        for PID in "${JOB_POOL_PIDS[@]}"; do
            kill -0 "$PID" 2>/dev/null && LIVE+=("$PID")
        done
        JOB_POOL_PIDS=("${LIVE[@]}")
        [ "${#JOB_POOL_PIDS[@]}" -lt "$MAX" ] && break
        sleep 0.3
    done
    "$@" &
    JOB_POOL_PIDS+=($!)
}

job_pool_wait() {
    for PID in "${JOB_POOL_PIDS[@]}"; do
        wait "$PID" 2>/dev/null || true
    done
    JOB_POOL_PIDS=()
}

#======================= PROGRESS BAR =======================
progress_bar() {
    local LABEL="$1"
    local CURRENT="$2"
    local TOTAL="$3"
    local WIDTH=40
    local PCT=0
    [ "$TOTAL" -gt 0 ] && PCT=$(( CURRENT * 100 / TOTAL ))
    local FILLED=$(( WIDTH * PCT / 100 ))
    local EMPTY=$(( WIDTH - FILLED ))
    local BAR
    BAR=$(printf '%*s' "$FILLED" | tr ' ' '█')$(printf '%*s' "$EMPTY" | tr ' ' '░')
    printf "\r${CYAN}[${NC}%s${CYAN}]${NC} ${WHITE}%s${NC} %d/%d (%d%%)  " "$BAR" "$LABEL" "$CURRENT" "$TOTAL" "$PCT"
}

#======================= FILTER SCOPE =======================
filter_scope() {
    local INPUT_FILE="$1"
    local OUTPUT_FILE="$2"

    if [ -n "$SCOPE_FILE" ] && [ -f "$SCOPE_FILE" ]; then
        grep -Fif "$SCOPE_FILE" "$INPUT_FILE" > "$OUTPUT_FILE.scoped" 2>/dev/null
        mv "$OUTPUT_FILE.scoped" "$OUTPUT_FILE"
    fi

    if [ -n "$OUT_OF_SCOPE" ] && [ -f "$OUT_OF_SCOPE" ]; then
        grep -Fivf "$OUT_OF_SCOPE" "$OUTPUT_FILE" > "$OUTPUT_FILE.filtered" 2>/dev/null
        mv "$OUTPUT_FILE.filtered" "$OUTPUT_FILE"
    fi
}
