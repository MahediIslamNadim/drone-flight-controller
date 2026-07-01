#======================= PHASE 9: VULNERABILITY SCANNING =======================
# Defined at module scope so background subshells spawned by phase_9_vuln_scan() can see it
run_nuclei_scan() {
    local OUTPUT_FILE="$1"; shift
    local _ALIVE="${OUTDIR}/alive/final_alive.txt"
    if [ "${AXIOM_MODE:-0}" -eq 1 ]; then
        axiom_scan "$_ALIVE" nuclei "$OUTPUT_FILE" "$@" 2>>"$OUTDIR/logs/errors.log"
    else
        network_run nuclei -l "$_ALIVE" "$@" -o "$OUTPUT_FILE" 2>>"$OUTDIR/logs/errors.log"
    fi
}

phase_9_vuln_scan() {
    if phase_done "phase_9"; then return 0; fi
    phase_banner "PHASE 9: NUCLEI FULL VULNERABILITY SCAN"

    local START_TIME
    START_TIME=$(date +%s)
    local VULN_DIR="$OUTDIR/vulns"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local TEMPLATE_BASE="$NUCLEI_TEMPLATES"

    [ ! -s "$ALIVE_FILE" ] && { error "No alive hosts!"; return; }

    mkdir -p "$VULN_DIR"
    : > "$VULN_DIR/severity_summary.txt"

    if [ "$AXIOM_MODE" -eq 1 ]; then
        TEMPLATE_BASE="$AXIOM_NUCLEI_TEMPLATES"
        log "AXIOM distributed nuclei mode enabled (remote templates: $TEMPLATE_BASE)"
    else
        log "Updating Nuclei templates..."
        nuclei -ut -silent 2>>"$OUTDIR/logs/errors.log" || true
    fi

    local PIDS=()

    log "[9.1] Nuclei CVE scan (critical+high)..."
    run_nuclei_scan "$VULN_DIR/nuclei_cves.txt" \
        -t "$TEMPLATE_BASE/cves/" \
        -severity critical,high \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -jsonl -silent &
    PIDS+=($!)

    log "[9.2] Nuclei exposed panels..."
    run_nuclei_scan "$VULN_DIR/exposed_panels.txt" \
        -t "$TEMPLATE_BASE/exposed-panels/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -silent &
    PIDS+=($!)

    log "[9.3] Nuclei misconfigurations..."
    run_nuclei_scan "$VULN_DIR/misconfigurations.txt" \
        -t "$TEMPLATE_BASE/misconfiguration/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -silent &
    PIDS+=($!)

    log "[9.4] Nuclei exposures..."
    run_nuclei_scan "$VULN_DIR/exposures.txt" \
        -t "$TEMPLATE_BASE/exposures/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -silent &
    PIDS+=($!)

    log "[9.5] Nuclei technologies..."
    run_nuclei_scan "$VULN_DIR/technologies.txt" \
        -t "$TEMPLATE_BASE/technologies/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -silent &
    PIDS+=($!)

    log "[9.6] Nuclei default credentials..."
    run_nuclei_scan "$VULN_DIR/default_logins.txt" \
        -t "$TEMPLATE_BASE/default-logins/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -silent &
    PIDS+=($!)

    log "[9.7] Nuclei SSL/TLS..."
    run_nuclei_scan "$VULN_DIR/ssl_issues.txt" \
        -t "$TEMPLATE_BASE/ssl/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -silent &
    PIDS+=($!)

    # ── nmap weak cipher suite detection ──
    log "[9.7b] nmap weak cipher suite scan..."
    : > "$VULN_DIR/weak_ciphers.txt"
    if command -v nmap &>/dev/null; then
        head -20 "$OUTDIR/subdomains/final_subs.txt" 2>/dev/null | while IFS= read -r HOST; do
            nmap --script ssl-enum-ciphers -p 443 "$HOST" 2>/dev/null \
                | grep -E "WEAK|WARNING|RC4|DES|EXPORT|NULL|MD5|TLS 1\.0|SSL" \
                >> "$VULN_DIR/weak_ciphers.txt" || true
        done &
        PIDS+=($!)
    fi

    # ── DAST mode (dynamic application security testing) ──
    log "[9.8] Nuclei DAST mode (active parameter fuzzing)..."
    if [ -s "$OUTDIR/urls/parameters.txt" ]; then
        network_run nuclei \
            -l "$OUTDIR/urls/parameters.txt" \
            -t "$TEMPLATE_BASE/dast/" \
            -severity critical,high,medium \
            -c "$NUCLEI_CONCURRENCY" \
            -rate-limit "$NUCLEI_RATE_LIMIT" \
            -o "$VULN_DIR/nuclei_dast.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log" &
        PIDS+=($!)
    fi

    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    log "[9.9] Nuclei FULL scan (all severities, critical path)..."
    run_nuclei_scan "$VULN_DIR/nuclei_full.txt" \
        -t "$TEMPLATE_BASE/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -severity critical,high,medium,low \
        -jsonl -silent

    # ── Nuclei AI fuzzing (requires nuclei v3.4+ with -ai flag and OPENAI_API_KEY) ──
    log "[9.10] Nuclei AI-assisted fuzzing..."
    if nuclei -version 2>&1 | grep -qE "3\.[4-9]|[4-9]\." && \
       [ -n "${OPENAI_API_KEY:-}" ] && \
       nuclei -help 2>&1 | grep -q "\-ai"; then
        network_run nuclei \
            -l "$ALIVE_FILE" \
            -ai \
            -severity critical,high \
            -c 5 \
            -rate-limit 30 \
            -o "$VULN_DIR/nuclei_ai_fuzz.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log" || true
        [ -s "$VULN_DIR/nuclei_ai_fuzz.txt" ] && \
            success "Nuclei AI: $(wc -l < "$VULN_DIR/nuclei_ai_fuzz.txt") findings"
    else
        info "[9.10] Nuclei AI fuzzing skipped (requires v3.4+ with -ai support and OPENAI_API_KEY)"
    fi

    # ── Merge and summarize ──
    cat "$VULN_DIR"/*.txt 2>/dev/null | sort -u > "$VULN_DIR/all_findings.txt"

    # Extract critical-only for AI analysis phase
    grep -i "\[critical\]" "$VULN_DIR/all_findings.txt" 2>/dev/null | \
        sort -u > "$VULN_DIR/nuclei_critical.txt" || : > "$VULN_DIR/nuclei_critical.txt"

    for sev in critical high medium low info; do
        local COUNT
        COUNT=$(grep -c "\[$sev\]" "$VULN_DIR/all_findings.txt" 2>/dev/null)
        COUNT=$(( ${COUNT:-0} + 0 ))
        echo "$sev: $COUNT" >> "$VULN_DIR/severity_summary.txt"
        [ "$sev" = "critical" ] && [ "$COUNT" -gt 0 ] && {
            vuln "CRITICAL FINDINGS: $COUNT"
            notify_vuln "critical" "$COUNT CRITICAL vulnerabilities on $DOMAIN"
        }
    done

    local TOTAL
    TOTAL=$(wc -l < "$VULN_DIR/all_findings.txt" 2>/dev/null)
    TOTAL=$(( TOTAL + 0 ))
    success "PHASE 9 DONE - Total findings: $TOTAL | Critical: $(wc -l < "$VULN_DIR/nuclei_critical.txt") | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 9: $TOTAL vulnerabilities found"
    mark_done "phase_9"
    echo ""
}
