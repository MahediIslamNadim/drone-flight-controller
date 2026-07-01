#======================= CONTINUOUS MONITORING =======================
prepare_monitor_mode() {
    if [ "$MONITOR_MODE" -ne 1 ]; then
        return
    fi

    log "Monitoring mode enabled"
    mkdir -p "$OUTDIR/monitoring"
    mkdir -p "$MONITOR_STATE_DIR/$DOMAIN/history"

    if command -v anew &>/dev/null; then
        info "Monitoring diff engine: anew"
    else
        warning "anew not found - falling back to comm-based diffing"
    fi
}

normalize_monitor_file() {
    local INPUT_FILE="$1"
    local OUTPUT_FILE="$2"

    if [ -s "$INPUT_FILE" ]; then
        sort -u "$INPUT_FILE" > "$OUTPUT_FILE"
    else
        : > "$OUTPUT_FILE"
    fi
}

diff_monitor_file() {
    local CURRENT_FILE="$1"
    local STATE_FILE="$2"
    local NEW_FILE="$3"
    local TMP_CURRENT="$NEW_FILE.current"

    if [ ! -f "$CURRENT_FILE" ]; then
        warning "Monitoring source missing, skipping baseline update: $CURRENT_FILE"
        : > "$NEW_FILE"
        return
    fi

    normalize_monitor_file "$CURRENT_FILE" "$TMP_CURRENT"

    if [ ! -f "$STATE_FILE" ]; then
        cp "$TMP_CURRENT" "$STATE_FILE"
        : > "$NEW_FILE"
        rm -f "$TMP_CURRENT"
        return
    fi

    if command -v anew &>/dev/null; then
        cp "$STATE_FILE" "$STATE_FILE.tmp"
        cat "$TMP_CURRENT" | anew "$STATE_FILE.tmp" > "$NEW_FILE" 2>/dev/null || :
        mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        comm -13 "$STATE_FILE" "$TMP_CURRENT" > "$NEW_FILE" 2>/dev/null || :
        cp "$TMP_CURRENT" "$STATE_FILE"
    fi

    rm -f "$TMP_CURRENT"
}

send_monitor_alert() {
    local LABEL="$1"
    local NEW_FILE="$2"
    local EMOJI="$3"
    local COUNT=0

    COUNT=$(wc -l < "$NEW_FILE" 2>/dev/null || echo 0)
    if [ "$COUNT" -eq 0 ]; then
        return
    fi

    local SAMPLE
    SAMPLE=$(head -5 "$NEW_FILE" 2>/dev/null | tr '\n' '; ' | sed 's/; $//')
    local MSG="MONITOR: $DOMAIN has $COUNT new $LABEL"

    if [ -n "$SAMPLE" ]; then
        MSG="$MSG | Sample: $SAMPLE"
    fi

    warning "New $LABEL detected: $COUNT"
    notify "$MSG" "$EMOJI"
}

write_monitor_history_snapshot() {
    local LABEL="$1"
    local SOURCE_FILE="$2"
    local SNAPSHOT_FILE="$MONITOR_STATE_DIR/$DOMAIN/history/${LABEL}-$(date +%Y%m%d-%H%M%S).txt"

    normalize_monitor_file "$SOURCE_FILE" "$SNAPSHOT_FILE"
}

generate_monitor_report() {
    local REPORT_FILE="$OUTDIR/reports/MONITORING.md"
    local SUB_NEW_COUNT=$(wc -l < "$OUTDIR/monitoring/new_subdomains.txt" 2>/dev/null || echo 0)
    local PORT_NEW_COUNT=$(wc -l < "$OUTDIR/monitoring/new_ports.txt" 2>/dev/null || echo 0)
    local JS_NEW_COUNT=$(wc -l < "$OUTDIR/monitoring/new_js_files.txt" 2>/dev/null || echo 0)

    cat > "$REPORT_FILE" << EOF
# Monitoring Diff Summary

Target: $DOMAIN
Date: $(date)
State Dir: $MONITOR_STATE_DIR/$DOMAIN

## New Assets
- New subdomains: $SUB_NEW_COUNT
- New ports: $PORT_NEW_COUNT
- New JavaScript files: $JS_NEW_COUNT

## Diff Files
- $OUTDIR/monitoring/new_subdomains.txt
- $OUTDIR/monitoring/new_ports.txt
- $OUTDIR/monitoring/new_js_files.txt

## Baseline Files
- $MONITOR_STATE_DIR/$DOMAIN/subdomains.txt
- $MONITOR_STATE_DIR/$DOMAIN/ports.txt
- $MONITOR_STATE_DIR/$DOMAIN/js_files.txt
EOF
}

