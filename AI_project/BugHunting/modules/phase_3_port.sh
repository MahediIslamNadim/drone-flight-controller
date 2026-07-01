#======================= PHASE 3: PORT SCANNING =======================
phase_3_port_scan() {
    if phase_done "phase_3"; then return 0; fi
    phase_banner "PHASE 3: PORT SCANNING + SERVICE DETECTION"

    local START_TIME
    START_TIME=$(date +%s)
    local PORT_DIR="$OUTDIR/ports"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    [ ! -s "$ALIVE_FILE" ] && ALIVE_FILE="$OUTDIR/subdomains/final_subs.txt"

    # Prepare IP/domain list
    sed 's|https\?://||g;s|/.*||;s|:.*||' "$ALIVE_FILE" | sort -u > "$PORT_DIR/scan_targets.txt"

    # ── Masscan (root only) ──
    if [ "$IS_ROOT" -eq 1 ] && [ "$SKIP_MASSCAN" -eq 0 ]; then
        if ! command -v masscan &>/dev/null; then
            warning "[3.1] masscan not found — skipping full port range scan"
        else
        log "[3.1] Masscan full port range (rate: $MASSCAN_RATE)..."
        masscan -iL "$PORT_DIR/scan_targets.txt" \
            -p1-65535 \
            --rate "$MASSCAN_RATE" \
            -oG "$PORT_DIR/masscan.gnmap" \
            2>>"$OUTDIR/logs/errors.log"
        grep "Host:" "$PORT_DIR/masscan.gnmap" 2>/dev/null | \
            awk '{print $2 ":" $5}' | sed 's|/open/.*||' | sort -u > "$PORT_DIR/masscan_ports.txt"
        success "Masscan: $(wc -l < "$PORT_DIR/masscan_ports.txt" 2>/dev/null) ports"
        fi  # end masscan installed check
    fi

    # ── Naabu ──
    if [ "$AXIOM_MODE" -eq 1 ]; then
        log "[3.2] Naabu top 1000 ports via AXIOM..."
        axiom_scan "$PORT_DIR/scan_targets.txt" naabu "$PORT_DIR/naabu.txt" \
            -top-ports 1000 \
            -rate "$NAABU_RATE" \
            -silent 2>>"$OUTDIR/logs/errors.log"
    elif command -v naabu &>/dev/null; then
        log "[3.2] Naabu top 1000 ports (Local)..."
        naabu -list "$PORT_DIR/scan_targets.txt" \
            -top-ports 1000 \
            -rate "$NAABU_RATE" \
            -o "$PORT_DIR/naabu.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log"
    else
        warning "[3.2] naabu not found — skipping top-1000 port scan"
    fi
    success "Naabu: $(wc -l < "$PORT_DIR/naabu.txt" 2>/dev/null || echo 0) ports"

    # ── Service detection on interesting ports ──
    log "[3.3] Service detection on interesting ports..."
    # Explicitly merge only port-result files — NOT scan_targets.txt (bare hostnames, no ports)
    {
        [ -f "$PORT_DIR/masscan_ports.txt" ] && cat "$PORT_DIR/masscan_ports.txt"
        [ -f "$PORT_DIR/naabu.txt" ]         && cat "$PORT_DIR/naabu.txt"
    } | sort -u > "$PORT_DIR/all_ports.txt"

    # Probe non-standard ports with httpx
    grep -v ":80$\|:443$" "$PORT_DIR/all_ports.txt" 2>/dev/null | \
        head -200 | \
        network_run httpx -silent -status-code -title \
        -threads "$HTTPX_THREADS" \
        -o "$PORT_DIR/unusual_services.txt" 2>/dev/null || true

    success "PHASE 3 DONE — Open ports: $(wc -l < "$PORT_DIR/all_ports.txt" 2>/dev/null) | Time: $(( $(date +%s) - $START_TIME ))s"
    notify "Phase 3: $(wc -l < "$PORT_DIR/all_ports.txt" 2>/dev/null) open ports" "🔓"
    echo ""
}
