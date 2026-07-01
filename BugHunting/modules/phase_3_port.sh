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
        fi
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

    # ── Merge discovered ports ──
    {
        [ -f "$PORT_DIR/masscan_ports.txt" ] && cat "$PORT_DIR/masscan_ports.txt"
        [ -f "$PORT_DIR/naabu.txt" ]         && cat "$PORT_DIR/naabu.txt"
    } | sort -u > "$PORT_DIR/all_ports.txt"

    # ── Nmap service + script detection on open ports ──
    log "[3.3] Nmap service detection on discovered ports..."
    if command -v nmap &>/dev/null && [ -s "$PORT_DIR/all_ports.txt" ]; then
        # Build nmap target list from host:port pairs
        local NMAP_HOSTS="$PORT_DIR/nmap_hosts.txt"
        local NMAP_PORTS="$PORT_DIR/nmap_ports.txt"
        awk -F: '{print $1}' "$PORT_DIR/all_ports.txt" | sort -u > "$NMAP_HOSTS"
        awk -F: '{print $2}' "$PORT_DIR/all_ports.txt" | sort -un | tr '\n' ',' | \
            sed 's/,$//' > "$NMAP_PORTS"
        local PORT_LIST
        PORT_LIST=$(cat "$NMAP_PORTS" 2>/dev/null)
        # Limit to top 500 unique ports to keep nmap fast
        PORT_LIST=$(echo "$PORT_LIST" | tr ',' '\n' | head -500 | tr '\n' ',' | sed 's/,$//')

        if [ -n "$PORT_LIST" ] && [ -s "$NMAP_HOSTS" ]; then
            local NMAP_TIMING="-T4"
            if [ "$WAF_AWARE" -eq 1 ] && [ -s "$OUTDIR/alive/waf_detected.txt" ]; then
                NMAP_TIMING="-T2"
                info "[3.3] WAF detected — nmap running in stealth timing (-T2)"
            fi
            nmap -sV -sC --open \
                -iL "$NMAP_HOSTS" \
                -p "$PORT_LIST" \
                $NMAP_TIMING \
                --max-retries 2 \
                --host-timeout 5m \
                -oN "$PORT_DIR/nmap_services.txt" \
                -oG "$PORT_DIR/nmap_grep.txt" \
                2>>"$OUTDIR/logs/errors.log" || true
            _nmap_cnt=$(grep -c "^Host:" "$PORT_DIR/nmap_grep.txt" 2>/dev/null); _nmap_cnt=$(( ${_nmap_cnt:-0} + 0 ))
            success "Nmap: $_nmap_cnt hosts scanned"
        fi

        # Extract interesting service banners
        grep -E "open.*http|open.*ssh|open.*ftp|open.*smb|open.*redis|open.*mongo|open.*mysql|open.*postgres" \
            "$PORT_DIR/nmap_services.txt" 2>/dev/null | \
            sort -u > "$PORT_DIR/interesting_services.txt" || true

        # Feed interesting services to open_ports.txt (for AI context)
        cat "$PORT_DIR/nmap_services.txt" 2>/dev/null | \
            grep -E "^[0-9]+/tcp" | sort -u > "$PORT_DIR/open_ports.txt" || true
    else
        # Fallback: convert all_ports.txt to open_ports.txt format
        cat "$PORT_DIR/all_ports.txt" 2>/dev/null | \
            awk -F: '{print $2"/tcp open host="$1}' | sort -u > "$PORT_DIR/open_ports.txt" || true
    fi

    # ── Probe non-standard HTTP ports ──
    log "[3.4] HTTP probe on non-standard ports..."
    grep -v ":80$\|:443$" "$PORT_DIR/all_ports.txt" 2>/dev/null | \
        head -200 | \
        network_run httpx -silent -status-code -title \
        -threads "$HTTPX_THREADS" \
        -o "$PORT_DIR/unusual_services.txt" 2>/dev/null || true

    success "PHASE 3 DONE — Open ports: $(wc -l < "$PORT_DIR/all_ports.txt" 2>/dev/null) | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 3: $(wc -l < "$PORT_DIR/all_ports.txt" 2>/dev/null) open ports" "🔓"
    mark_done "phase_3"
    echo ""
}
