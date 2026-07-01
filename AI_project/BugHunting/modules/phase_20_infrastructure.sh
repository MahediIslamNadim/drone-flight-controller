#======================= PHASE 20: INFRASTRUCTURE EXPOSURE =======================
# Exposed databases, K8s API, Docker Registry, Redis, MongoDB, Elasticsearch, etc.

_probe_database_ports() {
    local IP="$1"
    local INFRA_DIR="$2"

    for PORT in "${DB_PORTS[@]}"; do
        timeout 3 bash -c "echo >/dev/tcp/${IP}/${PORT}" 2>/dev/null && {
            echo "${IP}:${PORT}" >> "$INFRA_DIR/open_db_ports.txt"
            log "[DB] Open port: ${IP}:${PORT}"
        } || true
    done
}

_test_redis() {
    local IP="$1"
    local PORT="${2:-6379}"
    local INFRA_DIR="$3"

    local RESP
    RESP=$(printf '*1\r\n$4\r\nINFO\r\n' | timeout 5 nc -q 1 "$IP" "$PORT" 2>/dev/null | head -20)
    if echo "$RESP" | grep -q "redis_version"; then
        local VERSION
        VERSION=$(echo "$RESP" | grep "redis_version" | cut -d: -f2 | tr -d '\r')
        echo "REDIS EXPOSED: ${IP}:${PORT} (version: $VERSION)" >> "$INFRA_DIR/exposed_services.txt"
        vuln "EXPOSED REDIS: ${IP}:${PORT} — no auth required (v${VERSION})"
        notify_vuln "critical" "Exposed Redis: ${IP}:${PORT} — unauthenticated access to Redis server"
    fi
}

_test_mongodb() {
    local IP="$1"
    local PORT="${2:-27017}"
    local INFRA_DIR="$3"

    # MongoDB wire protocol: isMaster command
    local RESP
    RESP=$(curl_safe -sk "http://${IP}:${PORT}" --max-time 4 2>/dev/null | head -c 200)
    if echo "$RESP" | grep -qiE "mongodb|you are trying to access mongodb over http"; then
        echo "MONGODB HTTP EXPOSED: ${IP}:${PORT}" >> "$INFRA_DIR/exposed_services.txt"
        vuln "EXPOSED MONGODB: ${IP}:${PORT}"
        notify_vuln "critical" "Exposed MongoDB: ${IP}:${PORT} — accessible via HTTP"
    fi

    # Try mongo ping via TCP
    if timeout 3 bash -c "echo >/dev/tcp/${IP}/${PORT}" 2>/dev/null; then
        echo "MONGODB PORT OPEN: ${IP}:${PORT}" >> "$INFRA_DIR/open_db_ports.txt"
    fi
}

_test_elasticsearch() {
    local IP="$1"
    local PORT="${2:-9200}"
    local INFRA_DIR="$3"

    local RESP
    RESP=$(curl_safe -sk "http://${IP}:${PORT}" --max-time 6 2>/dev/null)
    if echo "$RESP" | jq -e '.name' &>/dev/null 2>/dev/null; then
        local ES_VER
        ES_VER=$(echo "$RESP" | jq -r '.version.number // "?"' 2>/dev/null)
        echo "ELASTICSEARCH EXPOSED: ${IP}:${PORT} (v${ES_VER})" >> "$INFRA_DIR/exposed_services.txt"
        vuln "EXPOSED ELASTICSEARCH: ${IP}:${PORT} — unauthenticated (v${ES_VER})"
        notify_vuln "critical" "Exposed Elasticsearch: ${IP}:${PORT} — no auth, version $ES_VER"

        # Dump indices
        curl_safe -sk "http://${IP}:${PORT}/_cat/indices?v" --max-time 8 2>/dev/null \
            >> "$INFRA_DIR/es_indices_${IP}.txt" || true
    fi
}

