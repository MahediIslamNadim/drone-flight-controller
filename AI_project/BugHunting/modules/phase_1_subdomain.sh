#======================= PHASE 1: SUBDOMAIN ENUMERATION =======================
phase_1_subdomain_enum() {
    if phase_done "phase_1"; then return 0; fi
    phase_banner "PHASE 1: SUBDOMAIN ENUMERATION (PASSIVE + ACTIVE)"

    local START_TIME=$(date +%s)
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

    log "[1.8] Amass (passive, 20min timeout)..."
    if command -v amass &>/dev/null; then
        (timeout 1200 amass enum -passive -d "$DOMAIN" -o "$SUB_DIR/amass.txt" -silent 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    fi

    log "[1.9] HackerTarget API..."
    (curl_safe "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" 2>/dev/null | \
        cut -d',' -f1 | sort -u > "$SUB_DIR/hackertarget.txt") &
    PIDS+=($!)

    log "[1.10] AlienVault OTX (ThreatCrowd shut down 2023)..."
    (curl_safe "https://otx.alienvault.com/api/v1/indicators/domain/$DOMAIN/passive_dns" 2>/dev/null | \
        jq -r '.passive_dns[]?.hostname // empty' 2>/dev/null | \
        grep -iE "\.$DOMAIN$" | sort -u > "$SUB_DIR/otx.txt" \
        || { warning "[1.10] AlienVault OTX lookup failed"; : > "$SUB_DIR/otx.txt"; }) &
    PIDS+=($!)

    # Wait for passive
    log "Waiting for passive sources..."
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    success "All passive sources complete"

    # ── Merge passive (explicit list avoids glob contamination) ──
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
    } | grep -E "^[a-zA-Z0-9]" | \
        grep -i "$DOMAIN" | \
        sed 's/^\*\.//;s/^http[s]*:\/\///;s/\/.*$//;s/:.*$//' | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u > "$SUB_DIR/all_passive.txt"

    local PASSIVE_COUNT=$(wc -l < "$SUB_DIR/all_passive.txt")
    success "Passive enumeration: $PASSIVE_COUNT unique subdomains"

    # ── DNS Bruteforce with MassDNS ──
    if command -v massdns &>/dev/null && [ -f "$WORDLIST_DNS" ] && [ -f "$RESOLVERS" ]; then
        log "[1.11] MassDNS bruteforce (wordlist: $WORDLIST_DNS)..."
        # Store raw/intermediate files in tmp — NOT in SUB_DIR or they pollute *.txt globs
        local BRUTE_CANDIDATES="$OUTDIR/tmp/brute_candidates.txt"
        local MASSDNS_RAW="$OUTDIR/tmp/massdns_raw.txt"
        sed "s/$/.$DOMAIN/" "$WORDLIST_DNS" > "$BRUTE_CANDIDATES"
        massdns -r "$RESOLVERS" -t A -o S -w "$MASSDNS_RAW" \
            "$BRUTE_CANDIDATES" 2>>"$OUTDIR/logs/errors.log"
        grep -v "CNAME" "$MASSDNS_RAW" 2>/dev/null | \
            awk '{print $1}' | sed 's/\.$//' | sort -u > "$SUB_DIR/massdns.txt"
        success "MassDNS: $(wc -l < "$SUB_DIR/massdns.txt") found"
    fi

    # ── Permutation with dnsgen ──
    if command -v dnsgen &>/dev/null && [ -f "$SUB_DIR/all_passive.txt" ]; then
        log "[1.12] DNSGen permutation scan..."
        # Store raw/intermediate files in tmp — NOT in SUB_DIR
        local PERM_WORDLIST="$OUTDIR/tmp/perm_wordlist.txt"
        local PERM_RAW="$OUTDIR/tmp/perm_raw.txt"
        dnsgen "$SUB_DIR/all_passive.txt" > "$PERM_WORDLIST" 2>/dev/null
        if command -v massdns &>/dev/null && [ -f "$RESOLVERS" ]; then
            massdns -r "$RESOLVERS" -t A -o S -w "$PERM_RAW" \
                "$PERM_WORDLIST" 2>>"$OUTDIR/logs/errors.log"
            grep -v "CNAME" "$PERM_RAW" 2>/dev/null | \
                awk '{print $1}' | sed 's/\.$//' | sort -u > "$SUB_DIR/permutation.txt"
            success "Permutation: $(wc -l < "$SUB_DIR/permutation.txt") found"
        fi
    fi

    # ── DNS validation with shuffledns ──
    if command -v shuffledns &>/dev/null; then
        log "[1.13] Validating with ShuffleDNS..."
        # Feed only clean subdomain files — raw massdns files live in tmp and are excluded
        {
            cat "$SUB_DIR/all_passive.txt" 2>/dev/null
            cat "$SUB_DIR/massdns.txt"    2>/dev/null
            cat "$SUB_DIR/permutation.txt" 2>/dev/null
        } | sort -u | \
            shuffledns -d "$DOMAIN" -r "$RESOLVERS" -o "$SUB_DIR/shuffledns.txt" -silent 2>/dev/null
    fi

    # ── Final merge ──
    log "[1.14] Final merge and deduplication..."
    # Explicit file list — never use *.txt glob here.
    # Raw massdns files (host. TYPE IP format) and unresolved wordlists live in
    # $OUTDIR/tmp/ and must never reach final_subs.txt.
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
        cat "$SUB_DIR/massdns.txt"        2>/dev/null
        cat "$SUB_DIR/permutation.txt"    2>/dev/null
        cat "$SUB_DIR/shuffledns.txt"     2>/dev/null
    } | grep -E "^[a-zA-Z0-9]" | \
        grep -i "$DOMAIN" | \
        sed 's/^\*\.//;s/^http[s]*:\/\///;s/\/.*$//;s/:.*$//' | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u > "$SUB_DIR/final_subs.txt"

    filter_scope "$SUB_DIR/final_subs.txt" "$SUB_DIR/final_subs.txt"

    local FINAL_COUNT=$(wc -l < "$SUB_DIR/final_subs.txt")
    local END_TIME=$(date +%s)
    local DUR=$((END_TIME - START_TIME))

    success "════════════════════════════════════"
    success "PHASE 1 DONE — Subdomains: $FINAL_COUNT | Time: ${DUR}s"
    success "════════════════════════════════════"
    notify "Phase 1: $FINAL_COUNT subdomains found for $DOMAIN" "🔍"
    echo ""
}
