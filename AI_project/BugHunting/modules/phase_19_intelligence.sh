#======================= PHASE 19: THREAT INTELLIGENCE APIS =======================
# Shodan, Censys, FOFA, Hunter.io email OSINT, VirusTotal, SecurityTrails

_shodan_lookup() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$SHODAN_API_KEY" ] && { info "[Shodan] No API key — skipping"; return; }

    log "[Shodan] Querying $HOST..."

    # Resolve IP first
    local IP
    IP=$(dig +short "$HOST" A 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -z "$IP" ] && return

    local SHODAN_RESP
    SHODAN_RESP=$(curl_safe -s \
        "https://api.shodan.io/shodan/host/${IP}?key=${SHODAN_API_KEY}" 2>/dev/null)

    if echo "$SHODAN_RESP" | jq -e '.ip_str' &>/dev/null 2>/dev/null; then
        echo "$SHODAN_RESP" > "$INTEL_DIR/shodan_${IP}.json"

        # Extract useful info
        local OPEN_PORTS VULNS ORG
        OPEN_PORTS=$(echo "$SHODAN_RESP" | jq -r '[.ports[]?] | join(", ")' 2>/dev/null || echo "?")
        VULNS=$(echo "$SHODAN_RESP" | jq -r '[.vulns? | keys[]?] | join(", ")' 2>/dev/null || echo "none")
        ORG=$(echo "$SHODAN_RESP" | jq -r '.org // "?"' 2>/dev/null)

        {
            echo "=== Shodan: $IP ($HOST) ==="
            echo "Org: $ORG"
            echo "Open Ports: $OPEN_PORTS"
            echo "Vulns: $VULNS"
            echo ""
        } >> "$INTEL_DIR/shodan_summary.txt"

        # Alert on CVEs
        if echo "$SHODAN_RESP" | jq -e '.vulns | length > 0' &>/dev/null 2>/dev/null; then
            local CVE_LIST
            CVE_LIST=$(echo "$SHODAN_RESP" | jq -r '.vulns | keys[]' 2>/dev/null | head -10 | tr '\n' ', ')
            vuln "SHODAN CVEs on $IP: $CVE_LIST"
            notify_vuln "critical" "Shodan: $IP ($HOST) has known CVEs: $CVE_LIST"
        fi

        # Shodan domain search
        curl_safe -s \
            "https://api.shodan.io/shodan/host/search?key=${SHODAN_API_KEY}&query=hostname:${HOST}&facets=port" 2>/dev/null \
            | jq -r '.matches[]? | "\(.ip_str):\(.port) [\(.product // "?")]"' 2>/dev/null \
            >> "$INTEL_DIR/shodan_hosts.txt" || true

        success "[Shodan] Data collected for $IP — Ports: $OPEN_PORTS | CVEs: $VULNS"
    else
        info "[Shodan] No data for $IP (may not be indexed)"
    fi
}

_censys_lookup() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$CENSYS_API_ID" ] || [ -z "$CENSYS_API_SECRET" ] && { info "[Censys] No credentials — skipping"; return; }

    log "[Censys] Querying $HOST..."

    local CENSYS_RESP
    CENSYS_RESP=$(curl_safe -s \
        -u "${CENSYS_API_ID}:${CENSYS_API_SECRET}" \
        "https://search.censys.io/api/v2/hosts/search?q=${HOST}&per_page=20" 2>/dev/null)

    if echo "$CENSYS_RESP" | jq -e '.result.hits' &>/dev/null 2>/dev/null; then
        echo "$CENSYS_RESP" | jq -r '
            .result.hits[]? |
            "\(.ip) | Ports: \([.services[]?.port] | join(",")) | Name: \(.name // "?")"
        ' 2>/dev/null >> "$INTEL_DIR/censys_hosts.txt" || true

        local HIT_CNT
        HIT_CNT=$(echo "$CENSYS_RESP" | jq '.result.total // 0' 2>/dev/null || echo 0)
        success "[Censys] $HIT_CNT hosts found for $HOST"
    fi
}

