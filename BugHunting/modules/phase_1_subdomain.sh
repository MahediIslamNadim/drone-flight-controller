#======================= PHASE 1: SUBDOMAIN ENUMERATION =======================
phase_1_subdomain_enum() {
    if phase_done "phase_1"; then return 0; fi
    phase_banner "PHASE 1: SUBDOMAIN ENUMERATION (PASSIVE + ACTIVE)"

    local START_TIME
    START_TIME=$(date +%s)
    local SUB_DIR="$OUTDIR/subdomains"
    local PIDS=()

    # ── Passive sources (run in parallel) ──
    log "[1.1] Subfinder (all sources, recursive)..."
    subfinder -d "$DOMAIN" -all -recursive -silent \
        -o "$SUB_DIR/subfinder.txt" -t "$THREADS" 2>>"$OUTDIR/logs/errors.log" &
    PIDS+=($!)

    log "[1.2] Assetfinder..."
    assetfinder --subs-only "$DOMAIN" > "$SUB_DIR/assetfinder.txt" 2>>"$OUTDIR/logs/errors.log" &
    PIDS+=($!)

    log "[1.3] crt.sh Certificate Transparency..."
    (curl_safe "https://crt.sh/?q=%.$DOMAIN&output=json" 2>/dev/null | \
        jq -r '.[].name_value' 2>/dev/null | \
        sed 's/\*\.//g;s/\\n/\n/g' | sort -u > "$SUB_DIR/crtsh.txt") &
    PIDS+=($!)

    log "[1.4] Archive.org CDX..."
    (curl_safe "http://web.archive.org/cdx/search/cdx?url=*.${DOMAIN}/*&output=json&collapse=urlkey&limit=50000" 2>/dev/null | \
        jq -r '.[1:][][2]' 2>/dev/null | \
        sed -e 's_https*://__' -e 's/[:/].*$//' | \
        grep -i "$DOMAIN" | sort -u > "$SUB_DIR/archiveorg.txt") &
    PIDS+=($!)

    log "[1.5] SecurityTrails via curl..."
    (curl_safe "https://securitytrails.com/list/apex_domain/$DOMAIN" 2>/dev/null | \
        grep -oE "[a-zA-Z0-9._-]+\.$DOMAIN" | sort -u > "$SUB_DIR/securitytrails.txt") &
    PIDS+=($!)

    log "[1.6] RapidDNS..."
    (curl_safe "https://rapiddns.io/subdomain/$DOMAIN?full=1" 2>/dev/null | \
        grep -oE "[a-zA-Z0-9._-]+\.$DOMAIN" | sort -u > "$SUB_DIR/rapiddns.txt") &
    PIDS+=($!)

    log "[1.7] Findomain..."
    if command -v findomain &>/dev/null; then
        findomain -t "$DOMAIN" -u "$SUB_DIR/findomain.txt" -q 2>>"$OUTDIR/logs/errors.log" &
        PIDS+=($!)
    fi

    # ── Amass v4 (passive, with config if available) ──
    log "[1.8] Amass v4 (passive, 20min timeout)..."
    if command -v amass &>/dev/null; then
        local AMASS_ARGS=(-passive -d "$DOMAIN" -o "$SUB_DIR/amass.txt" -silent)
        # v4 auto-detects ~/.config/amass/config.yaml — pass -config if it exists
        local AMASS_CFG="$HOME/.config/amass/config.yaml"
        [ -f "$AMASS_CFG" ] && AMASS_ARGS+=(-config "$AMASS_CFG")
        (timeout 1200 amass enum "${AMASS_ARGS[@]}" 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    fi

    log "[1.9] HackerTarget API..."
    (curl_safe "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" 2>/dev/null | \
        cut -d',' -f1 | sort -u > "$SUB_DIR/hackertarget.txt") &
    PIDS+=($!)

    log "[1.10] AlienVault OTX..."
    (curl_safe "https://otx.alienvault.com/api/v1/indicators/domain/$DOMAIN/passive_dns" 2>/dev/null | \
        jq -r '.passive_dns[]?.hostname // empty' 2>/dev/null | \
        grep -iE "\.$DOMAIN$" | sort -u > "$SUB_DIR/otx.txt" \
        || : > "$SUB_DIR/otx.txt") &
    PIDS+=($!)

    # ── Chaos (ProjectDiscovery public dataset) ──
    log "[1.11] Chaos (ProjectDiscovery dataset)..."
    if command -v chaos &>/dev/null; then
        (chaos -d "$DOMAIN" -silent -o "$SUB_DIR/chaos.txt" \
            2>>"$OUTDIR/logs/errors.log" || : > "$SUB_DIR/chaos.txt") &
        PIDS+=($!)
    else
        : > "$SUB_DIR/chaos.txt"
    fi

    # ── urlscan.io (free, no key required) ──
    log "[1.12] urlscan.io subdomain lookup..."
    (curl_safe "https://urlscan.io/api/v1/search/?q=domain:${DOMAIN}&size=10000" 2>/dev/null \
        | jq -r '.results[]?.page.domain // empty' 2>/dev/null \
        | grep -iE "\.${DOMAIN}$" \
        | sort -u > "$SUB_DIR/urlscan.txt" \
        || : > "$SUB_DIR/urlscan.txt") &
    PIDS+=($!)

    # Wait for all passive sources
    log "Waiting for passive sources..."
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    success "All passive sources complete"

    # ── Merge passive ──
    {
        cat "$SUB_DIR/subfinder.txt"      2>/dev/null
        cat "$SUB_DIR/assetfinder.txt"    2>/dev/null
        cat "$SUB_DIR/crtsh.txt"          2>/dev/null
        cat "$SUB_DIR/archiveorg.txt"     2>/dev/null
        cat "$SUB_DIR/securitytrails.txt" 2>/dev/null
        cat "$SUB_DIR/rapiddns.txt"       2>/dev/null
        cat "$SUB_DIR/findomain.txt"      2>/dev/null
        cat "$SUB_DIR/amass.txt"          2>/dev/null
        cat "$SUB_DIR/hackertarget.txt"   2>/dev/null
        cat "$SUB_DIR/otx.txt"            2>/dev/null
        cat "$SUB_DIR/chaos.txt"          2>/dev/null
        cat "$SUB_DIR/urlscan.txt"        2>/dev/null
    } | grep -E "^[a-zA-Z0-9]" | \
        grep -i "$DOMAIN" | \
        sed 's/^\*\.//;s/^http[s]*:\/\///;s/\/.*$//;s/:.*$//' | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u > "$SUB_DIR/all_passive.txt"

    local PASSIVE_COUNT
    PASSIVE_COUNT=$(wc -l < "$SUB_DIR/all_passive.txt")
    success "Passive enumeration: $PASSIVE_COUNT unique subdomains"

    # ── DNS Bruteforce — puredns (wildcard-aware) replaces raw massdns ──
    if command -v puredns &>/dev/null && [ -f "$WORDLIST_DNS" ] && [ -f "$RESOLVERS" ]; then
        log "[1.13] Puredns bruteforce (wildcard-aware)..."
        puredns bruteforce "$WORDLIST_DNS" "$DOMAIN" \
            -r "$RESOLVERS" \
            --write "$SUB_DIR/puredns.txt" \
            --wildcard-tests 3 \
            --wildcard-batch 1000000 \
            -q 2>>"$OUTDIR/logs/errors.log" || true
        success "Puredns: $(wc -l < "$SUB_DIR/puredns.txt" 2>/dev/null || echo 0) found"
    elif command -v massdns &>/dev/null && [ -f "$WORDLIST_DNS" ] && [ -f "$RESOLVERS" ]; then
        # Fallback: raw massdns (no wildcard filtering)
        log "[1.13] MassDNS bruteforce (fallback — install puredns for wildcard filtering)..."
        local BRUTE_CANDIDATES="$OUTDIR/tmp/brute_candidates.txt"
        local MASSDNS_RAW="$OUTDIR/tmp/massdns_raw.txt"
        sed "s/$/.$DOMAIN/" "$WORDLIST_DNS" > "$BRUTE_CANDIDATES"
        massdns -r "$RESOLVERS" -t A -o S -w "$MASSDNS_RAW" \
            "$BRUTE_CANDIDATES" 2>>"$OUTDIR/logs/errors.log"
        grep -v "CNAME" "$MASSDNS_RAW" 2>/dev/null | \
            awk '{print $1}' | sed 's/\.$//' | sort -u > "$SUB_DIR/puredns.txt"
        success "MassDNS (fallback): $(wc -l < "$SUB_DIR/puredns.txt") found"
    fi

    # ── Permutation with dnsgen ──
    if command -v dnsgen &>/dev/null && [ -f "$SUB_DIR/all_passive.txt" ]; then
        log "[1.13] DNSGen permutation scan..."
        local PERM_WORDLIST="$OUTDIR/tmp/perm_wordlist.txt"
        local PERM_RAW="$OUTDIR/tmp/perm_raw.txt"
        dnsgen "$SUB_DIR/all_passive.txt" > "$PERM_WORDLIST" 2>/dev/null
        if command -v puredns &>/dev/null && [ -f "$RESOLVERS" ]; then
            puredns resolve "$PERM_WORDLIST" \
                -r "$RESOLVERS" \
                --write "$SUB_DIR/permutation.txt" \
                -q 2>>"$OUTDIR/logs/errors.log" || true
            success "Permutation (puredns): $(wc -l < "$SUB_DIR/permutation.txt" 2>/dev/null || echo 0) found"
        elif command -v massdns &>/dev/null && [ -f "$RESOLVERS" ]; then
            massdns -r "$RESOLVERS" -t A -o S -w "$PERM_RAW" \
                "$PERM_WORDLIST" 2>>"$OUTDIR/logs/errors.log"
            grep -v "CNAME" "$PERM_RAW" 2>/dev/null | \
                awk '{print $1}' | sed 's/\.$//' | sort -u > "$SUB_DIR/permutation.txt"
        fi
    fi

    # ── DNS resolution + wildcard filter with dnsx ──
    # dnsx validates each subdomain and removes wildcards / dead entries
    local DNSX_INPUT="$OUTDIR/tmp/dnsx_input.txt"
    {
        cat "$SUB_DIR/all_passive.txt" 2>/dev/null
        cat "$SUB_DIR/puredns.txt"     2>/dev/null
        cat "$SUB_DIR/permutation.txt" 2>/dev/null
    } | sort -u > "$DNSX_INPUT"

    if command -v dnsx &>/dev/null && [ -s "$DNSX_INPUT" ]; then
        log "[1.14] dnsx — DNS resolution + wildcard filter ($(wc -l < "$DNSX_INPUT") candidates)..."
        dnsx -l "$DNSX_INPUT" \
            -r "$RESOLVERS" \
            -silent \
            -wd "$DOMAIN" \
            -o "$SUB_DIR/dnsx_resolved.txt" \
            2>>"$OUTDIR/logs/errors.log" || true
        success "dnsx resolved: $(wc -l < "$SUB_DIR/dnsx_resolved.txt" 2>/dev/null || echo 0) valid subdomains"
    fi

    # ── Final merge ──
    log "[1.15] Final merge and deduplication..."
    {
        cat "$SUB_DIR/subfinder.txt"      2>/dev/null
        cat "$SUB_DIR/assetfinder.txt"    2>/dev/null
        cat "$SUB_DIR/crtsh.txt"          2>/dev/null
        cat "$SUB_DIR/archiveorg.txt"     2>/dev/null
        cat "$SUB_DIR/securitytrails.txt" 2>/dev/null
        cat "$SUB_DIR/rapiddns.txt"       2>/dev/null
        cat "$SUB_DIR/findomain.txt"      2>/dev/null
        cat "$SUB_DIR/amass.txt"          2>/dev/null
        cat "$SUB_DIR/hackertarget.txt"   2>/dev/null
        cat "$SUB_DIR/otx.txt"            2>/dev/null
        cat "$SUB_DIR/chaos.txt"          2>/dev/null
        cat "$SUB_DIR/puredns.txt"        2>/dev/null
        cat "$SUB_DIR/permutation.txt"    2>/dev/null
        # Prefer dnsx-resolved list if available (already wildcard-filtered)
        cat "$SUB_DIR/dnsx_resolved.txt"  2>/dev/null
    } | grep -E "^[a-zA-Z0-9]" | \
        grep -i "$DOMAIN" | \
        sed 's/^\*\.//;s/^http[s]*:\/\///;s/\/.*$//;s/:.*$//' | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u > "$SUB_DIR/final_subs.txt"

    filter_scope "$SUB_DIR/final_subs.txt" "$SUB_DIR/final_subs.txt"

    # Also expose as all_subdomains.txt for AI analysis phase
    cp "$SUB_DIR/final_subs.txt" "$SUB_DIR/all_subdomains.txt" 2>/dev/null || true

    local FINAL_COUNT=$(wc -l < "$SUB_DIR/final_subs.txt")
    local END_TIME=$(date +%s)
    local DUR=$((END_TIME - START_TIME))

    success "════════════════════════════════════"
    success "PHASE 1 DONE — Subdomains: $FINAL_COUNT | Time: ${DUR}s"
    success "════════════════════════════════════"
    notify "Phase 1: $FINAL_COUNT subdomains found for $DOMAIN" "🔍"
    mark_done "phase_1"
    echo ""
}
