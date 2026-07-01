#======================= PHASE 22: CVE CORRELATION + SMART WORDLIST GENERATION =======================
# NVD API CVE lookup, version-based vuln matching, dynamic wordlist generation

_extract_software_versions() {
    local CVE_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[CVE] Extracting software versions from HTTP headers and bodies..."

    : > "$CVE_DIR/software_versions.txt"

    head -50 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        local HDRS
        HDRS=$(curl_safe -skI "$URL" --max-time 8 2>/dev/null)

        # Server header
        local SERVER
        SERVER=$(echo "$HDRS" | grep -i "^Server:" | head -1 | cut -d: -f2- | tr -d '\r ')
        [ -n "$SERVER" ] && echo "$URL | Server: $SERVER" >> "$CVE_DIR/software_versions.txt"

        # X-Powered-By
        local POWERED
        POWERED=$(echo "$HDRS" | grep -i "X-Powered-By:" | head -1 | cut -d: -f2- | tr -d '\r ')
        [ -n "$POWERED" ] && echo "$URL | X-Powered-By: $POWERED" >> "$CVE_DIR/software_versions.txt"

        # X-Generator (WordPress, Joomla)
        local GEN
        GEN=$(curl_safe -sk "$URL" --max-time 8 2>/dev/null \
            | grep -oiE '(WordPress|Joomla|Drupal|Magento)[^"'"'"'>< ]*' | head -3 | tr '\n' '|')
        [ -n "$GEN" ] && echo "$URL | CMS: $GEN" >> "$CVE_DIR/software_versions.txt"

        # PHP version from headers
        local PHP_VER
        PHP_VER=$(echo "$HDRS" | grep -oiE 'PHP/[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [ -n "$PHP_VER" ] && echo "$URL | $PHP_VER" >> "$CVE_DIR/software_versions.txt"

        # Apache / nginx version
        local _sw_match
        _sw_match=$(echo "$SERVER" | grep -oiE '(Apache|nginx|IIS|Tomcat|Jetty)/[0-9]+\.[0-9.]+' | head -1)
        [ -n "$_sw_match" ] && echo "$URL | $_sw_match" >> "$CVE_DIR/software_versions.txt" || true

    done

    # From nuclei/nmap results
    if [ -s "$OUTDIR/ports/nmap_services.txt" ]; then
        grep -oiE '(Apache|nginx|OpenSSH|Tomcat|IIS|PHP|WordPress|Drupal)[/ ][0-9]+\.[0-9.]+' \
            "$OUTDIR/ports/nmap_services.txt" 2>/dev/null \
            >> "$CVE_DIR/software_versions.txt" || true
    fi

    sort -u "$CVE_DIR/software_versions.txt" -o "$CVE_DIR/software_versions.txt" 2>/dev/null || true
    local VER_CNT
    VER_CNT=$(wc -l < "$CVE_DIR/software_versions.txt" 2>/dev/null || echo 0)
    info "[CVE] Extracted $VER_CNT software/version entries"
}

_nvd_lookup() {
    local KEYWORD="$1"
    local CVE_DIR="$2"
    local MAX_RESULTS=5

    [ -z "$KEYWORD" ] && return

    local ENCODED_KW
    # Try jq @uri first (already a dependency), fall back to python3, then raw
    ENCODED_KW=$(printf '%s' "$KEYWORD" | jq -Rr @uri 2>/dev/null) \
        || ENCODED_KW=$(printf '%s' "$KEYWORD" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))" 2>/dev/null) \
        || ENCODED_KW=$(printf '%s' "$KEYWORD" | sed 's/ /%20/g;s/\//%2F/g;s/+/%2B/g')
    local NVD_URL="https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=${ENCODED_KW}&resultsPerPage=${MAX_RESULTS}"

    # Add API key header if available
    local NVD_HEADERS=()
    [ -n "$NVD_API_KEY" ] && NVD_HEADERS=(-H "apiKey: $NVD_API_KEY")

    local NVD_RESP
    NVD_RESP=$(curl_safe -s "${NVD_HEADERS[@]}" "$NVD_URL" --max-time 15 2>/dev/null)

    if echo "$NVD_RESP" | jq -e '.vulnerabilities' &>/dev/null 2>/dev/null; then
        echo "$NVD_RESP" | jq -r '
            .vulnerabilities[]? |
            "\(.cve.id) | CVSS: \(.cve.metrics.cvssMetricV31[0].cvssData.baseScore // .cve.metrics.cvssMetricV2[0].cvssData.baseScore // "N/A") | \(.cve.descriptions[0].value[:120])"
        ' 2>/dev/null >> "$CVE_DIR/nvd_matches.txt" || true
    fi
}

