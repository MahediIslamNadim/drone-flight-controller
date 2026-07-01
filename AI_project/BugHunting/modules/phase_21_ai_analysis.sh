#======================= PHASE 21: AI-POWERED ANALYSIS (CLAUDE API) =======================
# Uses Anthropic Claude API to analyze findings, prioritize vulnerabilities, generate PoC hints

_ai_call() {
    local PROMPT="$1"
    local MAX_TOKENS="${2:-1024}"

    [ -z "$ANTHROPIC_API_KEY" ] && { echo "NO_API_KEY"; return 1; }

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg model "$AI_ANALYSIS_MODEL" \
        --arg content "$PROMPT" \
        --argjson max_tokens "$MAX_TOKENS" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            messages: [{ role: "user", content: $content }]
        }')

    local RESP
    # curl_api enforces TLS cert verification (no -k) for external API calls
    RESP=$(curl_api \
        -X POST "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "anthropic-beta: prompt-caching-2024-07-31" \
        -H "content-type: application/json" \
        -d "$PAYLOAD" \
        --max-time 60 2>/dev/null)

    echo "$RESP" | jq -r '.content[0].text // empty' 2>/dev/null
}

_ai_summarize_findings() {
    local AI_DIR="$1"

    log "[AI] Summarizing all findings for AI analysis..."

    # Build structured findings summary
    local FINDINGS_SUMMARY=""

    # Collect critical findings from all phases
    local VULN_COUNT=0
    for VULN_FILE in \
        "$OUTDIR/advanced/advanced_vulns.txt" \
        "$OUTDIR/advanced/injections/ssti_hits.txt" \
        "$OUTDIR/advanced/injections/xxe_hits.txt" \
        "$OUTDIR/advanced/injections/upload_hits.txt" \
        "$OUTDIR/advanced/websocket/cswsh_hits.txt" \
        "$OUTDIR/advanced/smuggling/smuggling_candidates.txt" \
        "$OUTDIR/advanced/graphql/mutation_hits.txt" \
        "$OUTDIR/oob/callback_summary.txt" \
        "$OUTDIR/infrastructure/exposed_services.txt" \
        "$OUTDIR/infrastructure/k8s_exposure.txt" \
        "$OUTDIR/network_recon/origin_ip_hits.txt"; do

        if [ -s "$VULN_FILE" ]; then
            local SECTION
            SECTION=$(basename "$(dirname "$VULN_FILE")")/$(basename "$VULN_FILE")
            FINDINGS_SUMMARY+="=== $SECTION ===\n"
            FINDINGS_SUMMARY+=$(head -10 "$VULN_FILE")
            FINDINGS_SUMMARY+="\n\n"
            VULN_COUNT=$(( VULN_COUNT + $(wc -l < "$VULN_FILE" 2>/dev/null || echo 0) ))
        fi
    done

    if [ "$VULN_COUNT" -eq 0 ]; then
        info "[AI] No findings to analyze"
        return
    fi

    echo -e "$FINDINGS_SUMMARY" > "$AI_DIR/findings_for_ai.txt"
    success "[AI] Collected $VULN_COUNT total finding lines for analysis"
}

_ai_prioritize_vulns() {
    local AI_DIR="$1"

    [ -s "$AI_DIR/findings_for_ai.txt" ] || return

    log "[AI] Asking Claude to prioritize vulnerabilities..."

    local PROMPT="You are a senior penetration tester reviewing bug bounty findings for the domain ${DOMAIN}.

Here are the raw findings:

$(head -200 "$AI_DIR/findings_for_ai.txt")

Please:
1. Rank the top 5 most critical findings by exploitability and impact (CVSS-style thinking)
2. For each: explain WHY it's critical and what the business impact is
3. Suggest a 1-2 sentence proof-of-concept approach for each
4. Flag any false positive risks
5. Recommend which to report first for maximum bounty impact

Be concise and technical. Format as numbered list."

    local AI_RESP
    AI_RESP=$(_ai_call "$PROMPT" 2048)

    if [ -n "$AI_RESP" ] && [ "$AI_RESP" != "NO_API_KEY" ]; then
        {
            echo "=== AI VULNERABILITY PRIORITIZATION ==="
            echo "Target: $DOMAIN"
            echo "Generated: $(date)"
            echo ""
            echo "$AI_RESP"
        } > "$AI_DIR/ai_prioritization.txt"
        success "[AI] Vulnerability prioritization complete"
        # Print top findings to console
        echo -e "${MAGENTA}[AI ANALYSIS]${NC}"
        echo "$AI_RESP" | head -30
        echo ""
    else
        warning "[AI] No response from Claude API (check ANTHROPIC_API_KEY)"
    fi
}

_ai_false_positive_filter() {
    local AI_DIR="$1"

    log "[AI] Running false positive filter on findings..."

    local -a FINDING_FILES=(
        "$OUTDIR/advanced/injections/ssti_hits.txt"
        "$OUTDIR/advanced/websocket/auth_bypass.txt"
        "$OUTDIR/advanced/smuggling/cache_poison_hits.txt"
        "$OUTDIR/advanced/graphql/mutation_hits.txt"
    )

    for FFILE in "${FINDING_FILES[@]}"; do
        [ -s "$FFILE" ] || continue
        local FNAME
        FNAME=$(basename "$FFILE")

        local PROMPT="You are a security researcher reviewing automated scan findings for false positive filtering.

Findings file: $FNAME
Target: $DOMAIN

Raw findings:
$(cat "$FFILE" 2>/dev/null | head -30)

For each finding, answer:
- TRUE POSITIVE or FALSE POSITIVE
- Brief reason (1 line)
- Confidence level (High/Medium/Low)

Be strict — automated tools often produce false positives for SSTI, cache poisoning, and authentication bypass."

        local AI_RESP
        AI_RESP=$(_ai_call "$PROMPT" 1024)

        if [ -n "$AI_RESP" ]; then
            {
                echo "=== FP Filter: $FNAME ==="
                echo "$AI_RESP"
                echo ""
            } >> "$AI_DIR/false_positive_analysis.txt"
        fi
    done

    [ -s "$AI_DIR/false_positive_analysis.txt" ] && \
        success "[AI] False positive analysis written to $AI_DIR/false_positive_analysis.txt"
}

