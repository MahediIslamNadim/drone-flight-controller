#======================= PHASE 21: AI-POWERED ANALYSIS =======================
# Multi-provider: set AI_PROVIDER in config/env to switch between backends.
#
#   AI_PROVIDER=codex       — ChatGPT Plus via ~/.codex/auth.json (no API key)
#                             run `codex login` once to authenticate
#   AI_PROVIDER=openrouter  — OpenRouter API (set OPENROUTER_API_KEY + OPENROUTER_MODEL)
#
# Models:
#   Codex:      CODEX_MODEL="gpt-5.4-mini"  (or gpt-5.4-pro / gpt-5.5-pro)
#   OpenRouter: OPENROUTER_MODEL="anthropic/claude-haiku-4-5"  (or any openrouter.ai/models)

_CODEX_AUTH_FILE="$HOME/.codex/auth.json"
_CODEX_CLIENT_ID="app_EMoamEEZ73f0CkXaXp7hrann"
_CODEX_VERSION="0.128.0"

#── PROVIDER: CODEX ──────────────────────────────────────────────────────────

# Returns a valid access_token; auto-refreshes if JWT is expired.
_codex_get_token() {
    [ ! -f "$_CODEX_AUTH_FILE" ] && return 1

    local ACCESS REFRESH NOW EXP NEW_TOKEN RESP
    ACCESS=$(python3 -c "
import json
try:
    d=json.load(open('$_CODEX_AUTH_FILE'))
    print(d.get('tokens',{}).get('access_token',''))
except: pass
" 2>/dev/null)
    [ -z "$ACCESS" ] && return 1

    NOW=$(date +%s)
    EXP=$(python3 -c "
import json, base64
t='$ACCESS'
parts=t.split('.')
if len(parts)!=3: exit(1)
pad=(4-len(parts[1])%4)%4
try:
    payload=base64.b64decode(parts[1]+'='*pad).decode()
    print(json.loads(payload).get('exp',0))
except: print(0)
" 2>/dev/null)

    if [ -n "$EXP" ] && [ "$EXP" -gt $((NOW + 60)) ]; then
        echo "$ACCESS"; return 0
    fi

    # Expired — attempt refresh
    REFRESH=$(python3 -c "
import json
try:
    d=json.load(open('$_CODEX_AUTH_FILE'))
    print(d.get('tokens',{}).get('refresh_token',''))
except: pass
" 2>/dev/null)
    [ -z "$REFRESH" ] && return 1

    RESP=$(curl_api -X POST "https://auth.openai.com/oauth/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "User-Agent: openclaw/$_CODEX_VERSION" \
        -H "originator: openclaw" \
        --data-urlencode "grant_type=refresh_token" \
        --data-urlencode "client_id=$_CODEX_CLIENT_ID" \
        --data-urlencode "refresh_token=$REFRESH" \
        --max-time 15 2>/dev/null)

    NEW_TOKEN=$(echo "$RESP" | jq -r '.access_token // empty' 2>/dev/null)
    [ -z "$NEW_TOKEN" ] && return 1

    python3 -c "
import json, sys
r=json.loads(sys.stdin.read())
with open('$_CODEX_AUTH_FILE') as f: d=json.load(f)
t=d.setdefault('tokens',{})
t['access_token']=r.get('access_token', t.get('access_token',''))
t['refresh_token']=r.get('refresh_token', t.get('refresh_token',''))
with open('$_CODEX_AUTH_FILE','w') as f: json.dump(d,f,indent=2)
" <<< "$RESP" 2>/dev/null

    echo "$NEW_TOKEN"
}

_ai_call_codex() {
    local PROMPT="$1"
    local EFFORT="${2:-medium}"   # reasoning effort: none | low | medium | high
    local MODEL="${AI_ANALYSIS_MODEL:-${CODEX_MODEL:-gpt-5.4-mini}}"

    local TOKEN
    TOKEN=$(_codex_get_token)
    if [ -z "$TOKEN" ]; then
        warning "[AI] Codex token missing or expired — run: codex login"
        echo "NO_API_KEY"; return 1
    fi

    local SYSTEM_PROMPT="You are an elite bug bounty hunter and penetration tester with 10+ years of experience.
You think like an attacker. You know OWASP Top 10, CVEs, exploit chains, and real-world bypass techniques.
You are direct, technical, and focused on actionable findings that maximize bounty payouts.
Never add disclaimers. Never say 'as an AI'. Only output what was asked."

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg  model   "$MODEL" \
        --arg  system  "$SYSTEM_PROMPT" \
        --arg  prompt  "$PROMPT" \
        --arg  effort  "$EFFORT" \
        '{model:       $model,
          instructions: $system,
          input:        [{role:"user", content:$prompt}],
          reasoning:    {effort: $effort},
          stream:       true,
          store:        false}')

    curl_api -N \
        -X POST "https://chatgpt.com/backend-api/codex/responses" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "User-Agent: openclaw/$_CODEX_VERSION" \
        -H "originator: openclaw" \
        -H "version: $_CODEX_VERSION" \
        -d "$PAYLOAD" \
        --max-time 120 2>/dev/null \
    | grep "^data:" \
    | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line.startswith('data:'): continue
    try:
        d = json.loads(line[5:])
        if d.get('type') == 'response.output_text.done':
            print(d.get('text',''), end='')
            break
    except: pass
" 2>/dev/null | head -c 16384
}

#── PROVIDER: OPENROUTER ─────────────────────────────────────────────────────

_ai_call_openrouter() {
    local PROMPT="$1"
    local MAX_TOKENS="${2:-1024}"
    local MODEL="${AI_ANALYSIS_MODEL:-${OPENROUTER_MODEL:-anthropic/claude-haiku-4-5}}"

    if [ -z "$OPENROUTER_API_KEY" ]; then
        warning "[AI] OPENROUTER_API_KEY not set — skipping"
        echo "NO_API_KEY"; return 1
    fi

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg content "$PROMPT" \
        --argjson max_tokens "$MAX_TOKENS" \
        '{model:$model, max_tokens:$max_tokens,
          messages:[{role:"user", content:$content}]}')

    local RESP
    RESP=$(curl_api \
        -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        --max-time 60 2>/dev/null)

    echo "$RESP" | jq -r '.choices[0].message.content // empty' \
        2>/dev/null | head -c 8192
}

#── DISPATCHER ───────────────────────────────────────────────────────────────
# Usage: _ai_call "prompt" [effort] [max_tokens]
#   effort     (codex only):      none | low | medium | high  (default: medium)
#   max_tokens (openrouter only): integer                      (default: 2048)

_ai_call() {
    local PROMPT="$1"
    local EFFORT="${2:-medium}"
    local MAX_TOKENS="${3:-2048}"
    local PROVIDER="${AI_PROVIDER:-codex}"
    case "$PROVIDER" in
        codex)      _ai_call_codex      "$PROMPT" "$EFFORT" ;;
        openrouter) _ai_call_openrouter "$PROMPT" "$MAX_TOKENS" ;;
        *)
            warning "[AI] Unknown AI_PROVIDER='$PROVIDER' — valid: codex, openrouter"
            echo "NO_API_KEY"; return 1 ;;
    esac
}

