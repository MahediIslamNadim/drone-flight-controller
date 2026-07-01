#======================= PHASE 2: ALIVE HOST DETECTION =======================
phase_2_alive_check() {
    if phase_done "phase_2"; then return 0; fi
    phase_banner "PHASE 2: ALIVE HOST DETECTION + FINGERPRINTING"

    local START_TIME
    START_TIME=$(date +%s)
    local ALIVE_DIR="$OUTDIR/alive"
    local SUB_FILE="$OUTDIR/subdomains/final_subs.txt"

    [ ! -s "$SUB_FILE" ] && { error "No subdomains! Skipping."; return; }

    # ── HTTP Probing with httpx (upgraded flags) ──
    local HTTPX_FLAGS=(
        -threads "$HTTPX_THREADS"
        -timeout "$TIMEOUT"
        -retries "$RETRIES"
        -follow-redirects
        -status-code
        -title
        -tech-detect
        -web-server
        -content-length
        -cdn
        -ip
        -cname
        -favicon
        -hash sha256
        -random-agent
        -json
        -silent
    )

    if [ "$AXIOM_MODE" -eq 1 ]; then
        log "[2.1] HTTP/HTTPS probing with httpx via AXIOM..."
        axiom_scan "$SUB_FILE" httpx "$ALIVE_DIR/httpx_full.json" \
            "${HTTPX_FLAGS[@]}" 2>>"$OUTDIR/logs/errors.log"
    else
        log "[2.1] HTTP/HTTPS probing with httpx (Local)..."
        cat "$SUB_FILE" | network_run httpx \
            "${HTTPX_FLAGS[@]}" \
            -o "$ALIVE_DIR/httpx_full.json" \
            2>>"$OUTDIR/logs/errors.log"
    fi

    # Extract URLs
    jq -r '.url' "$ALIVE_DIR/httpx_full.json" 2>/dev/null | sort -u > "$ALIVE_DIR/alive_http.txt"

    # ── Categorize by status ──
    mkdir -p "$ALIVE_DIR/by_status"
    for code in 200 201 204 301 302 307 308 400 401 403 404 429 500 502 503; do
        jq -r "select(.status_code==$code) | .url" \
            "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
            sort -u > "$ALIVE_DIR/by_status/status_$code.txt"
    done

    jq -r 'select(.status_code==403 or .status_code==429 or .status_code==503) |
        "\(.status_code)\t\(.url)"' "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        while IFS=$'\t' read -r STATUS URL; do
            [ -n "$STATUS" ] && record_block_signal "$STATUS" "$URL"
        done

    # ── Priority alive list ──
    cat "$ALIVE_DIR/by_status/status_200.txt" \
        "$ALIVE_DIR/by_status/status_301.txt" \
        "$ALIVE_DIR/by_status/status_302.txt" \
        "$ALIVE_DIR/by_status/status_403.txt" 2>/dev/null | sort -u > "$ALIVE_DIR/final_alive.txt"

    # ── Screenshots — httpx built-in (replaces gowitness) ──
    log "[2.2] Taking screenshots with httpx --screenshot..."
    local SCREENSHOT_DONE=0
    if cat "$ALIVE_DIR/final_alive.txt" | network_run httpx \
        -screenshot \
        -screenshot-timeout 15 \
        -threads 10 \
        -silent \
        -srd "$OUTDIR/screenshots" \
        2>>"$OUTDIR/logs/errors.log"; then
        SCREENSHOT_DONE=1
        success "Screenshots saved to $OUTDIR/screenshots/"
    fi

    # Fallback: eyewitness if httpx screenshot failed or not supported
    if [ "$SCREENSHOT_DONE" -eq 0 ] && command -v eyewitness &>/dev/null; then
        log "[2.2] Fallback: EyeWitness screenshots..."
        eyewitness --web -f "$ALIVE_DIR/final_alive.txt" \
            -d "$OUTDIR/screenshots" --no-prompt --timeout 20 \
            2>>"$OUTDIR/logs/errors.log" &
    fi

    # ── WAF Detection ──
    log "[2.3] WAF detection..."
    mkdir -p "$OUTDIR/waf"
    : > "$OUTDIR/waf/waf_detected.txt"

    # Priority 1: httpx tech-detect already ran — extract WAF technologies from JSON
    jq -r 'select(.tech != null) | [.url, (.tech | join(","))] | join(" | ")' \
        "$ALIVE_DIR/httpx_full.json" 2>/dev/null \
        | grep -iE "cloudflare|akamai|incapsula|imperva|aws-waf|sucuri|f5|barracuda|reblaze|fastly|wallarm" \
        >> "$OUTDIR/waf/waf_detected.txt" || true

    # Priority 2: wafw00f deep scan (only on hosts not already identified)
    if command -v wafw00f &>/dev/null; then
        head -50 "$ALIVE_DIR/final_alive.txt" | while IFS= read -r URL; do
            network_run wafw00f "$URL" 2>/dev/null | \
                grep -i "detected\|protected" >> "$OUTDIR/waf/waf_detected.txt" || true
        done
    fi

    # Priority 3: header-based fallback for unknown WAFs
    head -20 "$ALIVE_DIR/final_alive.txt" 2>/dev/null | while IFS= read -r URL; do
        local HEADERS
        HEADERS=$(curl_safe -I "$URL" 2>/dev/null || :)
        echo "$HEADERS" | grep -iE "x-waf|cf-ray|x-sucuri|x-iinfo|x-avi-|server-timing.*edge|x-cdn" | \
            awk -v prefix="$URL: " '{print prefix $0}' >> "$OUTDIR/waf/waf_detected.txt" || true
    done

    sort -u "$OUTDIR/waf/waf_detected.txt" -o "$OUTDIR/waf/waf_detected.txt"
    # Symlink into alive dir for should_skip_noisy_phase check
    ln -sf "$OUTDIR/waf/waf_detected.txt" "$ALIVE_DIR/waf_detected.txt" 2>/dev/null || true
    local WAF_CNT
    WAF_CNT=$(wc -l < "$OUTDIR/waf/waf_detected.txt" 2>/dev/null || echo 0)
    success "WAF detection: $WAF_CNT WAF indicators found"
    [ "$WAF_CNT" -gt 0 ] && info "WAF-aware mode will apply stealth rates to active phases"

    # ── Technology fingerprint summary ──
    jq -r '.tech[]?' "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        sort | uniq -c | sort -rn > "$ALIVE_DIR/tech_summary.txt"

    # Also write a flat tech_stack.txt for the AI analysis context builder
    mkdir -p "$OUTDIR/technology"
    jq -r '[.url, (.tech // [] | join(", "))] | join(" — ")' \
        "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        grep -v " — $" | sort -u > "$OUTDIR/technology/tech_stack.txt"

    # ── CDN-hosted hosts ──
    jq -r 'select(.cdn==true) | .url' "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        sort -u > "$ALIVE_DIR/cdn_hosts.txt"

    # ── JARM fingerprinting (TLS fingerprint — identifies server stacks) ──
    if command -v jarm &>/dev/null; then
        log "[2.4] JARM TLS fingerprinting..."
        head -30 "$ALIVE_DIR/final_alive.txt" | \
            sed 's|https\?://||;s|/.*||' | sort -u | \
            while IFS= read -r HOST; do
                jarm "$HOST" 2>/dev/null | \
                    grep -v "^$" >> "$ALIVE_DIR/jarm_fingerprints.txt" || true
            done
    fi

    cooldown_if_waf_pressure

    local ALIVE_COUNT=$(wc -l < "$ALIVE_DIR/final_alive.txt")
    local END_TIME=$(date +%s)
    success "PHASE 2 DONE — Alive: $ALIVE_COUNT | Time: $((END_TIME-START_TIME))s"
    notify "Phase 2: $ALIVE_COUNT alive hosts" "🌐"
    mark_done "phase_2"
    echo ""
}
