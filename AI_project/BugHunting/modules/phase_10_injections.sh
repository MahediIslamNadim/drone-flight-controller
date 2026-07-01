#======================= PHASE 10: INJECTION ATTACKS =======================
phase_10_injections() {
    if phase_done "phase_10"; then return 0; fi
    phase_banner "PHASE 10: INJECTION TESTING (XSS / SQLI / SSRF / LFI / REDIRECT)"

    local START_TIME=$(date +%s)
    local INJ_DIR="$OUTDIR/injections"
    local PARAM_FILE="$OUTDIR/urls/parameters.txt"

    [ ! -s "$PARAM_FILE" ] && { warning "No parameter URLs found, skipping injection tests"; return; }
    if should_skip_noisy_phase "Phase 10 active injection testing"; then
        return
    fi

    # XSS with dalfox
    if command -v dalfox &>/dev/null; then
        log "[10.1] XSS hunting with dalfox..."
        network_run dalfox file "$PARAM_FILE" \
            --skip-bav \
            --no-color \
            --silence \
            -o "$INJ_DIR/dalfox_xss.txt" \
            -w "$THREADS" \
            2>>"$OUTDIR/logs/errors.log"

        local XSS_COUNT
        XSS_COUNT=$(grep -c "POC" "$INJ_DIR/dalfox_xss.txt" 2>/dev/null || echo 0)
        [ "$XSS_COUNT" -gt 0 ] && {
            vuln "XSS FOUND: $XSS_COUNT endpoints"
            notify_vuln "high" "XSS: $XSS_COUNT endpoints vulnerable"
        }
        success "Dalfox XSS: $XSS_COUNT potential findings"
    else
        log "[10.1] XSS via nuclei (dalfox not found)..."
        network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
            -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/xss*" \
            -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/xss/" \
            -c "$NUCLEI_CONCURRENCY" \
            -o "$INJ_DIR/nuclei_xss.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log" || true
    fi

    # SQLi with ghauri/sqlmap
    if command -v ghauri &>/dev/null; then
        log "[10.2] SQLi with ghauri (fast, non-intrusive)..."
        head -50 "$PARAM_FILE" | while IFS= read -r URL; do
            network_run ghauri -u "$URL" --level 1 --batch --dbs \
                >> "$INJ_DIR/ghauri_sqli.txt" 2>/dev/null || true
        done
    elif command -v sqlmap &>/dev/null; then
        log "[10.2] SQLi with sqlmap..."
        network_run sqlmap -m "$PARAM_FILE" \
            --batch \
            --level 2 \
            --risk 2 \
            --random-agent \
            --timeout 10 \
            --retries 2 \
            --output-dir "$INJ_DIR/sqlmap" \
            2>>"$OUTDIR/logs/errors.log"
    else
        network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
            -t "$NUCLEI_TEMPLATES/vulnerabilities/" \
            -tags sqli \
            -c "$NUCLEI_CONCURRENCY" \
            -o "$INJ_DIR/nuclei_sqli.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log" || true
    fi

    log "[10.3] SSRF detection..."
    network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/ssrf*" \
        -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/ssrf/" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/ssrf.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    log "[10.4] LFI/RFI testing..."
    network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/lfi*" \
        -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/lfi/" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/lfi.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    log "[10.5] Open redirect testing..."
    network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/redirect*" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/open_redirect.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    log "[10.6] Host header injection..."
    head -50 "$OUTDIR/alive/final_alive.txt" | while IFS= read -r URL; do
        local RESP
        RESP=$(curl_safe -H "Host: example.invalid" -H "X-Forwarded-Host: example.invalid" \
            -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo 000)
        record_block_signal "$RESP" "$URL"
        echo "[$RESP] $URL" >> "$INJ_DIR/host_header.txt"
    done

    network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/host-header*" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/host_header_nuclei.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    log "[10.7] Prototype pollution check..."
    network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/prototype-pollution*" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/prototype_pollution.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    log "[10.8] Command injection..."
    network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
        -t "$NUCLEI_TEMPLATES/dast/vulnerabilities/rce/" \
        -c "$NUCLEI_CONCURRENCY" \
        -o "$INJ_DIR/cmdi.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    cooldown_if_waf_pressure
    success "PHASE 10 DONE - Injection testing complete | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 10: Injection testing done" "INJ"
    echo ""
}
