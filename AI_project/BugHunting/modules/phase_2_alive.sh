#======================= PHASE 2: ALIVE HOST DETECTION =======================
phase_2_alive_check() {
    if phase_done "phase_2"; then return 0; fi
    phase_banner "PHASE 2: ALIVE HOST DETECTION + FINGERPRINTING"

    local START_TIME=$(date +%s)
    local ALIVE_DIR="$OUTDIR/alive"
    local SUB_FILE="$OUTDIR/subdomains/final_subs.txt"

    [ ! -s "$SUB_FILE" ] && { error "No subdomains! Skipping."; return; }

    # ── HTTP Probing ──
    if [ "$AXIOM_MODE" -eq 1 ]; then
        log "[2.1] HTTP/HTTPS probing with httpx via AXIOM..."
        axiom_scan "$SUB_FILE" httpx "$ALIVE_DIR/httpx_full.json" \
            -threads "$HTTPX_THREADS" \
            -timeout "$TIMEOUT" \
            -retries "$RETRIES" \
            -follow-redirects \
            -status-code \
            -title \
            -tech-detect \
            -web-server \
            -content-length \
            -cdn \
            -ip \
            -cname \
            -json \
            -silent 2>>"$OUTDIR/logs/errors.log"
    else
        log "[2.1] HTTP/HTTPS probing with httpx (Local)..."
        cat "$SUB_FILE" | network_run httpx \
            -threads "$HTTPX_THREADS" \
            -timeout "$TIMEOUT" \
            -retries "$RETRIES" \
            -follow-redirects \
            -status-code \
            -title \
            -tech-detect \
            -web-server \
            -content-length \
            -cdn \
            -ip \
            -cname \
            -json \
            -o "$ALIVE_DIR/httpx_full.json" \
            -silent 2>>"$OUTDIR/logs/errors.log"
    fi

    # Extract URLs
    cat "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        jq -r '.url' 2>/dev/null | sort -u > "$ALIVE_DIR/alive_http.txt"

    # ── Categorize by status ──
    mkdir -p "$ALIVE_DIR/by_status"
    for code in 200 201 204 301 302 307 308 400 401 403 404 429 500 502 503; do
        cat "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
            jq -r "select(.status_code==$code) | .url" 2>/dev/null | \
            sort -u > "$ALIVE_DIR/by_status/status_$code.txt"
    done

    cat "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        jq -r 'select(.status_code==403 or .status_code==429 or .status_code==503) | "\(.status_code)\t\(.url)"' 2>/dev/null | \
        while IFS=$'\t' read -r STATUS URL; do
            [ -n "$STATUS" ] && record_block_signal "$STATUS" "$URL"
        done

    # ── Priority alive list ──
    cat "$ALIVE_DIR/by_status/status_200.txt" \
        "$ALIVE_DIR/by_status/status_301.txt" \
        "$ALIVE_DIR/by_status/status_302.txt" \
        "$ALIVE_DIR/by_status/status_403.txt" 2>/dev/null | sort -u > "$ALIVE_DIR/final_alive.txt"

    # ── Screenshots ──
    local SCREENSHOT_PID=""
    if command -v eyewitness &>/dev/null; then
        log "[2.2] Taking screenshots with EyeWitness (background)..."
        eyewitness --web -f "$ALIVE_DIR/final_alive.txt" \
            -d "$OUTDIR/screenshots" --no-prompt --timeout 20 \
            2>>"$OUTDIR/logs/errors.log" &
        SCREENSHOT_PID=$!
    elif command -v gowitness &>/dev/null; then
        log "[2.2] Taking screenshots with gowitness (background)..."
        gowitness file -f "$ALIVE_DIR/final_alive.txt" \
            --screenshot-path "$OUTDIR/screenshots" \
            2>>"$OUTDIR/logs/errors.log" &
        SCREENSHOT_PID=$!
    fi

    # ── WAF Detection ──
    log "[2.3] WAF detection..."
    if command -v wafw00f &>/dev/null; then
        head -50 "$ALIVE_DIR/final_alive.txt" | while IFS= read -r URL; do
            network_run wafw00f "$URL" 2>/dev/null | \
                grep -i "detected\|protected" >> "$ALIVE_DIR/waf_detected.txt" || true
        done
        success "WAF detection complete: $(wc -l < "$ALIVE_DIR/waf_detected.txt" 2>/dev/null || echo 0) WAFs found"
    else
        # Manual WAF check via headers
        head -30 "$ALIVE_DIR/final_alive.txt" | while IFS= read -r URL; do
            HEADERS=$(curl_safe -I "$URL" 2>/dev/null || :)
            echo "$HEADERS" | grep -i "cloudflare\|akamai\|sucuri\|incapsula\|x-waf\|aws-waf\|imperva" | \
                sed "s/^/$URL: /" >> "$ALIVE_DIR/waf_detected.txt" || true
        done
    fi

    # ── Technology fingerprint summary ──
    cat "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        jq -r '.tech[]?' 2>/dev/null | \
        sort | uniq -c | sort -rn > "$ALIVE_DIR/tech_summary.txt"

    # ── CDN-hosted hosts (de-prioritize) ──
    cat "$ALIVE_DIR/httpx_full.json" 2>/dev/null | \
        jq -r 'select(.cdn==true) | .url' 2>/dev/null | \
        sort -u > "$ALIVE_DIR/cdn_hosts.txt"

    cooldown_if_waf_pressure

    # Wait for screenshot job and report result
    if [ -n "$SCREENSHOT_PID" ]; then
        log "[2.2] Waiting for screenshot job (PID $SCREENSHOT_PID)..."
        wait "$SCREENSHOT_PID" 2>/dev/null \
            && success "Screenshots complete" \
            || warning "Screenshot tool exited with error — check $OUTDIR/logs/errors.log"
    fi

    local ALIVE_COUNT=$(wc -l < "$ALIVE_DIR/final_alive.txt")
    local END_TIME=$(date +%s)
    success "PHASE 2 DONE — Alive: $ALIVE_COUNT | Time: $((END_TIME-START_TIME))s"
    notify "Phase 2: $ALIVE_COUNT alive hosts" "🌐"
    echo ""
}
