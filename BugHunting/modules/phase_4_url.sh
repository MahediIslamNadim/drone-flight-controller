#======================= PHASE 4: URL & CONTENT DISCOVERY =======================
phase_4_url_discovery() {
    if phase_done "phase_4"; then return 0; fi
    phase_banner "PHASE 4: URL & CONTENT DISCOVERY"

    local START_TIME
    START_TIME=$(date +%s)
    local URL_DIR="$OUTDIR/urls"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    [ ! -s "$ALIVE_FILE" ] && { error "No alive hosts!"; return; }

    local PIDS=()
    mkdir -p "$URL_DIR/noisy_skipped"

    # Strip protocol/path for tools that expect bare domains
    local DOMAINS_FILE="$URL_DIR/domains_only.txt"
    sed 's|https\?://||;s|/.*||' "$ALIVE_FILE" | sort -u > "$DOMAINS_FILE"

    # ── Waymore (deep archive collection — supersedes gau+wayback individually) ──
    log "[4.1] Waymore (deep archive URL collection)..."
    if command -v waymore &>/dev/null; then
        (network_run waymore \
            -i "$DOMAIN" \
            -mode U \
            -oU "$URL_DIR/waymore.txt" \
            --timeout 30 \
            2>>"$OUTDIR/logs/errors.log" || : > "$URL_DIR/waymore.txt") &
        PIDS+=($!)
    else
        : > "$URL_DIR/waymore.txt"
        log "[4.1] waymore not found — falling back to waybackurls + gau"
    fi

    # ── Waybackurls (fallback / supplement) ──
    log "[4.2] Waybackurls..."
    if command -v waybackurls &>/dev/null; then
        (network_run waybackurls < "$DOMAINS_FILE" > "$URL_DIR/wayback.txt" \
            2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        : > "$URL_DIR/wayback.txt"
    fi

    # ── GAU ──
    log "[4.3] GAU (GetAllUrls)..."
    if command -v gau &>/dev/null; then
        (network_run gau --subs < "$DOMAINS_FILE" > "$URL_DIR/gau.txt" \
            2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        : > "$URL_DIR/gau.txt"
    fi

    # ── Katana (upgraded: passive mode, jsluice, known-files, deeper depth) ──
    log "[4.4] Katana crawler (JS parsing, depth 5)..."
    if command -v katana &>/dev/null; then
        (network_run katana -list "$ALIVE_FILE" \
            -js-crawl \
            -known-files all \
            -depth 5 \
            -field-scope rdn \
            -concurrency "$THREADS" \
            -timeout "$TIMEOUT" \
            -retry 2 \
            -o "$URL_DIR/katana.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        : > "$URL_DIR/katana.txt"
        warning "[4.4] katana not found — skipping"
    fi

    # ── Hakrawler ──
    log "[4.5] Hakrawler..."
    if command -v hakrawler &>/dev/null; then
        (network_run hakrawler -subs -u < "$ALIVE_FILE" > "$URL_DIR/hakrawler.txt" \
            2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        : > "$URL_DIR/hakrawler.txt"
    fi

    # ── Cariddi (crawler + secret finder combined) ──
    log "[4.6] Cariddi (crawler + inline secret finder)..."
    if command -v cariddi &>/dev/null; then
        (head -20 "$ALIVE_FILE" | while IFS= read -r URL; do
            network_run cariddi \
                -s \
                -e \
                -ef 3 \
                -info \
                -err \
                -target "$URL" \
                2>>"$OUTDIR/logs/errors.log" | \
                grep -E "^https?" >> "$URL_DIR/cariddi.txt" || true
        done) &
        PIDS+=($!)
    else
        : > "$URL_DIR/cariddi.txt"
    fi

    # Wait for all crawlers
    for pid in "${PIDS[@]}"; do wait "$pid" 2>/dev/null || true; done
    success "All crawlers complete"

    # ── Directory fuzzing on top hosts ──
    log "[4.7] Directory fuzzing with ffuf..."
    if should_skip_noisy_phase "Phase 4 directory fuzzing"; then
        : > "$URL_DIR/noisy_skipped/ffuf.txt"
    else
        head -10 "$ALIVE_FILE" | while IFS= read -r URL; do
            local SAFE_NAME
            SAFE_NAME=$(printf '%s' "$URL" | sed 's|https\?://||;s|[/?=&#]|_|g')
            network_run ffuf -w "$WORDLIST_DIR":FUZZ \
                -u "$URL/FUZZ" \
                -mc 200,201,204,301,302,307,403,405,429 \
                -rate "$FFUF_RATE" \
                -o "$URL_DIR/ffuf_${SAFE_NAME}.json" \
                -of json \
                -s 2>>"$OUTDIR/logs/errors.log" || true
        done
    fi

    # Extract ffuf discoveries
    : > "$URL_DIR/ffuf_urls.txt"
    for FFUF_JSON in "$URL_DIR"/ffuf_*.json; do
        [ -f "$FFUF_JSON" ] || continue
        jq -r '.results[]?.url // empty' "$FFUF_JSON" 2>/dev/null >> "$URL_DIR/ffuf_urls.txt" || true
    done
    [ -s "$URL_DIR/ffuf_urls.txt" ] && \
        success "ffuf URLs: $(wc -l < "$URL_DIR/ffuf_urls.txt")"

    # ── Arjun — hidden parameter discovery ──
    log "[4.8] Arjun — hidden parameter discovery..."
    if command -v arjun &>/dev/null; then
        # Build a deduplicated endpoint list (no params) for arjun
        {
            cat "$URL_DIR/wayback.txt" "$URL_DIR/gau.txt" "$URL_DIR/waymore.txt" \
                "$URL_DIR/katana.txt" "$URL_DIR/hakrawler.txt" 2>/dev/null
        } | grep -E "^https?" | sed 's/?.*//' | sort -u | head -200 > "$URL_DIR/arjun_targets.txt"

        if [ -s "$URL_DIR/arjun_targets.txt" ]; then
            local ARJUN_DELAY=""
            if [ "$WAF_AWARE" -eq 1 ] && [ -s "$OUTDIR/alive/waf_detected.txt" ]; then
                ARJUN_DELAY="--delay 2000"
                info "[4.8] WAF detected — arjun running with --stable --delay 2000"
            fi
            network_run arjun \
                -i "$URL_DIR/arjun_targets.txt" \
                -oJ "$URL_DIR/arjun.json" \
                -t "$THREADS" \
                --stable \
                -q \
                $ARJUN_DELAY \
                2>>"$OUTDIR/logs/errors.log" || true
            # Extract discovered param URLs
            jq -r 'to_entries[] | .key as $url | .value.params[]? | "\($url)?\(.)=FUZZ"' \
                "$URL_DIR/arjun.json" 2>/dev/null | \
                sort -u >> "$URL_DIR/parameters.txt" || true
            success "Arjun: $(jq -r 'to_entries | length' "$URL_DIR/arjun.json" 2>/dev/null || echo 0) endpoints with hidden params"
        fi
    else
        warning "[4.8] arjun not found — skipping hidden parameter discovery"
    fi

    # ── JS file extraction ──
    {
        cat "$URL_DIR/waymore.txt"   2>/dev/null
        cat "$URL_DIR/wayback.txt"   2>/dev/null
        cat "$URL_DIR/gau.txt"       2>/dev/null
        cat "$URL_DIR/katana.txt"    2>/dev/null
        cat "$URL_DIR/hakrawler.txt" 2>/dev/null
        cat "$URL_DIR/cariddi.txt"   2>/dev/null
        cat "$URL_DIR/ffuf_urls.txt" 2>/dev/null
    } | grep -E "\.js(\?|$)" | grep -v "\.json" | sort -u > "$URL_DIR/js_files.txt" || :
    success "JS files: $(wc -l < "$URL_DIR/js_files.txt" 2>/dev/null)"

    # ── Secret scanning in JS files ──
    log "[4.9] Scanning JS for secrets (nuclei)..."
    if [ -s "$URL_DIR/js_files.txt" ]; then
        network_run nuclei -l "$URL_DIR/js_files.txt" \
            -t "$NUCLEI_TEMPLATES/exposures/" \
            -t "$NUCLEI_TEMPLATES/token-spray/" \
            -c "$NUCLEI_CONCURRENCY" \
            -rate-limit "$NUCLEI_RATE_LIMIT" \
            -o "$URL_DIR/js_secrets_nuclei.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log"
    fi

    if command -v trufflehog &>/dev/null; then
        log "[4.10] TruffleHog secret scan on downloaded JS..."
        local TH_TMP="$URL_DIR/trufflehog_tmp"
        mkdir -p "$TH_TMP"
        while IFS= read -r JSURL; do
            local SAFE_HASH
            SAFE_HASH=$(printf '%s' "$JSURL" | md5sum | cut -d' ' -f1)
            local TMP_JS="$TH_TMP/${SAFE_HASH}.js"
            if curl_safe -o "$TMP_JS" "$JSURL" 2>/dev/null && [ -s "$TMP_JS" ]; then
                network_run trufflehog filesystem "$TMP_JS" --json \
                    >> "$URL_DIR/trufflehog.jsonl" 2>/dev/null || true
            fi
            rm -f "$TMP_JS"
        done < <(head -50 "$URL_DIR/js_files.txt" 2>/dev/null)
        rm -rf "$TH_TMP"
    fi

    fetch_source_map_candidates "$URL_DIR"
    unpack_source_maps "$URL_DIR"

    # ── Merge all URLs ──
    {
        cat "$URL_DIR/waymore.txt"   2>/dev/null
        cat "$URL_DIR/wayback.txt"   2>/dev/null
        cat "$URL_DIR/gau.txt"       2>/dev/null
        cat "$URL_DIR/katana.txt"    2>/dev/null
        cat "$URL_DIR/hakrawler.txt" 2>/dev/null
        cat "$URL_DIR/cariddi.txt"   2>/dev/null
        cat "$URL_DIR/ffuf_urls.txt" 2>/dev/null
        cat "$URL_DIR/js_files.txt"  2>/dev/null
    } | grep -E "^https?" | sort -u > "$URL_DIR/all_urls.txt" || :

    # Extract parameters (merge with arjun discoveries already appended above)
    grep "?" "$URL_DIR/all_urls.txt" | grep "=" | sort -u >> "$URL_DIR/parameters.txt" || :
    sort -u "$URL_DIR/parameters.txt" -o "$URL_DIR/parameters.txt" 2>/dev/null || :

    # Extract endpoints
    sed 's/?.*//' "$URL_DIR/all_urls.txt" | sort -u > "$URL_DIR/endpoints.txt"

    scan_unpacked_sources "$URL_DIR"
    cooldown_if_waf_pressure

    local URL_COUNT=$(wc -l < "$URL_DIR/all_urls.txt" 2>/dev/null)
    local PARAM_COUNT=$(wc -l < "$URL_DIR/parameters.txt" 2>/dev/null)
    success "PHASE 4 DONE — URLs: $URL_COUNT | Params: $PARAM_COUNT | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 4: $URL_COUNT URLs ($PARAM_COUNT with params)" "🔗"
    mark_done "phase_4"
    echo ""
}