_fofa_lookup() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$FOFA_EMAIL" ] || [ -z "$FOFA_KEY" ] && { info "[FOFA] No credentials — skipping"; return; }

    log "[FOFA] Querying $HOST..."

    # FOFA uses base64-encoded query
    local QUERY
    QUERY=$(printf 'domain="%s"' "$HOST" | base64 -w 0 2>/dev/null)

    curl_safe -s \
        "https://fofa.info/api/v1/search/all?email=${FOFA_EMAIL}&key=${FOFA_KEY}&qbase64=${QUERY}&size=100&fields=ip,port,host,title,country,server" 2>/dev/null \
        | jq -r '.results[]? | "\(.[0]):\(.[1]) | Host: \(.[2]) | Title: \(.[3]) | Server: \(.[5])"' 2>/dev/null \
        >> "$INTEL_DIR/fofa_results.txt" || true

    local FOFA_CNT
    FOFA_CNT=$(wc -l < "$INTEL_DIR/fofa_results.txt" 2>/dev/null || echo 0)
    success "[FOFA] $FOFA_CNT results"
}

_hunter_email_osint() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$HUNTER_API_KEY" ] && { info "[Hunter.io] No API key — skipping"; return; }

    log "[Hunter.io] Email OSINT for $HOST..."

    local HUNTER_RESP
    HUNTER_RESP=$(curl_safe -s \
        "https://api.hunter.io/v2/domain-search?domain=${HOST}&api_key=${HUNTER_API_KEY}&limit=50" 2>/dev/null)

    if echo "$HUNTER_RESP" | jq -e '.data.emails' &>/dev/null 2>/dev/null; then
        echo "$HUNTER_RESP" | jq -r '
            .data.emails[]? |
            "\(.value) | \(.type // "?") | \(.first_name // "") \(.last_name // "") | Confidence: \(.confidence)%"
        ' 2>/dev/null >> "$INTEL_DIR/hunter_emails.txt" || true

        local TOTAL
        TOTAL=$(echo "$HUNTER_RESP" | jq '.data.meta.total // 0' 2>/dev/null || echo 0)
        local ORG
        ORG=$(echo "$HUNTER_RESP" | jq -r '.data.organization // "?"' 2>/dev/null)
        local PATTERN
        PATTERN=$(echo "$HUNTER_RESP" | jq -r '.data.pattern // "?"' 2>/dev/null)

        {
            echo "=== Hunter.io: $HOST ==="
            echo "Organization: $ORG"
            echo "Email pattern: $PATTERN"
            echo "Total emails: $TOTAL"
        } >> "$INTEL_DIR/hunter_summary.txt"

        success "[Hunter.io] $TOTAL emails found for $HOST (pattern: $PATTERN)"
    fi
}

_virustotal_lookup() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$VIRUSTOTAL_API_KEY" ] && { info "[VT] No API key — skipping"; return; }

    log "[VirusTotal] Querying $HOST..."

    # Domain report
    local VT_RESP
    VT_RESP=$(curl_safe -s \
        -H "x-apikey: $VIRUSTOTAL_API_KEY" \
        "https://www.virustotal.com/api/v3/domains/${HOST}" 2>/dev/null)

    if echo "$VT_RESP" | jq -e '.data.attributes' &>/dev/null 2>/dev/null; then
        local MALICIOUS SUSPICIOUS LAST_ANALYSIS
        MALICIOUS=$(echo "$VT_RESP" | jq '.data.attributes.last_analysis_stats.malicious // 0' 2>/dev/null || echo 0)
        SUSPICIOUS=$(echo "$VT_RESP" | jq '.data.attributes.last_analysis_stats.suspicious // 0' 2>/dev/null || echo 0)
        LAST_ANALYSIS=$(echo "$VT_RESP" | jq -r '.data.attributes.last_analysis_date // "?"' 2>/dev/null)

        {
            echo "VirusTotal: $HOST"
            echo "  Malicious: $MALICIOUS | Suspicious: $SUSPICIOUS"
            echo "  Last analysis: $LAST_ANALYSIS"
        } >> "$INTEL_DIR/virustotal_summary.txt"

        [ "$MALICIOUS" -gt 0 ] && {
            vuln "VIRUSTOTAL: $HOST flagged by $MALICIOUS engines as malicious"
            notify_vuln "high" "VirusTotal: $HOST — $MALICIOUS antivirus engines flag as malicious"
        }

        # Subdomains from VT
        curl_safe -s \
            -H "x-apikey: $VIRUSTOTAL_API_KEY" \
            "https://www.virustotal.com/api/v3/domains/${HOST}/subdomains?limit=40" 2>/dev/null \
            | jq -r '.data[]?.id // empty' 2>/dev/null \
            >> "$INTEL_DIR/vt_subdomains.txt" || true

        success "[VT] Malicious: $MALICIOUS | Suspicious: $SUSPICIOUS for $HOST"
    fi
}