_test_memcached() {
    local IP="$1"
    local PORT="${2:-11211}"
    local INFRA_DIR="$3"

    local RESP
    RESP=$(printf 'stats\r\n' | timeout 4 nc -q 1 "$IP" "$PORT" 2>/dev/null | head -5)
    if echo "$RESP" | grep -q "STAT"; then
        echo "MEMCACHED EXPOSED: ${IP}:${PORT}" >> "$INFRA_DIR/exposed_services.txt"
        vuln "EXPOSED MEMCACHED: ${IP}:${PORT}"
        notify_vuln "critical" "Exposed Memcached: ${IP}:${PORT} — unauthenticated"
    fi
}

_test_kubernetes() {
    local URL="$1"
    local INFRA_DIR="$2"

    log "[K8s] Testing $URL for Kubernetes API..."

    local RESP
    RESP=$(curl_safe -sk "${URL}/api/v1" --max-time 8 2>/dev/null)
    if echo "$RESP" | grep -q "APIResourceList\|GroupVersionForDiscovery"; then
        echo "K8S API EXPOSED: $URL" >> "$INFRA_DIR/k8s_exposure.txt"
        vuln "KUBERNETES API EXPOSED: $URL — unauthenticated"
        notify_vuln "critical" "Kubernetes API Exposed: $URL — full API access without auth"

        # Dump namespaces
        curl_safe -sk "${URL}/api/v1/namespaces" --max-time 8 2>/dev/null \
            | jq -r '.items[]?.metadata.name // empty' 2>/dev/null \
            >> "$INFRA_DIR/k8s_namespaces.txt" || true

        # Dump secrets (if accessible)
        curl_safe -sk "${URL}/api/v1/secrets" --max-time 8 2>/dev/null \
            | jq -r '.items[]?.metadata.name // empty' 2>/dev/null \
            >> "$INFRA_DIR/k8s_secrets.txt" || true
    fi

    # Kubernetes Dashboard
    local DASH_RESP
    DASH_RESP=$(curl_safe -sk "${URL}/#/overview" -o /dev/null -w "%{http_code}" --max-time 5 2>/dev/null || echo "000")
    [[ "$DASH_RESP" =~ ^2 ]] && {
        echo "K8S DASHBOARD: $URL" >> "$INFRA_DIR/k8s_exposure.txt"
        vuln "KUBERNETES DASHBOARD EXPOSED: $URL"
    }

    # Kubelet metrics (10255)
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}' | cut -d: -f1)
    for PORT in 10255 10250; do
        local KUBELET_RESP
        KUBELET_RESP=$(curl_safe -sk "http://${HOST}:${PORT}/pods" --max-time 6 2>/dev/null | head -c 200)
        if echo "$KUBELET_RESP" | grep -q "apiVersion\|Pod\|Container"; then
            echo "KUBELET EXPOSED: ${HOST}:${PORT}" >> "$INFRA_DIR/k8s_exposure.txt"
            vuln "KUBELET API EXPOSED: ${HOST}:${PORT} — pod info accessible"
            notify_vuln "critical" "Kubelet Exposed: ${HOST}:${PORT} — pod metadata accessible without auth"
        fi
    done
}

_test_docker() {
    local HOST="$1"
    local INFRA_DIR="$2"

    for PORT in "${DOCKER_PORTS[@]}"; do
        local RESP
        RESP=$(curl_safe -sk "http://${HOST}:${PORT}/version" --max-time 5 2>/dev/null)
        if echo "$RESP" | grep -qiE "ApiVersion|DockerVersion"; then
            local DOCKER_VER
            DOCKER_VER=$(echo "$RESP" | jq -r '.Version // "?"' 2>/dev/null)
            echo "DOCKER API EXPOSED: ${HOST}:${PORT} (v${DOCKER_VER})" >> "$INFRA_DIR/docker_exposure.txt"
            vuln "DOCKER API EXPOSED: ${HOST}:${PORT}"
            notify_vuln "critical" "Docker Remote API Exposed: ${HOST}:${PORT} — RCE possible via container creation"

            # List containers
            curl_safe -sk "http://${HOST}:${PORT}/containers/json" --max-time 6 2>/dev/null \
                | jq -r '.[]? | "\(.Names[0]) [\(.Image)] \(.State)"' 2>/dev/null \
                >> "$INFRA_DIR/docker_containers_${HOST}.txt" || true
        fi
    done
}

