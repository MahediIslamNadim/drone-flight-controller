#======================= PHASE 4: URL & CONTENT DISCOVERY =======================
phase_4_url_discovery() {
    if phase_done "phase_4"; then return 0; fi
    phase_banner "PHASE 4: URL & CONTENT DISCOVERY"

    local START_TIME=$(date +%s)
    local URL_DIR="$OUTDIR/urls"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    [ ! -s "$ALIVE_FILE" ] && { error "No alive hosts!"; return; }

    local PIDS=()
    mkdir -p "$URL_DIR/noisy_skipped"

    # ── Parallel URL collection ──
    # waybackurls and gau expect bare domains (no protocol, no path)
    local DOMAINS_FILE="$URL_DIR/domains_only.txt"
    sed 's|https\?://||;s|/.*||' "$ALIVE_FILE" | sort -u > "$DOMAINS_FILE"

    log "[4.1] Waybackurls..."
    if command -v waybackurls &>/dev/null; then
        (network_run waybackurls < "$DOMAINS_FILE" > "$URL_DIR/wayback.txt" 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        warning "[4.1] waybackurls not found — skipping"
    fi

    log "[4.2] GAU (GetAllUrls)..."
    if command -v gau &>/dev/null; then
        (network_run gau --subs < "$DOMAINS_FILE" > "$URL_DIR/gau.txt" 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        warning "[4.2] gau not found — skipping"
    fi

    log "[4.3] Katana crawler (JS parsing)..."
    if command -v katana &>/dev/null; then
        (network_run katana -list "$ALIVE_FILE" \
            -js-crawl \
            -depth 3 \
            -concurrency "$THREADS" \
            -o "$URL_DIR/katana.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    else
        warning "[4.3] katana not found — skipping"
    fi

    log "[4.4] Hakrawler..."
    if command -v hakrawler &>/dev/null; then
        (network_run hakrawler -subs -u < "$ALIVE_FILE" > "$URL_DIR/hakrawler.txt" 2>>"$OUTDIR/logs/errors.log") &
        PIDS+=($!)
    fi

    # Wait for crawlers
    for pid in "${PIDS[@]}"; do wait "$pid" 2>/dev/null || true; done
    success "All crawlers complete"

    # ── Directory fuzzing on top hosts ──
    log "[4.5] Directory fuzzing with ffuf..."
    if should_skip_noisy_phase "Phase 4 directory fuzzing"; then
        : > "$URL_DIR/noisy_skipped/ffuf.txt"
    else
        head -10 "$ALIVE_FILE" | while IFS= read -r URL; do
            local SAFE_NAME
            # Sanitize all URL special chars so the filename is glob-safe
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

    # ── Extract ffuf discoveries into URL pool ──
    # ffuf writes JSON, not txt — pull found URLs out so they reach all_urls.txt
    : > "$URL_DIR/ffuf_urls.txt"
    for FFUF_JSON in "$URL_DIR"/ffuf_*.json; do
        [ -f "$FFUF_JSON" ] || continue
        jq -r '.results[]?.url // empty' "$FFUF_JSON" 2>/dev/null >> "$URL_DIR/ffuf_urls.txt" || true
    done
    [ -s "$URL_DIR/ffuf_urls.txt" ] && \
        success "ffuf extracted URLs: $(wc -l < "$URL_DIR/ffuf_urls.txt")"

    # ── JS extraction (explicit list — avoids glob pulling in non-URL files) ──
    {
        cat "$URL_DIR/wayback.txt"    2>/dev/null
        cat "$URL_DIR/gau.txt"        2>/dev/null
        cat "$URL_DIR/katana.txt"     2>/dev/null
        cat "$URL_DIR/hakrawler.txt"  2>/dev/null
        cat "$URL_DIR/ffuf_urls.txt"  2>/dev/null
    } | grep -E "\.js(\?|$)" | grep -v "\.json" | sort -u > "$URL_DIR/js_files.txt" || :
    success "JS files: $(wc -l < "$URL_DIR/js_files.txt" 2>/dev/null)"

    # ── Secret scanning in JS files ──
    log "[4.6] Scanning JS for secrets (nuclei)..."
    if [ -s "$URL_DIR/js_files.txt" ]; then
        network_run nuclei -l "$URL_DIR/js_files.txt" \
            -t "$NUCLEI_TEMPLATES/exposures/" \
            -t "$NUCLEI_TEMPLATES/token-spray/" \
            -c "$NUCLEI_CONCURRENCY" \
            -rate-limit "$NUCLEI_RATE_LIMIT" \
            -o "$URL_DIR/js_secrets_nuclei.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log"
    fi

    # Regex-based secret hunting — download JS files then scan with filesystem mode
    if command -v trufflehog &>/dev/null; then
        log "[4.7] TruffleHog secret scan (filesystem mode on downloaded JS)..."
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

    # ── Merge all URLs (explicit list — avoids glob contamination from JSON/secret files) ──
    {
        cat "$URL_DIR/wayback.txt"    2>/dev/null
        cat "$URL_DIR/gau.txt"        2>/dev/null
        cat "$URL_DIR/katana.txt"     2>/dev/null
        cat "$URL_DIR/hakrawler.txt"  2>/dev/null
        cat "$URL_DIR/ffuf_urls.txt"  2>/dev/null
        cat "$URL_DIR/js_files.txt"   2>/dev/null
    } | grep -E "^https?" | sort -u > "$URL_DIR/all_urls.txt" || :

    # Extract parameters
    grep "?" "$URL_DIR/all_urls.txt" | grep "=" | sort -u > "$URL_DIR/parameters.txt" || :

    # Extract endpoints (no params)
    sed 's/?.*//' "$URL_DIR/all_urls.txt" | sort -u > "$URL_DIR/endpoints.txt"

    scan_unpacked_sources "$URL_DIR"
    cooldown_if_waf_pressure

    local URL_COUNT=$(wc -l < "$URL_DIR/all_urls.txt" 2>/dev/null)
    local PARAM_COUNT=$(wc -l < "$URL_DIR/parameters.txt" 2>/dev/null)
    success "PHASE 4 DONE — URLs: $URL_COUNT | Params: $PARAM_COUNT | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 4: $URL_COUNT URLs ($PARAM_COUNT with params)" "🔗"
    echo ""
}