_correlate_cves() {
    local CVE_DIR="$1"

    [ -s "$CVE_DIR/software_versions.txt" ] || return

    log "[CVE] Correlating software versions with NVD CVE database..."
    local DONE=()
    local IDX=0

    while IFS= read -r LINE; do
        # Extract product+version e.g. "Apache/2.4.41" → "Apache 2.4.41"
        local PRODUCT
        PRODUCT=$(echo "$LINE" | grep -oiE '(Apache|nginx|OpenSSH|PHP|WordPress|Drupal|Joomla|Tomcat|IIS|Magento)[/: ][0-9]+\.[0-9.]+' \
            | head -1 | sed 's|/| |;s|: | |')
        [ -z "$PRODUCT" ] && continue

        # Deduplicate
        [[ " ${DONE[*]} " == *" $PRODUCT "* ]] && continue
        DONE+=("$PRODUCT")

        IDX=$(( IDX + 1 ))
        [ $IDX -gt 20 ] && break

        progress_bar "CVELookup" "$IDX" "20"
        _nvd_lookup "$PRODUCT" "$CVE_DIR"

        # Rate limit: NVD allows ~50 req/30s with key, 5/30s without (use 8s for safety buffer)
        if [ -n "$NVD_API_KEY" ]; then sleep 0.6; else sleep 8; fi

    done < "$CVE_DIR/software_versions.txt"
    echo ""

    if [ -s "$CVE_DIR/nvd_matches.txt" ]; then
        sort -u "$CVE_DIR/nvd_matches.txt" -o "$CVE_DIR/nvd_matches.txt"
        local CVE_CNT
        CVE_CNT=$(wc -l < "$CVE_DIR/nvd_matches.txt")
        success "[CVE] $CVE_CNT CVE matches found"

        # Highlight critical (CVSS >= 9.0)
        local CRITICAL_CVE
        CRITICAL_CVE=$(grep -E '\| (9\.[0-9]|10\.0) \|' "$CVE_DIR/nvd_matches.txt" 2>/dev/null)
        if [ -n "$CRITICAL_CVE" ]; then
            echo "$CRITICAL_CVE" > "$CVE_DIR/critical_cves.txt"
            vuln "CRITICAL CVEs FOUND ON $DOMAIN:"
            echo "$CRITICAL_CVE" | while IFS= read -r CVE_LINE; do
                vuln "  $CVE_LINE"
            done
            notify_vuln "critical" "Critical CVEs on $DOMAIN: $(echo "$CRITICAL_CVE" | head -3 | cut -d'|' -f1 | tr '\n' ',')"
        fi
    else
        info "[CVE] No CVE matches found (versions may not be detectable)"
    fi
}

