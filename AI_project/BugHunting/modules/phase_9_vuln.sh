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
        -json -silent &
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

    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    log "[9.8] Nuclei FULL scan (all severities)..."
    run_nuclei_scan "$VULN_DIR/nuclei_full.txt" \
        -t "$TEMPLATE_BASE/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -severity critical,high,medium,low \
        -json -silent

    cat "$VULN_DIR"/*.txt 2>/dev/null | sort -u > "$VULN_DIR/all_findings.txt"

    for sev in critical high medium low info; do
        local COUNT=$(grep -c "\[$sev\]" "$VULN_DIR/all_findings.txt" 2>/dev/null || echo 0)
        echo "$sev: $COUNT" >> "$VULN_DIR/severity_summary.txt"
        [ "$sev" = "critical" ] && [ "$COUNT" -gt 0 ] && {
            vuln "CRITICAL FINDINGS: $COUNT"
            notify_vuln "critical" "$COUNT CRITICAL vulnerabilities on $DOMAIN"
        }
    done

    local TOTAL=$(wc -l < "$VULN_DIR/all_findings.txt" 2>/dev/null)
    success "PHASE 9 DONE - Total findings: $TOTAL | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 9: $TOTAL vulnerabilities found"
    echo ""
}