_securitytrails_lookup() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$SECURITYTRAILS_API_KEY" ] && { info "[ST] No API key — skipping"; return; }

    log "[SecurityTrails] Querying $HOST..."

    # General info
    local ST_RESP
    ST_RESP=$(curl_safe -s \
        -H "apikey: $SECURITYTRAILS_API_KEY" \
        "https://api.securitytrails.com/v1/domain/${HOST}" 2>/dev/null)

    if echo "$ST_RESP" | jq -e '.current_dns' &>/dev/null 2>/dev/null; then
        echo "$ST_RESP" | jq -r '
            "MX: \([.current_dns.mx.values[]?.hostname?] | join(", "))\n" +
            "NS: \([.current_dns.ns.values[]?.nameserver?] | join(", "))\n" +
            "A: \([.current_dns.a.values[]?.ip?] | join(", "))"
        ' 2>/dev/null >> "$INTEL_DIR/securitytrails_dns.txt" || true
        success "[SecurityTrails] DNS records collected"
    fi

    # Associated IPs (known infrastructure)
    curl_safe -s \
        -H "apikey: $SECURITYTRAILS_API_KEY" \
        "https://api.securitytrails.com/v1/domain/${HOST}/associated" 2>/dev/null \
        | jq -r '.records[]?.hostname? // empty' 2>/dev/null \
        >> "$INTEL_DIR/st_associated.txt" || true
}

_fullhunt_lookup() {
    local HOST="$1"
    local INTEL_DIR="$2"

    [ -z "$FULLHUNT_API_KEY" ] && { info "[FullHunt] No API key — skipping"; return; }

    log "[FullHunt] Querying $HOST..."

    curl_safe -s \
        -H "X-API-KEY: $FULLHUNT_API_KEY" \
        "https://fullhunt.io/api/v1/domain/${HOST}/subdomains" 2>/dev/null \
        | jq -r '.hosts[]? // empty' 2>/dev/null \
        >> "$INTEL_DIR/fullhunt_subdomains.txt" || true

    local FH_CNT
    FH_CNT=$(wc -l < "$INTEL_DIR/fullhunt_subdomains.txt" 2>/dev/null || echo 0)
    [ "$FH_CNT" -gt 0 ] && success "[FullHunt] $FH_CNT subdomains found"
}

_employee_enum() {
    local HOST="$1"
    local INTEL_DIR="$2"

    log "[OSINT] Employee enumeration for $HOST..."

    # LinkedIn via Google dork (passive)
    local LINKEDIN_DORK="site:linkedin.com/in \"$HOST\" OR \"$(echo "$HOST" | cut -d. -f1)\""
    echo "LinkedIn dork: $LINKEDIN_DORK" >> "$INTEL_DIR/employee_osint.txt"

    # GitHub user search
    if [ -n "$GITHUB_TOKEN" ]; then
        curl_safe -s \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/search/users?q=${HOST}+in:email&per_page=10" 2>/dev/null \
            | jq -r '.items[]? | "\(.login) | \(.html_url)"' 2>/dev/null \
            >> "$INTEL_DIR/github_employees.txt" || true
    fi

    # Email pattern bruteforce (common formats) using Hunter pattern
    if [ -s "$INTEL_DIR/hunter_summary.txt" ]; then
        local PATTERN
        PATTERN=$(grep "Email pattern" "$INTEL_DIR/hunter_summary.txt" | awk -F': ' '{print $2}')
        [ -n "$PATTERN" ] && echo "Email pattern: $PATTERN" >> "$INTEL_DIR/employee_osint.txt"
    fi
}

