#======================= PHASE 5: API DISCOVERY =======================
phase_5_api_discovery() {
    if phase_done "phase_5"; then return 0; fi
    phase_banner "PHASE 5: API ENDPOINT DISCOVERY"

    local START_TIME=$(date +%s)
    local API_DIR="$OUTDIR/api"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"
    local URL_FILE="$OUTDIR/urls/all_urls.txt"

    [ ! -s "$ALIVE_FILE" ] && { error "No alive hosts!"; return; }
    mkdir -p "$API_DIR/noisy_skipped"

    # Common API paths
    log "[5.1] Probing common API paths..."
    cat > "$API_DIR/api_paths.txt" << 'EOF'
/api
/api/v1
/api/v2
/api/v3
/api/swagger
/api/swagger.json
/api/swagger.yaml
/api/openapi.json
/api/openapi.yaml
/api/docs
/swagger
/swagger.json
/swagger.yaml
/swagger/index.html
/swagger-ui.html
/swagger-ui
/openapi
/openapi.json
/openapi.yaml
/api-docs
/api-docs.json
/v1/swagger.json
/v2/swagger.json
/graphql
/graphiql
/graphql/playground
/graphql/console
/playground
/api/graphql
/__graphql
/altair
/voyager
/api/health
/api/status
/health
/healthz
/status
/metrics
/info
/env
/debug
/config
/admin/api
/api/admin
/api/user
/api/users
/api/me
/api/profile
/api/login
/api/auth
/api/token
/api/keys
/api/webhook
/api/webhooks
/api/export
/api/import
/api/upload
/api/download
/api/search
/api/query
/rest
/rest/v1
/rest/v2
/service
/services
/.well-known/openapi.json
/postman
/postman.json
EOF

    if should_skip_noisy_phase "Phase 5 active API fuzzing"; then
        : > "$API_DIR/noisy_skipped/api_ffuf.txt"
        : > "$API_DIR/api_found.txt"
    else
        head -20 "$ALIVE_FILE" | while IFS= read -r URL; do
            local SAFE
            # Sanitize all URL special chars so the filename is glob-safe
            SAFE=$(printf '%s' "$URL" | sed 's|https\?://||;s|[/?=&#]|_|g')
            network_run ffuf -w "$API_DIR/api_paths.txt":FUZZ \
                -u "$URL/FUZZ" \
                -mc 200,201,204,401,403,429 \
                -rate "$FFUF_RATE" \
                -o "$API_DIR/api_ffuf_${SAFE}.json" \
                -of json \
                -s 2>>"$OUTDIR/logs/errors.log" || true
        done

        : > "$API_DIR/api_found.txt"
        for FFUF_JSON in "$API_DIR"/api_ffuf_*.json; do
            [ -f "$FFUF_JSON" ] || continue
            jq -r '.results[]?.url // empty' "$FFUF_JSON" 2>/dev/null >> "$API_DIR/api_found.txt" || true
        done
        sort -u "$API_DIR/api_found.txt" -o "$API_DIR/api_found.txt"
    fi

    # GraphQL introspection
    log "[5.2] Testing GraphQL introspection..."
    if [ -s "$URL_FILE" ]; then
        grep -iE "graphql|graphiql|playground" "$URL_FILE" | sort -u > "$API_DIR/graphql_endpoints.txt" || :
    else
        : > "$API_DIR/graphql_endpoints.txt"
        warning "No URL inventory found for GraphQL introspection checks"
    fi

    while IFS= read -r GQL; do
        local RESULT
        RESULT=$(curl_safe -X POST \
            -H "Content-Type: application/json" \
            -d '{"query":"{__schema{types{name}}}"}' \
            "$GQL" 2>/dev/null || :)
        if echo "$RESULT" | grep -q "__schema"; then
            echo "$GQL - INTROSPECTION ENABLED" >> "$API_DIR/graphql_introspection.txt"
            vuln "GraphQL introspection enabled: $GQL"
            notify_vuln "medium" "GraphQL introspection: $GQL"
        fi
    done < "$API_DIR/graphql_endpoints.txt"

    # Nuclei API templates
    log "[5.3] Nuclei API/exposure templates..."
    network_run nuclei -l "$ALIVE_FILE" \
        -t "$NUCLEI_TEMPLATES/exposures/apis/" \
        -t "$NUCLEI_TEMPLATES/exposed-panels/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -o "$API_DIR/nuclei_api.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log" || true

    cooldown_if_waf_pressure
    success "PHASE 5 DONE - APIs found: $(wc -l < "$API_DIR/api_found.txt" 2>/dev/null || echo 0) | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 5: API discovery done" "API"
    echo ""
}
