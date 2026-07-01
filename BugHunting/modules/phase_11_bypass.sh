#======================= PHASE 11: BYPASS TECHNIQUES =======================
phase_11_bypass() {
    if phase_done "phase_11"; then return 0; fi
    phase_banner "PHASE 11: 403/401 BYPASS + WAF EVASION + CORS + METHOD OVERRIDE"

    if [ "$RESPECTFUL_MODE" -eq 1 ] || [ "$WAF_AWARE" -eq 1 ]; then
        warning "Respectful/WAF-aware mode disables active bypass techniques in phase 11"
        return
    fi

    local START_TIME
    START_TIME=$(date +%s)
    local BYPASS_DIR="$OUTDIR/bypass"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local FORBIDDEN_FILE="$OUTDIR/alive/by_status/status_403.txt"
    local UNAUTH_FILE="$OUTDIR/alive/by_status/status_401.txt"

    : > "$BYPASS_DIR/403_bypassed.txt"
    : > "$BYPASS_DIR/cors_manual.txt"
    : > "$BYPASS_DIR/method_override.txt"
    : > "$BYPASS_DIR/http_smuggling_hints.txt"

    # ──────────────────────────────────────────────────────
    # [11.1] 403 BYPASS — HEADER-BASED
    # ──────────────────────────────────────────────────────
    if [ -s "$FORBIDDEN_FILE" ]; then
        log "[11.1] Testing 403 bypass — header injection..."

        local BYPASS_HEADERS=(
            "X-Original-URL"
            "X-Rewrite-URL"
            "X-Override-URL"
            "X-Forwarded-For"
            "X-Remote-IP"
            "X-Remote-Addr"
            "X-ProxyUser-Ip"
            "X-Client-IP"
            "X-Real-IP"
            "X-Host"
            "X-Forwarded-Host"
            "X-Custom-IP-Authorization"
            "Forwarded"
            "True-Client-IP"
            "CF-Connecting-IP"
        )
        local BYPASS_VALUES=(
            "127.0.0.1"
            "localhost"
            "::1"
            "0.0.0.0"
            "10.0.0.1"
            "192.168.1.1"
            "172.16.0.1"
        )

        local TOTAL_403
        TOTAL_403=$(wc -l < "$FORBIDDEN_FILE" 2>/dev/null || echo 0)
        local CHECKED_403=0

        while IFS= read -r URL; do
            CHECKED_403=$(( CHECKED_403 + 1 ))
            progress_bar "403-HDR" "$CHECKED_403" "$TOTAL_403"
            host_already_done "phase_11_403" "$URL" && continue

            local SCHEME="${URL%%://*}"
            local HOST_PATH="${URL#*://}"
            local HOST="${HOST_PATH%%/*}"
            local BASE_URL="${SCHEME}://${HOST}"
            local URL_PATH="/${HOST_PATH#*/}"
            [ "$HOST_PATH" = "$HOST" ] && URL_PATH="/"
            local PATH_TRIMMED="${URL_PATH#/}"

            # Test each header × value combination
            for HDR in "${BYPASS_HEADERS[@]}"; do
                for VAL in "${BYPASS_VALUES[@]}"; do
                    local HDR_STRING="$HDR: $VAL"
                    # Path headers get the URL path, IP headers get IP values
                    case "$HDR" in
                        X-Original-URL|X-Rewrite-URL|X-Override-URL)
                            HDR_STRING="$HDR: $URL_PATH"
                            ;;
                    esac
                    local STATUS
                    STATUS=$(curl_safe -o /dev/null -w "%{http_code}" \
                        -H "$HDR_STRING" "$URL" 2>/dev/null)
                    if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
                        echo "[${STATUS}-HDR-BYPASS] $URL | $HDR_STRING" >> "$BYPASS_DIR/403_bypassed.txt"
                        vuln "403 BYPASSED via header: $URL — $HDR_STRING"
                        notify_vuln "medium" "403 Bypass: $URL"
                        break 2
                    fi
                done
            done

            # ── Path manipulation variants ──
            local -a PATH_VARIANTS=(
                "/%2e/${PATH_TRIMMED}"
                "/${PATH_TRIMMED}/"
                "/${PATH_TRIMMED}/."
                "//${PATH_TRIMMED}//"
                "/${PATH_TRIMMED}%20"
                "/${PATH_TRIMMED}%09"
                "/${PATH_TRIMMED}?"
                "/${PATH_TRIMMED}#"
                "/${PATH_TRIMMED}..;/"
                "/${PATH_TRIMMED}/./"
                "/%2F${PATH_TRIMMED}"
                "/%252F${PATH_TRIMMED}"
                "/${PATH_TRIMMED^}"
                "/${PATH_TRIMMED^^}"
            )
            for PAD in "${PATH_VARIANTS[@]}"; do
                local STATUS2
                STATUS2=$(curl_safe -o /dev/null -w "%{http_code}" \
                    "${BASE_URL}${PAD}" 2>/dev/null)
                if [ "$STATUS2" = "200" ]; then
                    echo "[200-PATH-BYPASS] ${BASE_URL}${PAD}" >> "$BYPASS_DIR/403_bypassed.txt"
                    vuln "403 PATH BYPASS: ${BASE_URL}${PAD}"
                    notify_vuln "medium" "403 path bypass: ${BASE_URL}${PAD}"
                    break
                fi
            done

            mark_host_done "phase_11_403" "$URL"
        done < "$FORBIDDEN_FILE"
        echo ""
        success "403 header/path bypass: $(wc -l < "$BYPASS_DIR/403_bypassed.txt" 2>/dev/null || echo 0) found"
    fi

    # ──────────────────────────────────────────────────────
    # [11.2] HTTP METHOD OVERRIDE
    # ──────────────────────────────────────────────────────
    log "[11.2] Testing HTTP method override on 403/401 targets..."
    local TARGETS_FILE="$BYPASS_DIR/method_targets.txt"
    cat "$FORBIDDEN_FILE" "$UNAUTH_FILE" 2>/dev/null | sort -u > "$TARGETS_FILE"

    local OVERRIDE_METHODS=(GET POST PUT PATCH DELETE OPTIONS HEAD TRACE CONNECT)
    while IFS= read -r URL; do
        for METHOD in "${OVERRIDE_METHODS[@]}"; do
            local STATUS
            STATUS=$(curl_safe -o /dev/null -w "%{http_code}" \
                -H "X-HTTP-Method-Override: $METHOD" \
                -H "X-Method-Override: $METHOD" \
                -H "_method: $METHOD" \
                -X POST "$URL" 2>/dev/null)
            if [ "$STATUS" = "200" ] || [ "$STATUS" = "201" ]; then
                echo "[${STATUS}-METHOD-OVERRIDE] $URL | Override→$METHOD" >> "$BYPASS_DIR/method_override.txt"
                vuln "METHOD OVERRIDE: $URL via $METHOD"
                notify_vuln "medium" "Method override: $URL via $METHOD"
                break
            fi
        done
    done < <(head -30 "$TARGETS_FILE" 2>/dev/null)
    success "Method override: $(wc -l < "$BYPASS_DIR/method_override.txt" 2>/dev/null || echo 0) bypassed"

    # ──────────────────────────────────────────────────────
    # [11.3] CORS MISCONFIGURATION
    # ──────────────────────────────────────────────────────
    log "[11.3] CORS misconfiguration testing (evil.com origin)..."
    local EVIL_ORIGINS=(
        "https://evil.com"
        "https://attacker.com"
        "null"
        "https://${DOMAIN}.evil.com"
        "https://evil.${DOMAIN}"
        "https://evil${DOMAIN}"
        "https://not${DOMAIN}"
        "https://${DOMAIN%.*}.evil.com"
        "http://localhost"
        "https://127.0.0.1"
    )
    while IFS= read -r URL; do
        host_already_done "phase_11_cors" "$URL" && continue
        for ORIGIN in "${EVIL_ORIGINS[@]}"; do
            local RESP
            RESP=$(curl_safe -I \
                -H "Origin: $ORIGIN" \
                -H "Access-Control-Request-Method: GET" \
                "$URL" 2>/dev/null)
            local ACAO
            ACAO=$(echo "$RESP" | grep -i "access-control-allow-origin" | head -1)
            local ACAC
            ACAC=$(echo "$RESP" | grep -i "access-control-allow-credentials" | head -1)
            if echo "$ACAO" | grep -qi "$ORIGIN\|null\|\*"; then
                if echo "$ACAC" | grep -qi "true"; then
                    echo "[CORS-CRED] $URL | Origin: $ORIGIN | $ACAO" >> "$BYPASS_DIR/cors_manual.txt"
                    vuln "CORS+CRED (high): $URL allows $ORIGIN with credentials"
                    notify_vuln "high" "CORS with credentials: $URL"
                else
                    echo "[CORS-ACAO] $URL | Origin: $ORIGIN | $ACAO" >> "$BYPASS_DIR/cors_manual.txt"
                fi
            fi
        done
        mark_host_done "phase_11_cors" "$URL"
    done < <(head -40 "$ALIVE_FILE" 2>/dev/null)
    success "CORS: $(wc -l < "$BYPASS_DIR/cors_manual.txt" 2>/dev/null || echo 0) misconfigurations"

    # ──────────────────────────────────────────────────────
    # [11.4] HTTP REQUEST SMUGGLING HINTS
    # (Detect servers that may be vulnerable by checking response headers)
    # ──────────────────────────────────────────────────────
    log "[11.4] Detecting HTTP/1.1 desync indicators..."
    while IFS= read -r URL; do
        local HEADERS
        HEADERS=$(curl_safe -I --http1.1 "$URL" 2>/dev/null)
        # Proxy/load-balancer headers suggest a multi-tier stack
        if echo "$HEADERS" | grep -qi "via:\|x-cache:\|x-varnish:\|x-squid\|CF-RAY:\|x-amz-cf"; then
            echo "[MULTI-TIER] $URL" >> "$BYPASS_DIR/http_smuggling_hints.txt"
        fi
    done < <(head -20 "$ALIVE_FILE" 2>/dev/null)
    success "Smuggling hints: $(wc -l < "$BYPASS_DIR/http_smuggling_hints.txt" 2>/dev/null || echo 0) multi-tier targets"

    # ──────────────────────────────────────────────────────
    # [11.5] NUCLEI BYPASS + CORS TEMPLATES
    # ──────────────────────────────────────────────────────
    log "[11.5] Nuclei bypass/CORS/access-control templates..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/vulnerabilities/generic/cors*" \
        -t "$NUCLEI_TEMPLATES/misconfiguration/cors*" \
        -t "$NUCLEI_TEMPLATES/misconfiguration/http-missing-security-headers*" \
        -t "$NUCLEI_TEMPLATES/misconfiguration/clickjacking*" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -o "$BYPASS_DIR/nuclei_bypass.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    local TOTAL_BYPASS
    TOTAL_BYPASS=$(wc -l < "$BYPASS_DIR/403_bypassed.txt" 2>/dev/null || echo 0)
    local TOTAL_CORS
    TOTAL_CORS=$(wc -l < "$BYPASS_DIR/cors_manual.txt" 2>/dev/null || echo 0)

    success "PHASE 11 DONE — 403 bypasses: $TOTAL_BYPASS | CORS issues: $TOTAL_CORS | Time: $(( $(date +%s) - $START_TIME ))s"
    notify "Phase 11: Bypass done ($TOTAL_BYPASS bypasses, $TOTAL_CORS CORS)" "🔓"
    mark_done "phase_11"
    echo ""
}