generate_monitor_cron_assets() {
    if [ "$MONITOR_MODE" -ne 1 ] || [ "$MONITOR_WRITE_CRON" -ne 1 ]; then
        return
    fi

    local CRON_SCRIPT="$OUTDIR/reports/monitor_cron.sh"
    local CRON_FILE="$OUTDIR/reports/monitor_crontab.txt"
    : > "$CRON_SCRIPT"
    echo '#!/bin/bash' >> "$CRON_SCRIPT"
    echo "cd \"$DIR\" || exit 1" >> "$CRON_SCRIPT"
    echo "\"$RUNNER_PATH\" \\" >> "$CRON_SCRIPT"
    echo "  -d \"$DOMAIN\" \\" >> "$CRON_SCRIPT"
    echo "  -M \\" >> "$CRON_SCRIPT"
    echo "  --monitor-state \"$MONITOR_STATE_DIR\" \\" >> "$CRON_SCRIPT"
    echo "  --monitor-schedule \"$MONITOR_SCHEDULE\" \\" >> "$CRON_SCRIPT"

    [ "$STEALTH_MODE" -eq 1 ] && echo "  -S \\" >> "$CRON_SCRIPT"
    [ "$PARALLEL_MODE" -eq 0 ] && echo "  -P \\" >> "$CRON_SCRIPT"
    [ "$RESUME_MODE" -eq 1 ] && echo "  -r \\" >> "$CRON_SCRIPT"
    [ "$SKIP_MASSCAN" -eq 1 ] && echo "  --skip-masscan \\" >> "$CRON_SCRIPT"
    [ -n "$SCOPE_FILE" ] && echo "  -s \"$SCOPE_FILE\" \\" >> "$CRON_SCRIPT"
    [ -n "$OUT_OF_SCOPE" ] && echo "  -x \"$OUT_OF_SCOPE\" \\" >> "$CRON_SCRIPT"
    [ -n "$DISCORD_WEBHOOK" ] && echo "  --discord \"$DISCORD_WEBHOOK\" \\" >> "$CRON_SCRIPT"
    [ -n "$SLACK_WEBHOOK" ] && echo "  --slack \"$SLACK_WEBHOOK\" \\" >> "$CRON_SCRIPT"
    [ -n "$TELEGRAM_BOT_TOKEN" ] && echo "  --telegram-token \"$TELEGRAM_BOT_TOKEN\" \\" >> "$CRON_SCRIPT"
    [ -n "$TELEGRAM_CHAT_ID" ] && echo "  --telegram-chat \"$TELEGRAM_CHAT_ID\" \\" >> "$CRON_SCRIPT"

    if [ "$AXIOM_MODE" -eq 1 ]; then
        echo "  -A \\" >> "$CRON_SCRIPT"
        [ -n "$AXIOM_FLEET" ] && echo "  --fleet \"$AXIOM_FLEET\" \\" >> "$CRON_SCRIPT"
        [ "$AXIOM_SPINUP" -gt 0 ] && echo "  --axiom-spinup \"$AXIOM_SPINUP\" \\" >> "$CRON_SCRIPT"
        [ "$AXIOM_RM_WHEN_DONE" -eq 1 ] && echo "  --axiom-rm \\" >> "$CRON_SCRIPT"
        [ "$AXIOM_SHUTDOWN_WHEN_DONE" -eq 1 ] && echo "  --axiom-shutdown \\" >> "$CRON_SCRIPT"
        [ -n "$AXIOM_NUCLEI_TEMPLATES" ] && echo "  --axiom-templates \"$AXIOM_NUCLEI_TEMPLATES\" \\" >> "$CRON_SCRIPT"
    fi

    echo "  --wordlist-dns \"$WORDLIST_DNS\"" >> "$CRON_SCRIPT"

    cat > "$CRON_FILE" << EOF
# Install with: crontab $CRON_FILE
$MONITOR_SCHEDULE $CRON_SCRIPT >> "$MONITOR_STATE_DIR/$DOMAIN/monitor.log" 2>&1
EOF

    if ! command -v crontab &>/dev/null; then
        warning "crontab not found locally - cron helper generated but not installable on this machine"
    fi

    success "Monitoring cron helper written: $CRON_FILE"
}

run_monitoring_diff() {
    if [ "$MONITOR_MODE" -ne 1 ]; then
        return
    fi

    phase_banner "MONITORING DIFF"

    local STATE_ROOT="$MONITOR_STATE_DIR/$DOMAIN"
    mkdir -p "$STATE_ROOT" "$OUTDIR/monitoring"

    diff_monitor_file "$OUTDIR/subdomains/final_subs.txt" "$STATE_ROOT/subdomains.txt" "$OUTDIR/monitoring/new_subdomains.txt"
    diff_monitor_file "$OUTDIR/ports/all_ports.txt" "$STATE_ROOT/ports.txt" "$OUTDIR/monitoring/new_ports.txt"
    diff_monitor_file "$OUTDIR/urls/js_files.txt" "$STATE_ROOT/js_files.txt" "$OUTDIR/monitoring/new_js_files.txt"

    write_monitor_history_snapshot "subdomains" "$OUTDIR/subdomains/final_subs.txt"
    write_monitor_history_snapshot "ports" "$OUTDIR/ports/all_ports.txt"
    write_monitor_history_snapshot "js_files" "$OUTDIR/urls/js_files.txt"

    send_monitor_alert "subdomains" "$OUTDIR/monitoring/new_subdomains.txt" "🛰️"
    send_monitor_alert "ports" "$OUTDIR/monitoring/new_ports.txt" "🔓"
    send_monitor_alert "JavaScript files" "$OUTDIR/monitoring/new_js_files.txt" "📜"

    generate_monitor_report
    generate_monitor_cron_assets
}