_ai_write_report_section() {
    local AI_DIR="$1"

    log "[AI] Generating executive summary..."

    local PHASE_STATS
    PHASE_STATS=$(cat <<EOF
Domain: $DOMAIN
Subdomains found: $(wc -l < "$OUTDIR/subdomains/all_subdomains.txt" 2>/dev/null || echo 0)
Alive hosts: $(wc -l < "$OUTDIR/alive/final_alive.txt" 2>/dev/null || echo 0)
Open ports: $(wc -l < "$OUTDIR/ports/open_ports.txt" 2>/dev/null || echo 0)
Parameters: $(wc -l < "$OUTDIR/urls/parameters.txt" 2>/dev/null || echo 0)
Critical vulns: $(grep -c "CRITICAL\|critical\|RCE\|SSRF\|SQLi\|XXE\|SSTI" "$OUTDIR/advanced/advanced_vulns.txt" 2>/dev/null || echo 0)
High vulns: $(wc -l < "$OUTDIR/advanced/injections/upload_hits.txt" 2>/dev/null || echo 0)
Exposed services: $(wc -l < "$OUTDIR/infrastructure/exposed_services.txt" 2>/dev/null || echo 0)
EOF
)

    local PROMPT="You are a senior security consultant writing an executive summary for a bug bounty report.

Statistics from automated scan of ${DOMAIN}:
${PHASE_STATS}

Top findings:
$(head -20 "$AI_DIR/findings_for_ai.txt" 2>/dev/null)

Write a professional executive summary (3-4 paragraphs) covering:
1. Overall security posture (1 paragraph)
2. Critical/high risk findings summary (1-2 paragraphs)
3. Recommended immediate remediation priorities (1 paragraph)

Tone: technical but readable by management. Do not use jargon without explanation."

    local AI_RESP
    AI_RESP=$(_ai_call "$PROMPT" 2048)

    if [ -n "$AI_RESP" ]; then
        {
            echo "=== EXECUTIVE SUMMARY (AI Generated) ==="
            echo "Target: $DOMAIN | Date: $(date)"
            echo ""
            echo "$AI_RESP"
        } > "$AI_DIR/executive_summary.txt"
        success "[AI] Executive summary written to $AI_DIR/executive_summary.txt"
    fi
}

_ai_poc_hints() {
    local AI_DIR="$1"

    [ -s "$AI_DIR/ai_prioritization.txt" ] || return
    log "[AI] Generating PoC hints for top findings..."

    local TOP_FINDINGS
    TOP_FINDINGS=$(head -50 "$AI_DIR/ai_prioritization.txt")

    local PROMPT="Given these prioritized findings for ${DOMAIN}:

${TOP_FINDINGS}

For the top 3 most critical findings, provide:
1. Step-by-step manual verification steps (how to confirm it's real)
2. What HTTP request/response to capture as evidence
3. Suggested CVSS score and vector string
4. Bug bounty report title suggestion

Format as: Finding N: [name] | CVSS: X.X | Steps: ..."

    local AI_RESP
    AI_RESP=$(_ai_call "$PROMPT" 1024)

    if [ -n "$AI_RESP" ]; then
        {
            echo "=== PoC HINTS (AI Generated) ==="
            echo "$AI_RESP"
        } > "$AI_DIR/poc_hints.txt"
        success "[AI] PoC hints written to $AI_DIR/poc_hints.txt"
    fi
}

phase_21_ai_analysis() {
    if phase_done "phase_21"; then return 0; fi
    [ "$AI_ANALYSIS_ENABLED" -ne 1 ] && [ "$AI_MODE" -ne 1 ] && {
        info "AI analysis disabled — skipping phase 21 (set AI_ANALYSIS_ENABLED=1 + ANTHROPIC_API_KEY)"
        return
    }
    [ -z "$ANTHROPIC_API_KEY" ] && {
        warning "ANTHROPIC_API_KEY not set — skipping AI analysis"
        return
    }
    phase_banner "PHASE 21: AI-POWERED ANALYSIS (CLAUDE API)"

    local START_TIME
    START_TIME=$(date +%s)
    local AI_DIR="$OUTDIR/ai_analysis"
    mkdir -p "$AI_DIR"

    _ai_summarize_findings "$AI_DIR"
    _ai_prioritize_vulns "$AI_DIR"
    _ai_false_positive_filter "$AI_DIR"
    _ai_write_report_section "$AI_DIR"
    _ai_poc_hints "$AI_DIR"

    local FILES_CREATED
    FILES_CREATED=$(ls "$AI_DIR"/*.txt 2>/dev/null | wc -l)

    success "PHASE 21 DONE — AI analysis files: $FILES_CREATED | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 21: AI Analysis done — executive summary + prioritization + PoC hints generated" "🤖"
    mark_done "phase_21"
    echo ""
}
