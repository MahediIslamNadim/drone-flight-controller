#======================= PHASE 6: CLOUD ASSET DISCOVERY =======================
phase_6_cloud_discovery() {
    if phase_done "phase_6"; then return 0; fi
    phase_banner "PHASE 6: CLOUD ASSET DISCOVERY (S3 / GCS / AZURE / FIREBASE / DO / R2)"

    local START_TIME
    START_TIME=$(date +%s)
    local CLOUD_DIR="$OUTDIR/cloud"
    local DOMAIN_CLEAN
    DOMAIN_CLEAN="${DOMAIN//./-}"
    local ROOT_LABEL="${DOMAIN%%.*}"

    if should_skip_noisy_phase "Phase 6 cloud asset discovery"; then
        return
    fi

    # ── Generate bucket name permutations ──
    log "[6.1] Generating cloud asset name permutations..."
    cat > "$CLOUD_DIR/bucket_names.txt" << EOF
$DOMAIN
$DOMAIN_CLEAN
$ROOT_LABEL
www.$DOMAIN
api.$DOMAIN
static.$DOMAIN
assets.$DOMAIN
media.$DOMAIN
uploads.$DOMAIN
files.$DOMAIN
cdn.$DOMAIN
backup.$DOMAIN
dev.$DOMAIN
staging.$DOMAIN
prod.$DOMAIN
app.$DOMAIN
mail.$DOMAIN
admin.$DOMAIN
data.$DOMAIN
download.$DOMAIN
logs.$DOMAIN
images.$DOMAIN
store.$DOMAIN
content.$DOMAIN
public.$DOMAIN
private.$DOMAIN
internal.$DOMAIN
test.$DOMAIN
${ROOT_LABEL}-prod
${ROOT_LABEL}-dev
${ROOT_LABEL}-staging
${ROOT_LABEL}-backup
${ROOT_LABEL}-assets
${ROOT_LABEL}-static
${ROOT_LABEL}-uploads
${ROOT_LABEL}-media
${ROOT_LABEL}-files
${ROOT_LABEL}-data
${ROOT_LABEL}-logs
${ROOT_LABEL}-public
EOF

    local ESCAPED_DOMAIN="${DOMAIN//./\\.}"
    local TOTAL_BUCKETS
    TOTAL_BUCKETS=$(wc -l < "$CLOUD_DIR/bucket_names.txt")
    local CHECKED=0
    local BASE

    # Helper: strip domain suffix from bucket name to get the base label
    _cloud_base() {
        printf '%s\n' "$1" | sed "s/\\.${ESCAPED_DOMAIN}$//;s/[._]/-/g"
    }

    # Helper: probe a URL and record result
    _cloud_probe() {
        local URL="$1" LABEL="$2" OUT="$3" VULN_MSG="$4"
        local STATUS
        STATUS=$(curl_safe -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo 000)
        record_block_signal "$STATUS" "$URL"
        case "$STATUS" in
            200)
                echo "[200-OPEN] $URL" >> "$OUT"
                vuln "$VULN_MSG: $URL"
                notify_vuln "high" "$VULN_MSG: $URL"
                ;;
            403)
                # Bucket exists but access denied — still worth noting
                echo "[403-EXISTS] $URL" >> "$OUT"
                ;;
            301|302)
                echo "[${STATUS}-REDIRECT] $URL" >> "$OUT"
                ;;
        esac
    }

    # ── AWS S3 ──
    log "[6.2] Checking AWS S3 buckets..."
    : > "$CLOUD_DIR/s3_found.txt"
    while IFS= read -r BUCKET; do
        CHECKED=$(( CHECKED + 1 ))
        progress_bar "S3" "$CHECKED" "$TOTAL_BUCKETS"
        BASE=$(_cloud_base "$BUCKET")
        _cloud_probe "https://${BASE}.s3.amazonaws.com"         "S3" "$CLOUD_DIR/s3_found.txt" "OPEN S3 BUCKET"
        _cloud_probe "https://s3.amazonaws.com/${BASE}"         "S3" "$CLOUD_DIR/s3_found.txt" "OPEN S3"
        _cloud_probe "https://${BASE}.s3-us-east-1.amazonaws.com" "S3" "$CLOUD_DIR/s3_found.txt" "OPEN S3-US-EAST"
    done < "$CLOUD_DIR/bucket_names.txt"
    echo ""
    success "S3: $(wc -l < "$CLOUD_DIR/s3_found.txt" 2>/dev/null || echo 0) findings"

    # ── Google Cloud Storage ──
    log "[6.3] Checking Google Cloud Storage buckets..."
    : > "$CLOUD_DIR/gcs_found.txt"
    CHECKED=0
    while IFS= read -r BUCKET; do
        CHECKED=$(( CHECKED + 1 ))
        progress_bar "GCS" "$CHECKED" "$TOTAL_BUCKETS"
        BASE=$(_cloud_base "$BUCKET")
        _cloud_probe "https://storage.googleapis.com/${BASE}"        "GCS" "$CLOUD_DIR/gcs_found.txt" "OPEN GCS BUCKET"
        _cloud_probe "https://${BASE}.storage.googleapis.com"        "GCS" "$CLOUD_DIR/gcs_found.txt" "OPEN GCS"
    done < "$CLOUD_DIR/bucket_names.txt"
    echo ""
    success "GCS: $(wc -l < "$CLOUD_DIR/gcs_found.txt" 2>/dev/null || echo 0) findings"

    # ── Azure Blob Storage ──
    log "[6.4] Checking Azure Blob Storage..."
    : > "$CLOUD_DIR/azure_found.txt"
    CHECKED=0
    while IFS= read -r BUCKET; do
        CHECKED=$(( CHECKED + 1 ))
        progress_bar "Azure" "$CHECKED" "$TOTAL_BUCKETS"
        BASE=$(_cloud_base "$BUCKET")
        _cloud_probe "https://${BASE}.blob.core.windows.net"         "AZ" "$CLOUD_DIR/azure_found.txt" "OPEN AZURE BLOB"
        _cloud_probe "https://${BASE}.file.core.windows.net"         "AZ" "$CLOUD_DIR/azure_found.txt" "OPEN AZURE FILE"
    done < "$CLOUD_DIR/bucket_names.txt"
    echo ""
    success "Azure: $(wc -l < "$CLOUD_DIR/azure_found.txt" 2>/dev/null || echo 0) findings"

    # ── Firebase Hosting / Realtime DB ──
    log "[6.5] Checking Firebase assets..."
    : > "$CLOUD_DIR/firebase_found.txt"
    while IFS= read -r BUCKET; do
        BASE=$(_cloud_base "$BUCKET")
        # Firebase Realtime Database — returns 200 with JSON on public DBs
        local FB_DB="https://${BASE}-default-rtdb.firebaseio.com/.json"
        local STATUS
        STATUS=$(curl_safe -o /dev/null -w "%{http_code}" "$FB_DB" 2>/dev/null || echo 000)
        if [ "$STATUS" = "200" ]; then
            echo "[200-OPEN-DB] $FB_DB" >> "$CLOUD_DIR/firebase_found.txt"
            vuln "OPEN FIREBASE DB: $FB_DB"
            notify_vuln "critical" "Public Firebase Realtime DB: $FB_DB"
        fi
        # Firebase Hosting
        _cloud_probe "https://${BASE}.web.app"         "FB" "$CLOUD_DIR/firebase_found.txt" "FIREBASE HOSTING"
        _cloud_probe "https://${BASE}.firebaseapp.com" "FB" "$CLOUD_DIR/firebase_found.txt" "FIREBASE HOSTING"
    done < <(head -15 "$CLOUD_DIR/bucket_names.txt")
    success "Firebase: $(wc -l < "$CLOUD_DIR/firebase_found.txt" 2>/dev/null || echo 0) findings"

    # ── DigitalOcean Spaces ──
    log "[6.6] Checking DigitalOcean Spaces..."
    : > "$CLOUD_DIR/do_spaces_found.txt"
    local DO_REGIONS=(nyc3 sfo3 ams3 sgp1 lon1 fra1 tor1 blr1)
    while IFS= read -r BUCKET; do
        BASE=$(_cloud_base "$BUCKET")
        for REGION in "${DO_REGIONS[@]}"; do
            _cloud_probe "https://${BASE}.${REGION}.digitaloceanspaces.com" "DO" \
                "$CLOUD_DIR/do_spaces_found.txt" "OPEN DO SPACE"
        done
    done < <(head -10 "$CLOUD_DIR/bucket_names.txt")
    success "DO Spaces: $(wc -l < "$CLOUD_DIR/do_spaces_found.txt" 2>/dev/null || echo 0) findings"

    # ── Cloudflare R2 ──
    log "[6.7] Checking Cloudflare R2 public buckets..."
    : > "$CLOUD_DIR/r2_found.txt"
    while IFS= read -r BUCKET; do
        BASE=$(_cloud_base "$BUCKET")
        # R2 public access uses account-scoped URLs; check common patterns
        _cloud_probe "https://pub-${BASE}.r2.dev"                "R2" "$CLOUD_DIR/r2_found.txt" "OPEN CF R2"
        _cloud_probe "https://${BASE}.r2.cloudflarestorage.com"  "R2" "$CLOUD_DIR/r2_found.txt" "OPEN CF R2"
    done < <(head -10 "$CLOUD_DIR/bucket_names.txt")
    success "R2: $(wc -l < "$CLOUD_DIR/r2_found.txt" 2>/dev/null || echo 0) findings"

    # ── Nuclei cloud templates ──
    log "[6.8] Nuclei cloud misconfiguration templates..."
    if [ -s "$OUTDIR/alive/final_alive.txt" ]; then
        network_run nuclei -l "$OUTDIR/alive/final_alive.txt" \
            -t "$NUCLEI_TEMPLATES/cloud/" \
            -c "$NUCLEI_CONCURRENCY" \
            -rate-limit "$NUCLEI_RATE_LIMIT" \
            -o "$CLOUD_DIR/nuclei_cloud.txt" \
            -silent 2>>"$OUTDIR/logs/errors.log" || true
    fi

    # ── Aggregate total cloud findings ──
    cat "$CLOUD_DIR"/{s3,gcs,azure,firebase,do_spaces,r2}_found.txt 2>/dev/null | \
        grep "^\[200" | sort -u > "$CLOUD_DIR/all_open.txt"
    local TOTAL_OPEN
    TOTAL_OPEN=$(wc -l < "$CLOUD_DIR/all_open.txt" 2>/dev/null || echo 0)
    [ "$TOTAL_OPEN" -gt 0 ] && notify_vuln "high" "Cloud scan: $TOTAL_OPEN OPEN assets found on $DOMAIN"

    cooldown_if_waf_pressure
    success "PHASE 6 DONE — Cloud open assets: $TOTAL_OPEN | Time: $(( $(date +%s) - START_TIME ))s"
    notify "Phase 6: Cloud scan done ($TOTAL_OPEN open)" "☁️"
    echo ""
}