_test_docker_registry() {
    local URL="$1"
    local INFRA_DIR="$2"

    local RESP
    RESP=$(curl_safe -sk "${URL}/v2/" --max-time 6 2>/dev/null)
    if echo "$RESP" | grep -q '{}'; then
        echo "DOCKER REGISTRY EXPOSED: $URL" >> "$INFRA_DIR/docker_exposure.txt"
        vuln "DOCKER REGISTRY EXPOSED: $URL — unauthenticated"
        notify_vuln "critical" "Docker Registry Exposed: $URL — can pull/push images without auth"

        # List catalog
        curl_safe -sk "${URL}/v2/_catalog" --max-time 8 2>/dev/null \
            | jq -r '.repositories[]? // empty' 2>/dev/null \
            >> "$INFRA_DIR/registry_repos.txt" || true
    fi
}

_test_admin_panels() {
    local INFRA_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    log "[Admin] Probing exposed admin panels..."

    local -a ADMIN_PATHS=(
        "/admin" "/administrator" "/manager" "/management" "/console"
        "/phpmyadmin" "/pma" "/_pma" "/phpMyAdmin" "/myadmin"
        "/adminer" "/adminer.php" "/db" "/database" "/mysql"
        "/jenkins" "/jenkins/login" "/nexus" "/sonar" "/sonarqube"
        "/:8080" "/:8443" "/:9000" "/:9090" "/:3000" "/:8888"
        "/grafana" "/kibana" "/app/kibana" "/zabbix" "/nagios"
        "/actuator" "/actuator/env" "/actuator/health" "/health"
        "/metrics" "/prometheus" "/api/swagger-ui" "/swagger-ui"
    )

    head -20 "$ALIVE_FILE" 2>/dev/null | while IFS= read -r BASEURL; do
        BASEURL="${BASEURL%/}"
        for APATH in "${ADMIN_PATHS[@]}"; do
            local TARGET="${BASEURL}${APATH}"
            local RESP_CODE
            RESP_CODE=$(curl_safe -sk -o /dev/null -w "%{http_code}" "$TARGET" --max-time 5 2>/dev/null || echo "000")
            if [[ "$RESP_CODE" =~ ^2 ]]; then
                echo "${TARGET} [HTTP $RESP_CODE]" >> "$INFRA_DIR/admin_panels.txt"
                info "[Admin] Found: $TARGET"
            fi
        done &
    done
    wait

    local ADMIN_CNT
    ADMIN_CNT=$(wc -l < "$INFRA_DIR/admin_panels.txt" 2>/dev/null || echo 0)
    [ "$ADMIN_CNT" -gt 0 ] && {
        vuln "EXPOSED ADMIN PANELS: $ADMIN_CNT panels found"
        notify_vuln "high" "Exposed Admin Panels: $ADMIN_CNT found (see $INFRA_DIR/admin_panels.txt)"
    }
}

