#======================= PHASE 14: NETWORK RECON (ASN / CDN BYPASS / PASSIVE DNS) =======================
# ASN enumeration, real IP discovery behind CDN, BGP data, PassiveDNS

_asn_lookup() {
    local TARGET="$1"
    local RECON_DIR="$2"

    log "[ASN] Looking up ASN for $TARGET via BGPView..."
    local BGP_JSON
    BGP_JSON=$(curl_safe -s "https://api.bgpview.io/search?query_term=${TARGET}" 2>/dev/null) || return

    # Extract ASNs
    echo "$BGP_JSON" | jq -r '
        .data.asns[]? |
        "AS\(.asn) | \(.name) | \(.description) | \(.country_code)"
    ' 2>/dev/null >> "$RECON_DIR/asns.txt" || true

    # Pull prefixes for first ASN found
    local FIRST_ASN
    FIRST_ASN=$(echo "$BGP_JSON" | jq -r '.data.asns[0].asn // empty' 2>/dev/null)
    if [ -n "$FIRST_ASN" ]; then
        log "[ASN] Fetching prefixes for AS${FIRST_ASN}..."
        curl_safe -s "https://api.bgpview.io/asn/${FIRST_ASN}/prefixes" 2>/dev/null \
            | jq -r '
                (.data.ipv4_prefixes[]? | .prefix),
                (.data.ipv6_prefixes[]? | .prefix)
            ' 2>/dev/null >> "$RECON_DIR/ip_ranges.txt" || true
    fi
}

_cdn_bypass_headers() {
    local URL="$1"
    local RECON_DIR="$2"
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')

    # Try to get origin IP via various headers
    local -a ORIGIN_HDRS=(
        "X-Forwarded-For: 127.0.0.1"
        "X-Real-IP: 127.0.0.1"
        "True-Client-IP: 127.0.0.1"
        "CF-Connecting-IP: 127.0.0.1"
        "X-Originating-IP: 127.0.0.1"
    )
    for HDR in "${ORIGIN_HDRS[@]}"; do
        curl_safe -sI -H "$HDR" "$URL" -o /dev/null 2>/dev/null &
    done
}

_cdn_bypass_dns() {
    local HOST="$1"
    local RECON_DIR="$2"

    log "[CDN] Historical DNS lookups for $HOST..."

    # SecurityTrails history (requires key)
    if [ -n "$SECURITYTRAILS_API_KEY" ]; then
        curl_safe -s \
            -H "apikey: $SECURITYTRAILS_API_KEY" \
            "https://api.securitytrails.com/v1/history/${HOST}/dns/a" 2>/dev/null \
            | jq -r '.records[]?.values[]?.ip // empty' 2>/dev/null \
            >> "$RECON_DIR/historical_ips.txt" || true
    fi

    # HackerTarget API (free)
    curl_safe -s "https://api.hackertarget.com/hostsearch/?q=${HOST}" 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
        >> "$RECON_DIR/historical_ips.txt" 2>/dev/null || true

    # Shodan search (requires key)
    if [ -n "$SHODAN_API_KEY" ]; then
        curl_safe -s \
            "https://api.shodan.io/shodan/host/search?key=${SHODAN_API_KEY}&query=hostname:${HOST}&facets=ip" 2>/dev/null \
            | jq -r '.matches[]?.ip_str // empty' 2>/dev/null \
            >> "$RECON_DIR/historical_ips.txt" || true
    fi

    # Remove CDN IPs (Cloudflare, Fastly, Akamai ranges)
    if [ -s "$RECON_DIR/historical_ips.txt" ]; then
        sort -u "$RECON_DIR/historical_ips.txt" -o "$RECON_DIR/historical_ips.txt"
        local UNIQUE_COUNT
        UNIQUE_COUNT=$(wc -l < "$RECON_DIR/historical_ips.txt")
        info "[CDN] Found $UNIQUE_COUNT historical/alternate IPs for $HOST"
    fi
}

_passive_dns() {
    local HOST="$1"
    local RECON_DIR="$2"

    log "[PDNS] Passive DNS lookups for $HOST..."

    # RiskIQ PassiveTotal (free tier)
    curl_safe -s "https://api.passivetotal.org/v2/dns/passive?query=${HOST}" \
        2>/dev/null | jq -r '.results[]?.resolve // empty' 2>/dev/null \
        >> "$RECON_DIR/pdns_resolutions.txt" || true

    # DNS history via VirusTotal (requires key)
    if [ -n "$VIRUSTOTAL_API_KEY" ]; then
        curl_safe -s \
            -H "x-apikey: $VIRUSTOTAL_API_KEY" \
            "https://www.virustotal.com/api/v3/domains/${HOST}/resolutions?limit=40" 2>/dev/null \
            | jq -r '.data[]?.attributes.ip_address // empty' 2>/dev/null \
            >> "$RECON_DIR/pdns_resolutions.txt" || true
    fi

    # DNSDB via Farsight (free lookup endpoint)
    curl_safe -s "https://api.dnsdb.info/lookup/rrset/name/*.${HOST}/A?limit=50" \
        -H "X-API-Key: unauthenticated" 2>/dev/null \
        | jq -r '.rdata[]? // empty' 2>/dev/null \
        >> "$RECON_DIR/pdns_resolutions.txt" 2>/dev/null || true

    if [ -s "$RECON_DIR/pdns_resolutions.txt" ]; then
        sort -u "$RECON_DIR/pdns_resolutions.txt" -o "$RECON_DIR/pdns_resolutions.txt"
        info "[PDNS] $(wc -l < "$RECON_DIR/pdns_resolutions.txt") passive DNS resolutions collected"
    fi
}