# Returns 0 if the active provider is ready to use.
_ai_provider_ready() {
    local PROVIDER="${AI_PROVIDER:-codex}"
    case "$PROVIDER" in
        codex)      _codex_get_token > /dev/null 2>&1 ;;
        openrouter) [ -n "$OPENROUTER_API_KEY" ] ;;
        *)          return 1 ;;
    esac
}

#── SESSION MEMORY ────────────────────────────────────────────────────────────
# Gives AI continuity across steps: each step saves its key insight so later
# steps can reference "what we already know" without re-analysing from scratch.

_AI_MEM_DIR=""  # set by _ai_memory_init
_AI_HELPER=""   # path to Python JSON-extraction helper

_ai_memory_init() {
    _AI_MEM_DIR="$1/memory"
    mkdir -p "$_AI_MEM_DIR"
}

_ai_memory_save() {
    # _ai_memory_save KEY "plain text value"
    [ -n "$_AI_MEM_DIR" ] && printf '%s\n' "$2" > "$_AI_MEM_DIR/$1.txt"
}

_ai_memory_load() {
    [ -n "$_AI_MEM_DIR" ] && [ -f "$_AI_MEM_DIR/$1.txt" ] && \
        head -5 "$_AI_MEM_DIR/$1.txt"
}

# Returns a formatted prior-context block for prompt injection.
# Silent when no prior steps have saved anything yet (first call).
_ai_memory_context() {
    [ -z "$_AI_MEM_DIR" ] && return
    local FOUND=0 BLOCK
    BLOCK="PRIOR ANALYSIS CONTEXT (accumulated this session):"$'\n'
    for KEY in context prioritization fp_filter chains; do
        local F="$_AI_MEM_DIR/${KEY}.txt"
        [ -s "$F" ] || continue
        BLOCK="${BLOCK}  [${KEY}] $(head -2 "$F" | tr '\n' ' ')"$'\n'
        FOUND=1
    done
    [ "$FOUND" -eq 1 ] && printf '%s\n' "$BLOCK"
}

#── JSON HELPER SETUP ─────────────────────────────────────────────────────────
# Writes a small Python script that extracts valid JSON from AI responses,
# handling markdown code fences and leading/trailing prose.

_ai_setup_helpers() {
    local AI_DIR="$1"
    _AI_HELPER="$AI_DIR/ai_json_extract.py"
    cat > "$_AI_HELPER" << 'PYEOF'
#!/usr/bin/env python3
import json, sys, re

def extract_json(text):
    candidates = [text]
    # Strip markdown code fences
    s = re.sub(r'```(?:json)?\s*', '', text)
    s = re.sub(r'\s*```', '', s)
    candidates.append(s)
    # Grab outermost { ... } block
    m = re.search(r'(\{[\s\S]*\})', text)
    if m:
        candidates.append(m.group(1))
    for c in candidates:
        try:
            return json.loads(c.strip())
        except Exception:
            continue
    return None

raw = sys.stdin.read()
obj = extract_json(raw)
if obj:
    print(json.dumps(obj, indent=2))
    sys.exit(0)
else:
    print(raw, end='', file=sys.stderr)
    sys.exit(1)
PYEOF
    chmod +x "$_AI_HELPER"
}

