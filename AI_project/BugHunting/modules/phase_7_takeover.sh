#======================= PHASE 7: SUBDOMAIN TAKEOVER =======================
phase_7_subdomain_takeover() {
    if phase_done "phase_7"; then return 0; fi
    phase_banner "PHASE 7: SUBDOMAIN TAKEOVER DETECTION"

    local START_TIME=$(date +%s)
    local TAKEOVER_DIR="$OUTDIR/takeover"
    local SUB_FILE="$OUTDIR/subdomains/final_subs.txt"

    [ ! -s "$SUB_FILE" ] && { error "No subdomains!"; return; }

    # ── Subjack ──
    if command -v subjack &>/dev/null; then
        log "[7.1] Subjack takeover scan..."
        subjack -w "$SUB_FILE" \
            -t "$THREADS" \
            -a \
            -ssl \
            -o "$TAKEOVER_DIR/subjack.txt" \
            2>>"$OUTDIR/logs/errors.log"
        local TAKE_COUNT=$(wc -l < "$TAKEOVER_DIR/subjack.txt" 2>/dev/null || echo 0)
        [ "$TAKE_COUNT" -gt 0 ] && {
            vuln "SUBDOMAIN TAKEOVER CANDIDATES: $TAKE_COUNT"
            notify_vuln "high" "Potential takeover: $TAKE_COUNT subdomains"
        }
    fi

    # ── Nuclei takeover templates ──
    log "[7.2] Nuclei takeover templates..."
    network_run nuclei -l "$SUB_FILE" \
        -t "$NUCLEI_TEMPLATES/takeovers/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -o "$TAKEOVER_DIR/nuclei_takeover.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log"

    # ── Manual CNAME check ──
    log "[7.3] CNAME→dangling check..."
    while IFS= read -r SUB; do
        local CNAME
        CNAME=$(dig CNAME "$SUB" +short 2>/dev/null | head -1)
        if [ -n "$CNAME" ]; then
            local IP
            IP=$(dig A "$CNAME" +short 2>/dev/null | head -1)
            if [ -z "$IP" ]; then
                echo "DANGLING_CNAME: $SUB -> $CNAME" >> "$TAKEOVER_DIR/dangling_cnames.txt"
                warning "Dangling CNAME: $SUB → $CNAME"
            fi
        fi
    done < "$SUB_FILE"

    success "PHASE 7 DONE — Takeover check complete | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 7: Takeover detection done" "⛳"
    echo ""
}