phase_20_infrastructure() {
    if phase_done "phase_20"; then return 0; fi
    [ "$INFRA_EXPOSURE_MODE" -ne 1 ] && { info "Infrastructure exposure mode disabled — skipping phase 20"; return; }
    phase_banner "PHASE 20: INFRASTRUCTURE EXPOSURE (DB / K8s / DOCKER / ADMIN)"

    local START_TIME
    START_TIME=$(date +%s)
    local INFRA_DIR="$OUTDIR/infrastructure"
    mkdir -p "$INFRA_DIR"

    : > "$INFRA_DIR/exposed_services.txt"
    : > "$INFRA_DIR/open_db_ports.txt"
    : > "$INFRA_DIR/k8s_exposure.txt"
    : > "$INFRA_DIR/docker_exposure.txt"
    : > "$INFRA_DIR/admin_panels.txt"

    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    # Build list of unique IPs/hosts from alive targets
    local HOST_LIST="$INFRA_DIR/target_hosts.txt"
    : > "$HOST_LIST"
    while IFS= read -r URL; do
        echo "$URL" | awk -F/ '{print $3}' | cut -d: -f1
    done < "$ALIVE_FILE" | sort -u > "$HOST_LIST"

    # Add hosts from IP ranges (phase 14)
    if [ -s "$OUTDIR/network_recon/all_candidate_ips.txt" ]; then
        cat "$OUTDIR/network_recon/all_candidate_ips.txt" >> "$HOST_LIST"
        sort -u "$HOST_LIST" -o "$HOST_LIST"
    fi

    local HOST_CNT
    HOST_CNT=$(wc -l < "$HOST_LIST" 2>/dev/null || echo 0)
    log "[20] Testing $HOST_CNT hosts for infrastructure exposure..."

    # ── [20.1] Database exposure ─────────────────────────────
    log "[20.1] Scanning for exposed databases..."
    local IDX=0
    while IFS= read -r HOST && [ $IDX -lt 50 ]; do
        IDX=$(( IDX + 1 ))
        progress_bar "DBScan" "$IDX" "50"
        _test_redis "$HOST" 6379 "$INFRA_DIR" &
        _test_mongodb "$HOST" 27017 "$INFRA_DIR" &
        _test_elasticsearch "$HOST" 9200 "$INFRA_DIR" &
        _test_memcached "$HOST" 11211 "$INFRA_DIR" &
        if (( IDX % 5 == 0 )); then wait; fi
    done < "$HOST_LIST"
    wait
    echo ""

    # ── [20.2] Kubernetes exposure ───────────────────────────
    log "[20.2] Testing for exposed Kubernetes APIs..."
    while IFS= read -r HOST; do
        _test_kubernetes "https://${HOST}:6443" "$INFRA_DIR" &
        _test_kubernetes "http://${HOST}:8080" "$INFRA_DIR" &
    done < <(head -20 "$HOST_LIST" 2>/dev/null)
    wait

    # ── [20.3] Docker exposure ───────────────────────────────
    log "[20.3] Testing for exposed Docker APIs and registries..."
    while IFS= read -r HOST; do
        _test_docker "$HOST" "$INFRA_DIR" &
        _test_docker_registry "http://${HOST}:5000" "$INFRA_DIR" &
        _test_docker_registry "https://${HOST}:5000" "$INFRA_DIR" &
    done < <(head -20 "$HOST_LIST" 2>/dev/null)
    wait

    # ── [20.4] Admin panels ──────────────────────────────────
    log "[20.4] Admin panel enumeration..."
    _test_admin_panels "$INFRA_DIR"

    # ── [20.5] Nuclei infra templates ────────────────────────
    if command -v nuclei &>/dev/null && [ -d "$NUCLEI_TEMPLATES" ]; then
        log "[20.5] Running nuclei infrastructure templates..."
        nuclei \
            -l "$ALIVE_FILE" \
            -t "$NUCLEI_TEMPLATES/http/exposed-panels/" \
            -t "$NUCLEI_TEMPLATES/http/misconfiguration/kubernetes/" \
            -t "$NUCLEI_TEMPLATES/http/misconfiguration/docker/" \
            -t "$NUCLEI_TEMPLATES/network/" \
            -silent -json \
            -o "$INFRA_DIR/nuclei_infra.jsonl" \
            2>/dev/null || true
    fi

    local EXPOSED_CNT DB_CNT K8S_CNT DOCKER_CNT ADMIN_CNT
    EXPOSED_CNT=$(wc -l < "$INFRA_DIR/exposed_services.txt" 2>/dev/null || echo 0)
    K8S_CNT=$(wc -l < "$INFRA_DIR/k8s_exposure.txt" 2>/dev/null || echo 0)
    DOCKER_CNT=$(wc -l < "$INFRA_DIR/docker_exposure.txt" 2>/dev/null || echo 0)
    ADMIN_CNT=$(wc -l < "$INFRA_DIR/admin_panels.txt" 2>/dev/null || echo 0)

    success "PHASE 20 DONE — Exposed services: $EXPOSED_CNT | K8s: $K8S_CNT | Docker: $DOCKER_CNT | Admin panels: $ADMIN_CNT | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 20: Infrastructure done — $EXPOSED_CNT exposed services, $K8S_CNT K8s, $DOCKER_CNT Docker, $ADMIN_CNT admin panels" "🏗️"
    mark_done "phase_20"
    echo ""
}