phase_19_intelligence() {
    if phase_done "phase_19"; then return 0; fi
    [ "$INTEL_API_MODE" -ne 1 ] && { info "Intelligence API mode disabled — skipping phase 19"; return; }
    phase_banner "PHASE 19: THREAT INTELLIGENCE APIS"

    local START_TIME
    START_TIME=$(date +%s)
    local INTEL_DIR="$OUTDIR/intelligence"
    mkdir -p "$INTEL_DIR"

    : > "$INTEL_DIR/shodan_summary.txt"
    : > "$INTEL_DIR/hunter_emails.txt"
    : > "$INTEL_DIR/virustotal_summary.txt"
    : > "$INTEL_DIR/fofa_results.txt"
    : > "$INTEL_DIR/fullhunt_subdomains.txt"

    # ── [19.1] Shodan ─────────────────────────────────────────
    log "[19.1] Shodan intelligence..."
    _shodan_lookup "$DOMAIN" "$INTEL_DIR"

    # ── [19.2] Censys ─────────────────────────────────────────
    log "[19.2] Censys intelligence..."
    _censys_lookup "$DOMAIN" "$INTEL_DIR"

    # ── [19.3] FOFA ───────────────────────────────────────────
    log "[19.3] FOFA intelligence..."
    _fofa_lookup "$DOMAIN" "$INTEL_DIR"

    # ── [19.4] Hunter.io ─────────────────────────────────────
    log "[19.4] Hunter.io email OSINT..."
    _hunter_email_osint "$DOMAIN" "$INTEL_DIR"

    # ── [19.5] VirusTotal ────────────────────────────────────
    log "[19.5] VirusTotal reputation..."
    _virustotal_lookup "$DOMAIN" "$INTEL_DIR"

    # ── [19.6] SecurityTrails ────────────────────────────────
    log "[19.6] SecurityTrails historical DNS..."
    _securitytrails_lookup "$DOMAIN" "$INTEL_DIR"

    # ── [19.7] FullHunt ──────────────────────────────────────
    log "[19.7] FullHunt attack surface..."
    _fullhunt_lookup "$DOMAIN" "$INTEL_DIR"

    # ── [19.8] Employee OSINT ────────────────────────────────
    log "[19.8] Employee enumeration..."
    _employee_enum "$DOMAIN" "$INTEL_DIR"

    # Merge any new subdomains found into main subdomain list
    local NEW_SUBS=0
    for F in "$INTEL_DIR/vt_subdomains.txt" "$INTEL_DIR/fullhunt_subdomains.txt" "$INTEL_DIR/st_associated.txt"; do
        if [ -s "$F" ]; then
            cat "$F" >> "$OUTDIR/subdomains/all_subdomains.txt" 2>/dev/null || true
            NEW_SUBS=$(( NEW_SUBS + $(wc -l < "$F" 2>/dev/null || echo 0) ))
        fi
    done
    sort -u "$OUTDIR/subdomains/all_subdomains.txt" -o "$OUTDIR/subdomains/all_subdomains.txt" 2>/dev/null || true

    local EMAIL_CNT FOFA_CNT
    EMAIL_CNT=$(wc -l < "$INTEL_DIR/hunter_emails.txt" 2>/dev/null || echo 0)
    FOFA_CNT=$(wc -l < "$INTEL_DIR/fofa_results.txt" 2>/dev/null || echo 0)

    success "PHASE 19 DONE — Emails: $EMAIL_CNT | FOFA results: $FOFA_CNT | New subs: $NEW_SUBS | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 19: Intelligence done — $EMAIL_CNT emails, $FOFA_CNT FOFA results, $NEW_SUBS new subdomains" "🕵️"
    mark_done "phase_19"
    echo ""
}