#── JSON-AWARE AI CALL ────────────────────────────────────────────────────────
# Calls _ai_call, then validates/extracts JSON from the response.
# Returns 0 + valid JSON on success; returns 1 + raw text on fallback.
_ai_call_json() {
    local PROMPT="$1"
    local EFFORT="${2:-medium}"
    local MAX_TOKENS="${3:-4096}"

    local RAW
    RAW=$(_ai_call "$PROMPT" "$EFFORT" "$MAX_TOKENS")
    [ -z "$RAW" ] || [ "$RAW" = "NO_API_KEY" ] && { echo "$RAW"; return 1; }

    local JSON_OUT
    if [ -n "$_AI_HELPER" ] && [ -f "$_AI_HELPER" ]; then
        JSON_OUT=$(echo "$RAW" | python3 "$_AI_HELPER" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$JSON_OUT" ]; then
            echo "$JSON_OUT"
            return 0
        fi
    fi

    warning "[AI] Response was not valid JSON — saving as plain text"
    echo "$RAW"
    return 1
}

#── CONTEXT BUILDER ──────────────────────────────────────────────────────────
_ai_build_target_context() {
    local AI_DIR="$1"
    {
        printf "TARGET: %s\nSCAN DATE: %s\n\n" "$DOMAIN" "$(date -u '+%Y-%m-%d %H:%M UTC')"
        printf "=== ATTACK SURFACE ===\nSubdomains: %s | Alive: %s | Open ports: %s | Parameters: %s\n\n" \
            "$(wc -l < "$OUTDIR/subdomains/all_subdomains.txt" 2>/dev/null || echo 0)" \
            "$(wc -l < "$OUTDIR/alive/final_alive.txt"         2>/dev/null || echo 0)" \
            "$(wc -l < "$OUTDIR/ports/open_ports.txt"          2>/dev/null || echo 0)" \
            "$(wc -l < "$OUTDIR/urls/parameters.txt"           2>/dev/null || echo 0)"
        [ -s "$OUTDIR/technology/tech_stack.txt" ] && {
            printf "=== TECHNOLOGY STACK ===\n"; head -25 "$OUTDIR/technology/tech_stack.txt"; printf "\n"; }
        [ -s "$OUTDIR/waf/waf_detected.txt" ] && {
            printf "=== WAF / SECURITY CONTROLS ===\n"; cat "$OUTDIR/waf/waf_detected.txt"; printf "\n"; }
        [ -s "$OUTDIR/ports/open_ports.txt" ] && {
            printf "=== OPEN PORTS (top 30) ===\n"; head -30 "$OUTDIR/ports/open_ports.txt"; printf "\n"; }
        [ -s "$OUTDIR/network_recon/asns.txt" ] && {
            printf "=== ASN / NETWORK OWNERSHIP ===\n"; head -10 "$OUTDIR/network_recon/asns.txt"; printf "\n"; }
        [ -s "$OUTDIR/cve_correlation/nvd_matches.txt" ] && {
            printf "=== CVE CORRELATION ===\n"; head -20 "$OUTDIR/cve_correlation/nvd_matches.txt"; printf "\n"; }
        { [ -s "$OUTDIR/repos/secret_hits_gitleaks.jsonl" ] || [ -s "$OUTDIR/urls/trufflehog.jsonl" ]; } && {
            printf "=== LEAKED SECRETS ===\n"
            [ -s "$OUTDIR/repos/secret_hits_gitleaks.jsonl" ] && \
                jq -r '.RuleID + ": " + (.Secret // .Match // "")' "$OUTDIR/repos/secret_hits_gitleaks.jsonl" 2>/dev/null | head -10
            [ -s "$OUTDIR/urls/trufflehog.jsonl" ] && \
                jq -r '.DetectorName + ": " + (.Raw // "")' "$OUTDIR/urls/trufflehog.jsonl" 2>/dev/null | head -10
            printf "\n"; }
        [ -s "$OUTDIR/cloud/all_open.txt" ] && {
            printf "=== CLOUD BUCKET EXPOSURE ===\n"
            grep "200-OPEN" "$OUTDIR/cloud/all_open.txt" 2>/dev/null | head -10; printf "\n"; }
    } > "$AI_DIR/target_context.txt"

    # Save compact summary to session memory for subsequent AI steps
    local _SUBS _ALIVE _PARAMS _TECH _WAF
    _SUBS=$(wc -l < "$OUTDIR/subdomains/all_subdomains.txt" 2>/dev/null || echo 0)
    _ALIVE=$(wc -l < "$OUTDIR/alive/final_alive.txt"         2>/dev/null || echo 0)
    _PARAMS=$(wc -l < "$OUTDIR/urls/parameters.txt"          2>/dev/null || echo 0)
    _TECH=$(awk -F'—' 'NR<=3{printf "%s,",$2}' "$OUTDIR/technology/tech_stack.txt" 2>/dev/null | \
            sed 's/,$//' | head -c 100)
    _WAF=$(grep -m1 "detected\|protected" "$OUTDIR/waf/waf_detected.txt" 2>/dev/null | \
           head -c 80 || echo "none detected")
    _ai_memory_save "context" \
        "Target: $DOMAIN | Subdomains: $_SUBS | Alive: $_ALIVE | Params: $_PARAMS | Tech: ${_TECH:-unknown} | WAF: $_WAF"
}

#── FINDINGS AGGREGATOR ───────────────────────────────────────────────────────
_ai_summarize_findings() {
    local AI_DIR="$1"
    log "[AI] Aggregating all scan findings..."
    local F="$AI_DIR/findings_for_ai.txt"
    : > "$F"
    local TOTAL=0 CAT_COUNT=0

    _add_vuln_section() {
        local LABEL="$1" FILE="$2" MAX="${3:-15}"
        [ -s "$FILE" ] || return
        local N; N=$(wc -l < "$FILE" 2>/dev/null || echo 0)
        { printf "=== %s (%s findings) ===\n" "$LABEL" "$N"
          head -"$MAX" "$FILE"; printf "\n"; } >> "$F"
        TOTAL=$((TOTAL + N)); CAT_COUNT=$((CAT_COUNT + 1))
    }

    _add_vuln_section "Nuclei Critical/High"       "$OUTDIR/vulns/nuclei_critical.txt"                 25
    _add_vuln_section "Subdomain Takeover"          "$OUTDIR/takeover/takeover_hits.txt"
    _add_vuln_section "SSTI Injection"              "$OUTDIR/advanced/injections/ssti_hits.txt"
    _add_vuln_section "XXE Injection"               "$OUTDIR/advanced/injections/xxe_hits.txt"
    _add_vuln_section "File Upload / RCE"           "$OUTDIR/advanced/injections/upload_hits.txt"
    _add_vuln_section "HTTP Request Smuggling"      "$OUTDIR/advanced/smuggling/smuggling_candidates.txt"
    _add_vuln_section "Cache Poisoning"             "$OUTDIR/advanced/smuggling/cache_poison_hits.txt"
    _add_vuln_section "GraphQL Mutations"           "$OUTDIR/advanced/graphql/mutation_hits.txt"
    _add_vuln_section "GraphQL IDOR"                "$OUTDIR/advanced/graphql/idor_hits.txt"
    _add_vuln_section "WebSocket Auth Bypass"       "$OUTDIR/advanced/websocket/auth_bypass.txt"
    _add_vuln_section "CSRF / CSWSH"                "$OUTDIR/advanced/websocket/cswsh_hits.txt"
    _add_vuln_section "OOB Callbacks (SSRF/XXE)"    "$OUTDIR/oob/callback_summary.txt"
    _add_vuln_section "XSS"                         "$OUTDIR/vulns/xss_hits.txt"
    _add_vuln_section "SQL Injection"               "$OUTDIR/vulns/sqli_hits.txt"
    _add_vuln_section "LFI / RFI"                   "$OUTDIR/vulns/lfi_hits.txt"
    _add_vuln_section "Open Redirect"               "$OUTDIR/vulns/open_redirect_hits.txt"
    _add_vuln_section "Prototype Pollution"         "$OUTDIR/vulns/prototype_hits.txt"
    _add_vuln_section "Host Header Injection"       "$OUTDIR/vulns/hostheader_hits.txt"
    _add_vuln_section "403 Bypass"                  "$OUTDIR/bypass/403_bypassed.txt"
    _add_vuln_section "SSRF"                        "$OUTDIR/injections/ssrf.txt"
    _add_vuln_section "Exposed Services"            "$OUTDIR/infrastructure/exposed_services.txt"
    _add_vuln_section "K8s / Container Exposure"    "$OUTDIR/infrastructure/k8s_exposure.txt"
    _add_vuln_section "Docker API Exposure"         "$OUTDIR/infrastructure/docker_exposure.txt"
    _add_vuln_section "Origin IP Disclosure"        "$OUTDIR/network_recon/origin_ip_hits.txt"
    _add_vuln_section "Leaked Secrets (gitleaks)"   "$OUTDIR/repos/secret_hits_gitleaks.jsonl"
    _add_vuln_section "Leaked Secrets (trufflehog)" "$OUTDIR/urls/trufflehog.jsonl"

    if [ "$TOTAL" -eq 0 ]; then
        info "[AI] No findings to analyze"; return 1
    fi
    success "[AI] $TOTAL finding lines across $CAT_COUNT categories collected"
    return 0
}

#── VULNERABILITY PRIORITIZATION ─────────────────────────────────────────────
_ai_prioritize_vulns() {
    local AI_DIR="$1"
    [ -s "$AI_DIR/findings_for_ai.txt" ] || return

    log "[AI] Prioritizing vulnerabilities (effort: medium)..."

    local CTX=""
    [ -s "$AI_DIR/target_context.txt" ] && CTX=$(head -60 "$AI_DIR/target_context.txt")

    # Inject session memory so AI builds on prior context
    local MEM_CTX
    MEM_CTX=$(_ai_memory_context)

    local SCHEMA
    SCHEMA='{"target":"string","generated":"ISO-8601 datetime","findings":[{"rank":1,"title":"string","type":"string","affected":"string","cvss_score":9.0,"cvss_vector":"AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H","severity":"Critical","exploitability":"Easy","exploitability_reason":"string","business_impact":"string","chained":false,"chain_detail":"string or null","confidence":"High","confidence_reason":"string","bounty_range":"$X-$Y"}],"analysis_summary":"string"}'

    local PROMPT
    PROMPT="You are an elite bug bounty hunter with 10+ years of experience reviewing automated scan output.

TARGET CONTEXT:
${CTX}

${MEM_CTX}RAW FINDINGS:
$(head -300 "$AI_DIR/findings_for_ai.txt")

TASK: Analyze all findings and produce a ranked vulnerability report for the top 8 findings.
Assess CVSS 3.1 scores accurately. Identify which findings chain with others for higher impact.
Focus on real-world exploitability and business consequences that maximize bug bounty payouts.

OUTPUT FORMAT: Respond with ONLY valid JSON matching this schema — no markdown fences, no prose before or after:
${SCHEMA}"

    local AI_RESP IS_JSON
    AI_RESP=$(_ai_call_json "$PROMPT" "medium" "4096")
    IS_JSON=$?

    if [ -z "$AI_RESP" ] || [ "$AI_RESP" = "NO_API_KEY" ]; then
        warning "[AI] No prioritization response — check provider credentials"
        return
    fi

    if [ "$IS_JSON" -eq 0 ]; then
        # Save machine-readable JSON
        echo "$AI_RESP" > "$AI_DIR/ai_prioritization.json"

        # Generate human-readable text from JSON
        python3 - "$AI_DIR/ai_prioritization.json" \
            > "$AI_DIR/ai_prioritization.txt" 2>/dev/null << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
print("=== AI VULNERABILITY PRIORITIZATION ===")
print(f"Target: {d.get('target','')}  |  Generated: {d.get('generated','')}\n")
for f in d.get('findings', []):
    print("---FINDING---")
    print(f"RANK: {f.get('rank')}  |  SEVERITY: {f.get('severity')}  |  CVSS: {f.get('cvss_score')}")
    print(f"TITLE: {f.get('title')}")
    print(f"TYPE: {f.get('type')}  |  AFFECTED: {f.get('affected')}")
    print(f"CVSS_VECTOR: {f.get('cvss_vector')}")
    print(f"EXPLOITABILITY: {f.get('exploitability')} — {f.get('exploitability_reason')}")
    print(f"BUSINESS_IMPACT: {f.get('business_impact')}")
    chained = f.get('chained', False)
    chain_detail = f.get('chain_detail') or ''
    print(f"CHAINED: {'yes — ' + chain_detail if chained else 'no'}")
    print(f"CONFIDENCE: {f.get('confidence')} — {f.get('confidence_reason')}")
    print(f"BOUNTY_RANGE: {f.get('bounty_range')}")
    print("---END---\n")
s = d.get('analysis_summary', '')
if s:
    print(f"ANALYSIS_SUMMARY: {s}")
PYEOF
        success "[AI] Prioritization → JSON + text ($AI_DIR)"
    else
        # Fallback: text-only output
        { echo "=== AI VULNERABILITY PRIORITIZATION ==="
          printf "Target: %s  |  Generated: %s\n\n" "$DOMAIN" "$(date)"
          echo "$AI_RESP"; } > "$AI_DIR/ai_prioritization.txt"
        success "[AI] Prioritization → $AI_DIR/ai_prioritization.txt (text mode)"
    fi

    # Save top finding summary to session memory
    local MEM_LINE=""
    if [ "$IS_JSON" -eq 0 ] && [ -f "$AI_DIR/ai_prioritization.json" ]; then
        MEM_LINE=$(python3 -c "
import json
d = json.load(open('$AI_DIR/ai_prioritization.json'))
f = d.get('findings', [{}])[0]
s = d.get('analysis_summary', '')[:180]
print(f\"Top: {f.get('title','?')} (CVSS {f.get('cvss_score','?')}, {f.get('severity','?')}). {s}\")
" 2>/dev/null)
    else
        MEM_LINE=$(grep "^TITLE:" "$AI_DIR/ai_prioritization.txt" 2>/dev/null | head -1)
    fi
    [ -n "$MEM_LINE" ] && _ai_memory_save "prioritization" "$MEM_LINE"

    echo -e "${MAGENTA}[AI TOP FINDINGS]${NC}"
    head -35 "$AI_DIR/ai_prioritization.txt"
    echo ""
}

#── FALSE POSITIVE FILTER ─────────────────────────────────────────────────────
_ai_false_positive_filter() {
    local AI_DIR="$1"
    log "[AI] Running false-positive triage (effort: low)..."
    local FP_FILE="$AI_DIR/false_positive_analysis.txt"
    : > "$FP_FILE"

    local -a FP_TARGETS=(
        "SSTI Injection|$OUTDIR/advanced/injections/ssti_hits.txt"
        "Cache Poisoning|$OUTDIR/advanced/smuggling/cache_poison_hits.txt"
        "WebSocket Auth Bypass|$OUTDIR/advanced/websocket/auth_bypass.txt"
        "GraphQL Mutations|$OUTDIR/advanced/graphql/mutation_hits.txt"
        "Host Header Injection|$OUTDIR/vulns/hostheader_hits.txt"
        "Prototype Pollution|$OUTDIR/vulns/prototype_hits.txt"
        "OOB Callbacks|$OUTDIR/oob/callback_summary.txt"
    )

    for ENTRY in "${FP_TARGETS[@]}"; do
        local LABEL="${ENTRY%%|*}"
        local FILE="${ENTRY##*|}"
        [ -s "$FILE" ] || continue

        local PROMPT
        PROMPT="You are a security researcher triaging automated scan output for false positives.

Scan type: $LABEL
Target: $DOMAIN
Raw findings (first 25 lines):
$(head -25 "$FILE")

For each finding line output EXACTLY:
LINE_N | TRUE_POSITIVE or FALSE_POSITIVE | High/Med/Low confidence | one-line reason

Then:
VERDICT: [X] TP, [Y] FP
FP_PATTERN: [main false positive pattern observed, or none]"

        local AI_RESP
        AI_RESP=$(_ai_call "$PROMPT" "low" "1024")

        [ -n "$AI_RESP" ] && {
            printf "=== FP TRIAGE: %s ===\n%s\n\n" "$LABEL" "$AI_RESP" >> "$FP_FILE"
        }
    done

    if [ -s "$FP_FILE" ]; then
        success "[AI] FP analysis → $FP_FILE"
        # Save verdict summary to session memory
        local TP_CNT FP_CNT
        TP_CNT=$(grep -c "TRUE_POSITIVE" "$FP_FILE" 2>/dev/null); TP_CNT=$(( ${TP_CNT:-0} + 0 ))
        FP_CNT=$(grep -c "FALSE_POSITIVE" "$FP_FILE" 2>/dev/null); FP_CNT=$(( ${FP_CNT:-0} + 0 ))
        _ai_memory_save "fp_filter" \
            "FP triage complete: $TP_CNT confirmed true positives, $FP_CNT false positives across ${#FP_TARGETS[@]} finding categories"
    fi
}

#── ATTACK CHAIN ANALYSIS ─────────────────────────────────────────────────────
_ai_attack_chains() {
    local AI_DIR="$1"
    [ -s "$AI_DIR/ai_prioritization.txt" ] || return

    log "[AI] Mapping multi-vulnerability attack chains (effort: high)..."

    local CTX=""
    [ -s "$AI_DIR/target_context.txt" ] && CTX=$(cat "$AI_DIR/target_context.txt")

    # Pull in session memory so AI knows FP triage results, top finding, etc.
    local MEM_CTX
    MEM_CTX=$(_ai_memory_context)

    local SCHEMA
    SCHEMA='{"chains":[{"name":"string","severity":"Critical|High|Medium","vulns_combined":["string"],"risk_category":"string","scenario":["step1 string","step2 string","step3 string"],"attacker_requirement":"Unauthenticated|Authenticated user|Specific role","likelihood":"High|Medium|Low","likelihood_reason":"string","combined_cvss":9.8,"report_value":"$X-$Y"}],"chains_summary":"string"}'

    local PROMPT
    PROMPT="You are a senior penetration tester writing the compound risk section of an authorized security engagement report.

TARGET CONTEXT:
${CTX}

${MEM_CTX}VULNERABILITIES FOUND (authorized assessment):
$(head -200 "$AI_DIR/ai_prioritization.txt")

TASK: For each pair or group of findings that compound each other's risk, document the combined scenario. This helps the client understand which findings to remediate together to break dangerous combinations.

Common compound risk patterns:
- SSRF + cloud metadata = cloud credential exposure
- Open redirect + OAuth flow = token interception
- HTTP smuggling + auth endpoint = session confusion
- XXE + internal SSRF = internal service enumeration
- Subdomain takeover + shared cookie domain = session exposure
- File upload + web-accessible path = remote code execution
- GraphQL IDOR + mass assignment = unauthorized privilege change
- Cache poisoning + reflected parameter = persistent content injection
- Leaked credential + exposed management port = direct infra access

OUTPUT FORMAT: Respond with ONLY valid JSON matching this schema — no markdown fences, no prose:
${SCHEMA}"

    local AI_RESP IS_JSON
    AI_RESP=$(_ai_call_json "$PROMPT" "high" "5000")
    IS_JSON=$?

    if [ -z "$AI_RESP" ] || [ "$AI_RESP" = "NO_API_KEY" ]; then
        warning "[AI] No attack chain response"
        return
    fi

    if [ "$IS_JSON" -eq 0 ]; then
        echo "$AI_RESP" > "$AI_DIR/attack_chains.json"

        # Generate human-readable text from JSON
        python3 - "$AI_DIR/attack_chains.json" \
            > "$AI_DIR/attack_chains.txt" 2>/dev/null << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
print("=== AI ATTACK CHAIN ANALYSIS ===\n")
for c in d.get('chains', []):
    print(f"---CHAIN---")
    print(f"NAME: {c.get('name')}")
    print(f"SEVERITY: {c.get('severity')}  |  COMBINED_CVSS: {c.get('combined_cvss')}")
    print(f"VULNS_COMBINED: {', '.join(c.get('vulns_combined',[]))}")
    print(f"RISK_CATEGORY: {c.get('risk_category')}")
    print("SCENARIO:")
    for i, step in enumerate(c.get('scenario', []), 1):
        print(f"  {i}. {step}")
    print(f"ATTACKER_REQUIREMENT: {c.get('attacker_requirement')}")
    print(f"LIKELIHOOD: {c.get('likelihood')} — {c.get('likelihood_reason')}")
    print(f"REPORT_VALUE: {c.get('report_value')}")
    print("---END---\n")
s = d.get('chains_summary', '')
if s:
    print(f"CHAINS_SUMMARY: {s}")
PYEOF
        success "[AI] Attack chains → JSON + text ($AI_DIR)"
    else
        { echo "=== AI ATTACK CHAIN ANALYSIS ==="
          printf "Target: %s  |  Generated: %s\n\n" "$DOMAIN" "$(date)"
          echo "$AI_RESP"; } > "$AI_DIR/attack_chains.txt"
        success "[AI] Attack chains → $AI_DIR/attack_chains.txt (text mode)"
    fi

    # Save chain summary to session memory
    local CHAIN_MEM=""
    if [ "$IS_JSON" -eq 0 ] && [ -f "$AI_DIR/attack_chains.json" ]; then
        CHAIN_MEM=$(python3 -c "
import json
d = json.load(open('$AI_DIR/attack_chains.json'))
n = len(d.get('chains', []))
top = d.get('chains',[{}])[0].get('name','?') if n>0 else 'none'
s = d.get('chains_summary','')[:180]
print(f'{n} chains identified. Highest-risk: {top}. {s}')
" 2>/dev/null)
    else
        CHAIN_MEM=$(grep "^CHAINS_SUMMARY:" "$AI_DIR/attack_chains.txt" 2>/dev/null | head -1)
    fi
    [ -n "$CHAIN_MEM" ] && _ai_memory_save "chains" "$CHAIN_MEM"

    echo -e "${MAGENTA}[AI ATTACK CHAINS]${NC}"
    head -35 "$AI_DIR/attack_chains.txt"
    echo ""
}

#── EXECUTIVE SUMMARY ─────────────────────────────────────────────────────────
_ai_write_report_section() {
    local AI_DIR="$1"
    log "[AI] Writing executive summary (effort: medium)..."

    local CTX=""
    [ -s "$AI_DIR/target_context.txt" ] && CTX=$(cat "$AI_DIR/target_context.txt")
    local CHAINS=""
    [ -s "$AI_DIR/attack_chains.txt" ] && \
        CHAINS=$(grep -A 50 "CHAINS_SUMMARY" "$AI_DIR/attack_chains.txt" 2>/dev/null | head -20)

    # Inject full session memory — exec summary should reflect everything we know
    local MEM_CTX
    MEM_CTX=$(_ai_memory_context)

    local PROMPT
    PROMPT="You are a senior security consultant writing the executive summary of a professional penetration test report.

TARGET CONTEXT:
${CTX}

${MEM_CTX}TOP VULNERABILITIES (prioritized):
$(head -100 "$AI_DIR/ai_prioritization.txt" 2>/dev/null)

ATTACK CHAINS IDENTIFIED:
${CHAINS}

Write a professional executive summary (400-600 words) with these FOUR sections in markdown:

## Overall Security Posture
[2-3 sentences: overall risk rating with justification, compared to industry baseline]

## Critical Findings
[Bullet list of top 5 findings: name + one-line business impact + severity label]

## Most Dangerous Attack Scenario
[2-3 sentences: the highest-impact chain, what a real attacker would do with it]

## Immediate Remediation Priorities
[Numbered list of top 5 actions in priority order. Each: action + estimated effort label: Quick Win, 1 week, or 1 month]

Tone: authoritative, technical but business-readable. No hedging. Write as if this will be read by a CISO."

    local AI_RESP
    AI_RESP=$(_ai_call "$PROMPT" "medium" "3000")

    [ -n "$AI_RESP" ] && {
        {
            echo "=== EXECUTIVE SUMMARY (AI Generated) ==="
            printf "Target: %s  |  Date: %s\n\n" "$DOMAIN" "$(date)"
            echo "$AI_RESP"
        } > "$AI_DIR/executive_summary.txt"
        success "[AI] Executive summary → $AI_DIR/executive_summary.txt"
    }
}

#── FULL H1/BUGCROWD REPORT ───────────────────────────────────────────────────
_ai_generate_report() {
    local AI_DIR="$1"
    [ -s "$AI_DIR/ai_prioritization.txt" ] || return
    log "[AI] Generating HackerOne-style report for top finding (effort: high)..."

    local TOP_FINDING
    TOP_FINDING=$(awk '/^---FINDING---/{p=1} p{print} /^---END---/{p=0; exit}' \
        "$AI_DIR/ai_prioritization.txt" 2>/dev/null)
    [ -z "$TOP_FINDING" ] && TOP_FINDING=$(head -60 "$AI_DIR/ai_prioritization.txt")

    local CTX=""
    [ -s "$AI_DIR/target_context.txt" ] && CTX=$(head -40 "$AI_DIR/target_context.txt")

    local PROMPT
    PROMPT="You are a top-ranked HackerOne researcher writing a vulnerability report to maximize triage acceptance and bounty payout.

TARGET CONTEXT:
${CTX}

VULNERABILITY TO REPORT:
${TOP_FINDING}

Generate a complete HackerOne/Bugcrowd submission in markdown. Use this exact structure:

# [Concise impact-focused title]

**Severity:** [Critical/High/Medium/Low]
**CVSS 3.1:** [score] ([vector string])
**Type:** [CWE-XXX: Name]
**Asset:** [affected URL or host]

## Summary
[2-3 sentences: what the bug is, how it was found, what an attacker achieves]

## Description
[Technical deep-dive: root cause, affected component, exploit conditions. 3-4 paragraphs. Be specific about the technology stack.]

## Steps to Reproduce
1. [Exact step — include endpoint, method, parameters]
2. [Modification made — exact payload or header value]
3. [What to observe in the response that confirms the vulnerability]

## Proof of Concept
(Provide the exact minimal curl command or raw HTTP request that reproduces the issue, including all required headers and the payload)

Expected response: [what a vulnerable response looks like — status code, header, or body content]

## Impact
[2-3 sentences: specific data or access at risk, affected user population, business consequences. Be concrete and specific.]

## Remediation
[Specific fix — configuration change, code pattern, or library update. Not generic advice.]

## References
[Real CVEs or CWEs only — format: CVE-XXXX-XXXX or CWE-XXX]

Write as if a real researcher found this through careful manual testing. Be specific and technical."

    local AI_RESP
    AI_RESP=$(_ai_call "$PROMPT" "high" "5000")

    if [ -n "$AI_RESP" ] && [ "$AI_RESP" != "NO_API_KEY" ]; then
        echo "$AI_RESP" > "$AI_DIR/h1_report_draft.md"
        success "[AI] H1 report draft → $AI_DIR/h1_report_draft.md"
    fi
}

#── POC VERIFICATION GUIDE ────────────────────────────────────────────────────
_ai_poc_hints() {
    local AI_DIR="$1"
    [ -s "$AI_DIR/ai_prioritization.txt" ] || return
    log "[AI] Generating PoC verification guide (effort: medium)..."

    local CTX=""
    [ -s "$AI_DIR/target_context.txt" ] && CTX=$(head -40 "$AI_DIR/target_context.txt")

    # Full session memory — PoC guide should know FP results and chain context
    local MEM_CTX
    MEM_CTX=$(_ai_memory_context)

    local SCHEMA
    SCHEMA='{"pocs":[{"rank":1,"finding":"string","cvss_score":9.0,"cvss_vector":"AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H","h1_title":"string","verification_steps":["step1","step2","step3"],"minimal_poc":"curl -X POST https://example.com/api -H ... -d ...","evidence_to_capture":"string","triage_notes":"string","impact_statement":"string"}]}'

    local PROMPT
    PROMPT="You are a bug bounty hunter preparing to manually verify and document the top vulnerabilities before submission.

TARGET CONTEXT:
${CTX}

${MEM_CTX}PRIORITIZED VULNERABILITIES:
$(head -120 "$AI_DIR/ai_prioritization.txt")

TASK: For the top 3 ranked true-positive findings (skip any flagged as false-positive in the session context), provide a detailed PoC verification guide.
For each finding: give exact reproduction steps, a minimal curl PoC, what evidence to screenshot for the report, and how to distinguish this from a scanner false positive.

OUTPUT FORMAT: Respond with ONLY valid JSON matching this schema — no markdown fences, no prose:
${SCHEMA}"

    local AI_RESP IS_JSON
    AI_RESP=$(_ai_call_json "$PROMPT" "medium" "4000")
    IS_JSON=$?

    if [ -z "$AI_RESP" ] || [ "$AI_RESP" = "NO_API_KEY" ]; then
        warning "[AI] No PoC hints response"
        return
    fi

    if [ "$IS_JSON" -eq 0 ]; then
        echo "$AI_RESP" > "$AI_DIR/poc_hints.json"

        # Generate human-readable text from JSON
        python3 - "$AI_DIR/poc_hints.json" \
            > "$AI_DIR/poc_hints.txt" 2>/dev/null << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
print("=== PoC VERIFICATION GUIDE (AI Generated) ===\n")
for p in d.get('pocs', []):
    print(f"---POC {p.get('rank')}---")
    print(f"FINDING: {p.get('finding')}")
    print(f"CVSS: {p.get('cvss_score')}  |  VECTOR: {p.get('cvss_vector')}")
    print(f"H1_TITLE: {p.get('h1_title')}\n")
    print("VERIFICATION_STEPS:")
    for i, step in enumerate(p.get('verification_steps', []), 1):
        print(f"  {i}. {step}")
    print(f"\nMINIMAL_POC:\n{p.get('minimal_poc','')}")
    print(f"\nEVIDENCE_TO_CAPTURE:\n{p.get('evidence_to_capture','')}")
    print(f"\nTRIAGE_NOTES:\n{p.get('triage_notes','')}")
    print(f"\nIMPACT_STATEMENT:\n{p.get('impact_statement','')}")
    print("---END_POC---\n")
PYEOF
        success "[AI] PoC hints → JSON + text ($AI_DIR)"
    else
        { echo "=== PoC VERIFICATION GUIDE (AI Generated) ==="
          printf "Target: %s  |  Generated: %s\n\n" "$DOMAIN" "$(date)"
          echo "$AI_RESP"; } > "$AI_DIR/poc_hints.txt"
        success "[AI] PoC hints → $AI_DIR/poc_hints.txt (text mode)"
    fi
}

#── PHASE ORCHESTRATOR ────────────────────────────────────────────────────────
phase_21_ai_analysis() {
    if phase_done "phase_21"; then return 0; fi
    [ "${AI_ANALYSIS_ENABLED:-0}" -ne 1 ] && [ "${AI_MODE:-0}" -ne 1 ] && {
        info "AI analysis disabled — skipping phase 21 (use --ai or set AI_ANALYSIS_ENABLED=1)"
        return
    }
    if ! _ai_provider_ready; then
        case "${AI_PROVIDER:-codex}" in
            codex)      warning "Codex token not found or expired — run: codex login" ;;
            openrouter) warning "OPENROUTER_API_KEY not set — add it to .env" ;;
            *)          warning "Unknown AI_PROVIDER='${AI_PROVIDER:-codex}'" ;;
        esac
        return
    fi

    local MODEL_LABEL="${AI_ANALYSIS_MODEL:-${CODEX_MODEL:-${OPENROUTER_MODEL:-default}}}"
    phase_banner "PHASE 21: AI-POWERED ANALYSIS  [provider: ${AI_PROVIDER:-codex}  model: $MODEL_LABEL]"

    local START_TIME; START_TIME=$(date +%s)
    local AI_DIR="$OUTDIR/ai_analysis"
    mkdir -p "$AI_DIR"

    # Initialise session memory + JSON helper before any analysis step
    _ai_memory_init   "$AI_DIR"
    _ai_setup_helpers "$AI_DIR"

    _ai_build_target_context  "$AI_DIR"
    _ai_summarize_findings     "$AI_DIR" || { mark_done "phase_21"; return; }
    _ai_prioritize_vulns       "$AI_DIR"
    _ai_false_positive_filter  "$AI_DIR"
    _ai_attack_chains          "$AI_DIR"
    _ai_write_report_section   "$AI_DIR"
    _ai_generate_report        "$AI_DIR"
    _ai_poc_hints              "$AI_DIR"

    local FILES_CREATED ELAPSED
    FILES_CREATED=$(find "$AI_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
    ELAPSED=$(( $(date +%s) - START_TIME ))

    success "PHASE 21 DONE — AI analysis files: $FILES_CREATED | Time: ${ELAPSED}s"
    info "Output directory: $AI_DIR/"
    while IFS= read -r _F; do
        printf "  %-42s  %d lines\n" "$(basename "$_F")" "$(wc -l < "$_F")"
    done < <(find "$AI_DIR" -maxdepth 1 \( -name "*.txt" -o -name "*.md" \) 2>/dev/null | sort)

    notify "Phase 21 complete — $FILES_CREATED AI analysis files in $AI_DIR" "🤖"
    mark_done "phase_21"
    echo ""
}