_generate_smart_wordlists() {
    local CVE_DIR="$1"

    log "[CVE] Generating smart wordlists from target context..."

    local WL_DIR="$CVE_DIR/wordlists"
    mkdir -p "$WL_DIR"

    # ── Domain-based wordlist ─────────────────────────────────
    # Extract words from domain name and subdomains
    {
        echo "$DOMAIN" | tr '.' '\n'
        # Words from subdomain names
        cat "$OUTDIR/subdomains/final_subs.txt" 2>/dev/null \
            | sed 's/\..*//' \
            | tr '-_' '\n'
    } | sort -u > "$WL_DIR/domain_words.txt"

    # ── API endpoint wordlist from discovered endpoints ───────
    if [ -s "$OUTDIR/urls/all_urls.txt" ]; then
        grep -oE '/[a-zA-Z0-9_-]{3,}' "$OUTDIR/urls/all_urls.txt" 2>/dev/null \
            | sort -u | head -500 > "$WL_DIR/api_endpoints.txt"
    fi

    # ── Parameter wordlist from discovered params ─────────────
    if [ -s "$OUTDIR/urls/parameters.txt" ]; then
        grep -oE '[?&][a-zA-Z0-9_-]+=' "$OUTDIR/urls/parameters.txt" 2>/dev/null \
            | tr -d '?&=' | sort -u > "$WL_DIR/parameter_names.txt"
        local PARAM_CNT
        PARAM_CNT=$(wc -l < "$WL_DIR/parameter_names.txt" 2>/dev/null || echo 0)
        success "[WordList] Custom param wordlist: $PARAM_CNT entries"
    fi

    # ── Tech-specific paths based on detected technology ──────
    local TECH_WORDLIST="$WL_DIR/tech_specific.txt"
    : > "$TECH_WORDLIST"

    if grep -qi "wordpress\|wp-content" "$CVE_DIR/software_versions.txt" 2>/dev/null; then
        cat >> "$TECH_WORDLIST" <<'EOF'
/wp-admin/
/wp-login.php
/wp-config.php
/wp-json/wp/v2/users
/wp-json/wp/v2/posts
/wp-content/uploads/
/xmlrpc.php
/wp-cron.php
EOF
    fi

    if grep -qi "joomla" "$CVE_DIR/software_versions.txt" 2>/dev/null; then
        cat >> "$TECH_WORDLIST" <<'EOF'
/administrator/
/administrator/index.php
/configuration.php
/api/index.php
EOF
    fi

    if grep -qi "drupal" "$CVE_DIR/software_versions.txt" 2>/dev/null; then
        cat >> "$TECH_WORDLIST" <<'EOF'
/admin/
/node/add
/user/register
/update.php
/install.php
/sites/default/settings.php
EOF
    fi

    if grep -qi "laravel\|php" "$CVE_DIR/software_versions.txt" 2>/dev/null; then
        cat >> "$TECH_WORDLIST" <<'EOF'
/.env
/storage/logs/laravel.log
/public/.htaccess
/artisan
/phpinfo.php
EOF
    fi

    if grep -qi "spring\|java\|tomcat" "$CVE_DIR/software_versions.txt" 2>/dev/null; then
        cat >> "$TECH_WORDLIST" <<'EOF'
/actuator
/actuator/env
/actuator/heapdump
/actuator/mappings
/manager/html
/host-manager/html
/console
EOF
    fi

    # ── Merge with existing wordlists ─────────────────────────
    local FINAL_DIR="$WL_DIR/final_dir.txt"
    {
        cat "$WL_DIR/domain_words.txt" 2>/dev/null
        cat "$WL_DIR/api_endpoints.txt" 2>/dev/null
        cat "$WL_DIR/tech_specific.txt" 2>/dev/null
        head -200 "$WORDLIST_DIR" 2>/dev/null
    } | sort -u > "$FINAL_DIR"

    local WL_CNT
    WL_CNT=$(wc -l < "$FINAL_DIR" 2>/dev/null || echo 0)
    success "[WordList] Smart directory wordlist: $WL_CNT entries → $FINAL_DIR"

    # ── Re-run ffuf with smart wordlist on alive hosts ────────
    if command -v ffuf &>/dev/null && [ "$WL_CNT" -gt 0 ]; then
        log "[CVE] Re-running directory bruteforce with smart wordlist..."
        head -10 "$OUTDIR/alive/final_alive.txt" 2>/dev/null | while IFS= read -r URL; do
            local SAFE_NAME
            SAFE_NAME=$(echo "$URL" | md5sum | cut -d' ' -f1)
            ffuf -u "${URL}/FUZZ" \
                -w "$FINAL_DIR" \
                -mc 200,201,204,301,302,401,403 \
                -t 50 \
                -rate "$FFUF_RATE" \
                -o "$CVE_DIR/smart_ffuf_${SAFE_NAME}.json" \
                -of json \
                -s 2>/dev/null || true
        done
    fi
}

