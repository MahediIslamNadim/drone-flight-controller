#======================= DEEP JAVASCRIPT ANALYSIS =======================
resolve_source_url() {
    local BASE_URL="$1"
    local REF="$2"

    if [ -z "$REF" ]; then
        return
    fi

    if [[ "$REF" =~ ^https?:// ]]; then
        echo "$REF"
        return
    fi

    if [[ "$REF" == data:* ]]; then
        return
    fi

    local SCHEME="${BASE_URL%%://*}"
    local REST="${BASE_URL#*://}"
    local HOST="${REST%%/*}"
    local ROOT="${SCHEME}://${HOST}"
    local CLEAN_BASE="${BASE_URL%%\?*}"

    if [[ "$REF" == //* ]]; then
        echo "${SCHEME}:$REF"
    elif [[ "$REF" == /* ]]; then
        echo "${ROOT}${REF}"
    else
        local BASE_DIR="${CLEAN_BASE%/*}"
        echo "${BASE_DIR}/${REF}"
    fi
}

sanitize_source_path() {
    local SRC="$1"

    SRC="${SRC#webpack:///}"
    SRC="${SRC#webpack://}"
    SRC="${SRC#file://}"
    SRC="${SRC#/}"
    SRC="${SRC//../_}"
    SRC="${SRC//:/_}"
    SRC="${SRC%%\?*}"
    SRC="${SRC%%#*}"

    if [ -z "$SRC" ]; then
        SRC="unknown_source.js"
    fi

    echo "$SRC"
}

safe_asset_name() {
    printf '%s\n' "$1" | sed 's|https\?://||; s|[^a-zA-Z0-9._-]|_|g'
}

fetch_source_map_candidates() {
    local URL_DIR="$1"
    local JS_FILE="$URL_DIR/js_files.txt"
    local MAP_DIR="$URL_DIR/sourcemaps"
    local TMP_JS="$URL_DIR/tmp_js_fetch.txt"

    mkdir -p "$MAP_DIR/raw" "$MAP_DIR/extracted"
    : > "$MAP_DIR/sourcemap_urls.txt"

    if [ ! -s "$JS_FILE" ]; then
        return
    fi

    log "[4.7] Discovering source maps..."
    head -100 "$JS_FILE" | while IFS= read -r JSURL; do
        local DEFAULT_MAP="${JSURL%%\?*}.map"
        echo "$DEFAULT_MAP" >> "$MAP_DIR/sourcemap_urls.txt"

        if curl_safe -o "$TMP_JS" "$JSURL" 2>/dev/null; then
            local SOURCE_MAP_REF
            SOURCE_MAP_REF=$(grep -oE 'sourceMappingURL=[^[:space:]]+' "$TMP_JS" | tail -1 | cut -d'=' -f2- | sed "s/[\"'].*$//; s#\\*/$##")
            if [ -n "$SOURCE_MAP_REF" ]; then
                resolve_source_url "$JSURL" "$SOURCE_MAP_REF" >> "$MAP_DIR/sourcemap_urls.txt"
            fi
        fi
    done

    sort -u "$MAP_DIR/sourcemap_urls.txt" -o "$MAP_DIR/sourcemap_urls.txt"
    rm -f "$TMP_JS"
    success "Source map candidates: $(wc -l < "$MAP_DIR/sourcemap_urls.txt" 2>/dev/null || echo 0)"
}

unpack_source_maps() {
    local URL_DIR="$1"
    local MAP_DIR="$URL_DIR/sourcemaps"

    if [ ! -s "$MAP_DIR/sourcemap_urls.txt" ]; then
        return
    fi

    log "[4.8] Downloading and unpacking source maps..."
    : > "$MAP_DIR/valid_sourcemaps.txt"
    : > "$MAP_DIR/source_files.txt"

    while IFS= read -r MAP_URL; do
        local MAP_NAME
        MAP_NAME=$(safe_asset_name "$MAP_URL")
        local RAW_MAP="$MAP_DIR/raw/${MAP_NAME}.map"
        local EXTRACT_DIR="$MAP_DIR/extracted/$MAP_NAME"

        mkdir -p "$EXTRACT_DIR"

        if ! curl_safe -o "$RAW_MAP" "$MAP_URL" 2>/dev/null; then
            rm -f "$RAW_MAP"
            continue
        fi

        if ! jq -e '.sources or .sourcesContent' "$RAW_MAP" >/dev/null 2>&1; then
            rm -f "$RAW_MAP"
            continue
        fi

        echo "$MAP_URL" >> "$MAP_DIR/valid_sourcemaps.txt"

        jq -r '.sources[]?' "$RAW_MAP" 2>/dev/null >> "$MAP_DIR/source_files.txt"

        jq -r '.sources | to_entries[] | [.key, .value] | @tsv' "$RAW_MAP" 2>/dev/null | while IFS=$'\t' read -r IDX SRC; do
            local SAFE_SRC
            SAFE_SRC=$(sanitize_source_path "$SRC")
            local OUT_FILE="$EXTRACT_DIR/$SAFE_SRC"
            mkdir -p "$(dirname "$OUT_FILE")"

            jq -r --argjson idx "$IDX" '.sourcesContent[$idx] // empty' "$RAW_MAP" 2>/dev/null > "$OUT_FILE"
            if [ ! -s "$OUT_FILE" ]; then
                rm -f "$OUT_FILE"
            fi
        done
    done < "$MAP_DIR/sourcemap_urls.txt"

    if [ -f "$MAP_DIR/source_files.txt" ]; then
        sort -u "$MAP_DIR/source_files.txt" -o "$MAP_DIR/source_files.txt"
    fi
    if [ -f "$MAP_DIR/valid_sourcemaps.txt" ]; then
        sort -u "$MAP_DIR/valid_sourcemaps.txt" -o "$MAP_DIR/valid_sourcemaps.txt"
    fi

    local MAP_COUNT=$(wc -l < "$MAP_DIR/valid_sourcemaps.txt" 2>/dev/null || echo 0)
    [ "$MAP_COUNT" -gt 0 ] && notify_vuln "medium" "Source maps exposed: $MAP_COUNT assets on $DOMAIN"
    success "Valid source maps: $MAP_COUNT"
}

scan_unpacked_sources() {
    local URL_DIR="$1"
    local MAP_DIR="$URL_DIR/sourcemaps"
    local EXTRACT_ROOT="$MAP_DIR/extracted"

    if [ ! -d "$EXTRACT_ROOT" ]; then
        return
    fi

    log "[4.9] Analyzing unpacked JavaScript sources..."

    grep -RhoE "https?://[^[:space:]\"'<>)]+" "$EXTRACT_ROOT" 2>/dev/null > "$MAP_DIR/absolute_urls.txt" || :
    grep -RhoE "/(api|graphql|graphiql|auth|oauth|internal|admin|v[0-9]+)[A-Za-z0-9._~!$&'()*+,;=:@%/?-]*" "$EXTRACT_ROOT" 2>/dev/null > "$MAP_DIR/relative_endpoints.txt" || :

    cat "$MAP_DIR/absolute_urls.txt" "$MAP_DIR/relative_endpoints.txt" 2>/dev/null | \
        grep -vE "\.map($|\?)" | sort -u > "$URL_DIR/sourcemap_endpoints.txt"

    grep -RInE "(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|secret[_-]?key|aws_access_key_id|aws_secret_access_key|authorization|bearer[[:space:]]+[A-Za-z0-9._-]+|BEGIN[[:space:]]+(RSA[[:space:]]+)?PRIVATE[[:space:]]+KEY|password[[:space:]]*[:=])" "$EXTRACT_ROOT" 2>/dev/null | \
        sort -u > "$URL_DIR/sourcemap_credentials_hits.txt" || :

    if [ -s "$URL_DIR/sourcemap_endpoints.txt" ]; then
        cat "$URL_DIR/endpoints.txt" "$URL_DIR/sourcemap_endpoints.txt" 2>/dev/null | sort -u > "$URL_DIR/endpoints_merged.txt"
        mv "$URL_DIR/endpoints_merged.txt" "$URL_DIR/endpoints.txt"
    fi

    local EXTRACTED_COUNT
    EXTRACTED_COUNT=$(find "$EXTRACT_ROOT" -type f 2>/dev/null | wc -l)
    local ENDPOINT_COUNT
    ENDPOINT_COUNT=$(wc -l < "$URL_DIR/sourcemap_endpoints.txt" 2>/dev/null || echo 0)
    local CREDS_COUNT
    CREDS_COUNT=$(wc -l < "$URL_DIR/sourcemap_credentials_hits.txt" 2>/dev/null || echo 0)

    [ "$ENDPOINT_COUNT" -gt 0 ] && notify "Deep JS: $ENDPOINT_COUNT endpoints extracted from source maps" "🧠"
    [ "$CREDS_COUNT" -gt 0 ] && notify_vuln "high" "Deep JS: $CREDS_COUNT credential hits in unpacked sources"
    success "Unpacked JS sources: $EXTRACTED_COUNT | Endpoints: $ENDPOINT_COUNT | Credential hits: $CREDS_COUNT"
}