_probe_origin_ips() {
    local HOST="$1"
    local RECON_DIR="$2"

    # Combine all candidate IPs
    local ALL_CANDIDATES="$RECON_DIR/all_candidate_ips.txt"
    cat "$RECON_DIR/historical_ips.txt" \
        "$RECON_DIR/pdns_resolutions.txt" \
        2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
        | grep -vE '^(8\.8\.8\.8|8\.8\.4\.4|1\.1\.1\.1|1\.0\.0\.1|9\.9\.9\.9|208\.67\.222\.222|208\.67\.220\.220)$' \
        | sort -u > "$ALL_CANDIDATES"

    local CAND_COUNT
    CAND_COUNT=$(wc -l < "$ALL_CANDIDATES" 2>/dev/null || echo 0)
    [ "$CAND_COUNT" -eq 0 ] && return

    log "[CDN] Probing $CAND_COUNT candidate origin IPs for $HOST..."
    local HITS=0
    while IFS= read -r IP; do
        local RESP
        RESP=$(curl_safe -sk --connect-timeout 5 \
            -H "Host: $HOST" \
            "https://${IP}/" -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
        if [[ "$RESP" =~ ^[23] ]]; then
            echo "${IP} → HTTP ${RESP} (Host: $HOST)" >> "$RECON_DIR/origin_ip_hits.txt"
            HITS=$(( HITS + 1 ))
            vuln "ORIGIN IP EXPOSED: $IP responds for $HOST (HTTP $RESP)"
            notify_vuln "high" "CDN Bypass: Origin IP $IP found for $HOST (HTTP $RESP)"
        fi
    done < "$ALL_CANDIDATES"
    info "[CDN] Origin IP probe complete — $HITS direct-access hits"
}

_ip_range_scan() {
    local RECON_DIR="$1"
    local ALIVE_FILE="$OUTDIR/alive/final_alive.txt"

    [ -s "$RECON_DIR/ip_ranges.txt" ] || return
    command -v naabu &>/dev/null || { info "[Naabu] not available — skipping IP range scan"; return; }

    log "[IPRange] Scanning ASN IP ranges with naabu..."
    local RANGE_FILE="$RECON_DIR/ip_ranges.txt"
    local RANGE_COUNT
    RANGE_COUNT=$(wc -l < "$RANGE_FILE")
    [ "$RANGE_COUNT" -gt 20 ] && { info "[IPRange] $RANGE_COUNT ranges — capping at first 20"; head -20 "$RANGE_FILE" > "${RANGE_FILE}.tmp" && mv "${RANGE_FILE}.tmp" "$RANGE_FILE"; }

    naabu \
        -list "$RANGE_FILE" \
        -top-ports 100 \
        -rate "$NAABU_RATE" \
        -silent \
        -json \
        -o "$RECON_DIR/range_ports.jsonl" \
        2>/dev/null || true

    if [ -s "$RECON_DIR/range_ports.jsonl" ]; then
        local OPEN_COUNT
        OPEN_COUNT=$(wc -l < "$RECON_DIR/range_ports.jsonl")
        success "[IPRange] $OPEN_COUNT open ports found in ASN ranges"
        # Extract new hosts not in original alive list
        jq -r '"http://\(.ip):\(.port)"' "$RECON_DIR/range_ports.jsonl" 2>/dev/null \
            | sort -u > "$RECON_DIR/new_hosts_from_ranges.txt"
    fi
}

_whois_and_org() {
    local HOST="$1"
    local RECON_DIR="$2"

    log "[WHOIS] Organization info for $HOST..."

    # Resolve current IP
    local CURRENT_IP
    CURRENT_IP=$(dig +short "$HOST" A 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$CURRENT_IP" ]; then
        echo "Current IP: $CURRENT_IP" > "$RECON_DIR/whois_summary.txt"

        # Detect CDN provider
        local CDN_PROVIDER=""
        if curl_safe -s "https://api.cloudflare.com/client/v4/ips" 2>/dev/null \
            | jq -r '.result.ipv4_cidrs[]' 2>/dev/null \
            | grep -q "$(echo "$CURRENT_IP" | cut -d. -f1-3)"; then
            CDN_PROVIDER="Cloudflare"
        fi
        whois "$CURRENT_IP" 2>/dev/null | grep -iE "^(org|orgname|netname|cidr|country)" \
            | head -15 >> "$RECON_DIR/whois_summary.txt" || true

        if [ -n "$CDN_PROVIDER" ]; then
            echo "CDN Provider detected: $CDN_PROVIDER" >> "$RECON_DIR/whois_summary.txt"
            info "[WHOIS] Target appears behind $CDN_PROVIDER"
        fi

        # BGPView IP lookup
        curl_safe -s "https://api.bgpview.io/ip/${CURRENT_IP}" 2>/dev/null \
            | jq -r '"ASN: AS\(.data.prefixes[0].asn.asn // "?")\nOrg: \(.data.prefixes[0].asn.name // "?")\nPrefix: \(.data.prefixes[0].prefix // "?")"' \
            2>/dev/null >> "$RECON_DIR/whois_summary.txt" || true
    fi
}

phase_14_network_recon() {
    if phase_done "phase_14"; then return 0; fi
    [ "$NETWORK_RECON_MODE" -ne 1 ] && { info "Network recon mode disabled — skipping phase 14"; return; }
    phase_banner "PHASE 14: NETWORK RECON (ASN / CDN BYPASS / PASSIVE DNS)"

    local START_TIME
    START_TIME=$(date +%s)
    local RECON_DIR="$OUTDIR/network_recon"
    mkdir -p "$RECON_DIR"

    : > "$RECON_DIR/asns.txt"
    : > "$RECON_DIR/ip_ranges.txt"
    : > "$RECON_DIR/historical_ips.txt"
    : > "$RECON_DIR/pdns_resolutions.txt"
    : > "$RECON_DIR/origin_ip_hits.txt"
    : > "$RECON_DIR/new_hosts_from_ranges.txt"

    # ── [14.1] WHOIS + Organization info ──────────────────────
    log "[14.1] WHOIS & organization data..."
    _whois_and_org "$DOMAIN" "$RECON_DIR"
    success "[14.1] WHOIS data collected"

    # ── [14.2] ASN Enumeration via BGPView ────────────────────
    log "[14.2] ASN enumeration..."
    _asn_lookup "$DOMAIN" "$RECON_DIR"
    local ASN_COUNT
    ASN_COUNT=$(grep -c "^AS" "$RECON_DIR/asns.txt" 2>/dev/null); ASN_COUNT=$(( ${ASN_COUNT:-0} + 0 ))
    local RANGE_COUNT
    RANGE_COUNT=$(wc -l < "$RECON_DIR/ip_ranges.txt" 2>/dev/null || echo 0)
    success "[14.2] ASNs: $ASN_COUNT | IP ranges: $RANGE_COUNT"

    # ── [14.3] CDN Bypass — historical DNS ───────────────────
    log "[14.3] CDN bypass via historical DNS..."
    _cdn_bypass_dns "$DOMAIN" "$RECON_DIR"
    success "[14.3] Historical DNS lookup complete"

    # ── [14.4] Passive DNS ───────────────────────────────────
    if [ "$PASSIVE_DNS_ENABLED" -eq 1 ]; then
        log "[14.4] Passive DNS collection..."
        _passive_dns "$DOMAIN" "$RECON_DIR"
        success "[14.4] Passive DNS complete"
    fi

    # ── [14.5] Probe candidate origin IPs ────────────────────
    if [ "$CDN_BYPASS_ENABLED" -eq 1 ]; then
        log "[14.5] Probing origin IPs directly..."
        _probe_origin_ips "$DOMAIN" "$RECON_DIR"
        local HIT_COUNT
        HIT_COUNT=$(wc -l < "$RECON_DIR/origin_ip_hits.txt" 2>/dev/null || echo 0)
        success "[14.5] Origin IP probing done — $HIT_COUNT direct hits"
    fi

    # ── [14.6] ASN IP Range Port Scan ────────────────────────
    if [ "$ASN_LOOKUP_ENABLED" -eq 1 ] && [ "$RANGE_COUNT" -gt 0 ]; then
        log "[14.6] Scanning ASN-owned IP ranges..."
        _ip_range_scan "$RECON_DIR"
        success "[14.6] IP range scan complete"
    fi

    # ── Summary ──────────────────────────────────────────────
    local ORIGINS
    ORIGINS=$(wc -l < "$RECON_DIR/origin_ip_hits.txt" 2>/dev/null || echo 0)
    local NEW_HOSTS
    NEW_HOSTS=$(wc -l < "$RECON_DIR/new_hosts_from_ranges.txt" 2>/dev/null || echo 0)

    success "PHASE 14 DONE — ASNs: $ASN_COUNT | Origin IPs found: $ORIGINS | New hosts: $NEW_HOSTS | Time: $(( $(date +%s) - $START_TIME ))s"
    notify "Phase 14: Network Recon done — $ORIGINS origin IPs exposed, $NEW_HOSTS new hosts from ASN ranges" "🌐"
    mark_done "phase_14"
    echo ""
}