_version_specific_exploits() {
    local CVE_DIR="$1"

    [ -s "$CVE_DIR/software_versions.txt" ] || return
    log "[CVE] Checking known exploitable version patterns..."

    # Patterns with known critical exploits worth flagging
    local -a CRITICAL_PATTERNS=(
        "Apache/2.4.49:CVE-2021-41773 (Path Traversal + RCE)"
        "Apache/2.4.50:CVE-2021-42013 (Path Traversal)"
        "Log4j:CVE-2021-44228 (Log4Shell RCE)"
        "Spring/5.:CVE-2022-22963 (Spring4Shell RCE)"
        "OpenSSH/7.:CVE-2016-6210 (User Enumeration)"
        "OpenSSH/8.:CVE-2023-38408 (RCE via ssh-agent)"
        "PHP/7.4:CVE-2019-11043 (FPM RCE)"
        "PHP/8.0:CVE-2022-31625 (Use after free)"
        "WordPress/4.:CVE-2019-8943 (File overwrite)"
        "WordPress/5.6:CVE-2021-29447 (XXE)"
        "Drupal/7.:CVE-2018-7600 (Drupalgeddon2 RCE)"
        "nginx/1.16:CVE-2019-20372 (HTTP Request Smuggling)"
        "Tomcat/9.:CVE-2020-1938 (Ghostcat AJP RCE)"
        "Tomcat/10.:CVE-2021-33037 (HTTP Request Smuggling)"
    )

    local FOUND_EXPLOITS=()
    while IFS= read -r SW_LINE; do
        for PATTERN_STR in "${CRITICAL_PATTERNS[@]}"; do
            local MATCH="${PATTERN_STR%%:*}"
            local DESC="${PATTERN_STR##*:}"
            if echo "$SW_LINE" | grep -qi "$MATCH"; then
                FOUND_EXPLOITS+=("$SW_LINE → $DESC")
                echo "$SW_LINE → $DESC" >> "$CVE_DIR/version_exploits.txt"
                vuln "VERSION EXPLOIT: $SW_LINE → $DESC"
                notify_vuln "critical" "Known Exploit: $MATCH on $DOMAIN — $DESC"
            fi
        done
    done < "$CVE_DIR/software_versions.txt"

    [ "${#FOUND_EXPLOITS[@]}" -gt 0 ] && \
        success "[CVE] ${#FOUND_EXPLOITS[@]} version-specific exploits identified"
}

phase_22_cve_correlation() {
    if phase_done "phase_22"; then return 0; fi
    [ "$CVE_CORRELATION_MODE" -ne 1 ] && { info "CVE correlation mode disabled — skipping phase 22"; return; }
    phase_banner "PHASE 22: CVE CORRELATION + SMART WORDLIST GENERATION"

    local START_TIME
    START_TIME=$(date +%s)
    local CVE_DIR="$OUTDIR/cve_correlation"
    mkdir -p "$CVE_DIR"

    : > "$CVE_DIR/software_versions.txt"
    : > "$CVE_DIR/nvd_matches.txt"

    # ── [22.1] Extract versions from scan data ────────────────
    log "[22.1] Extracting software versions..."
    _extract_software_versions "$CVE_DIR"

    # ── [22.2] Version-specific known exploits ────────────────
    log "[22.2] Checking known exploit signatures..."
    _version_specific_exploits "$CVE_DIR"

    # ── [22.3] NVD API correlation ───────────────────────────
    log "[22.3] NVD API CVE correlation..."
    _correlate_cves "$CVE_DIR"

    # ── [22.4] Smart wordlist generation ─────────────────────
    log "[22.4] Generating smart context-aware wordlists..."
    _generate_smart_wordlists "$CVE_DIR"

    local CVE_CNT EXPLOIT_CNT WL_CNT
    CVE_CNT=$(wc -l < "$CVE_DIR/nvd_matches.txt" 2>/dev/null || echo 0)
    EXPLOIT_CNT=$(wc -l < "$CVE_DIR/version_exploits.txt" 2>/dev/null || echo 0)
    WL_CNT=$(wc -l < "$CVE_DIR/wordlists/final_dir.txt" 2>/dev/null || echo 0)

    success "PHASE 22 DONE — CVEs: $CVE_CNT | Direct exploits: $EXPLOIT_CNT | Wordlist: $WL_CNT entries | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 22: CVE Correlation done — $CVE_CNT CVEs, $EXPLOIT_CNT known exploits, $WL_CNT-entry smart wordlist" "🔍"
    mark_done "phase_22"
    echo ""
}
