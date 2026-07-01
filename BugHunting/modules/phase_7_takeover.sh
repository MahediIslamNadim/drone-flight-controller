#======================= PHASE 7: SUBDOMAIN TAKEOVER =======================
phase_7_subdomain_takeover() {
    if phase_done "phase_7"; then return 0; fi
    phase_banner "PHASE 7: SUBDOMAIN TAKEOVER DETECTION"

    local START_TIME
    START_TIME=$(date +%s)
    local TAKEOVER_DIR="$OUTDIR/takeover"
    local SUB_FILE="$OUTDIR/subdomains/final_subs.txt"

    mkdir -p "$TAKEOVER_DIR"
    : > "$TAKEOVER_DIR/subjack.txt"
    : > "$TAKEOVER_DIR/nuclei_takeover.txt"
    : > "$TAKEOVER_DIR/dangling_cnames.txt"

    [ ! -s "$SUB_FILE" ] && { error "No subdomains!"; return; }

    # ── Subjack ──
    if command -v subjack &>/dev/null; then
        log "[7.1] Subjack takeover scan..."
        subjack -w "$SUB_FILE" \
            -t "$THREADS" \
            -a \
            -ssl \
            -o "$TAKEOVER_DIR/subjack.txt" \
            2>>"$OUTDIR/logs/errors.log"
        local TAKE_COUNT
        TAKE_COUNT=$(wc -l < "$TAKEOVER_DIR/subjack.txt" 2>/dev/null || echo 0)
        [ "$TAKE_COUNT" -gt 0 ] && {
            vuln "SUBDOMAIN TAKEOVER CANDIDATES: $TAKE_COUNT"
            notify_vuln "high" "Potential takeover: $TAKE_COUNT subdomains"
        }
    fi

    # ── Nuclei takeover templates ──
    log "[7.2] Nuclei takeover templates..."
    network_run nuclei -l "$SUB_FILE" \
        -t "$NUCLEI_TEMPLATES/takeovers/" \
        -c "$NUCLEI_CONCURRENCY" \
        -rate-limit "$NUCLEI_RATE_LIMIT" \
        -o "$TAKEOVER_DIR/nuclei_takeover.txt" \
        -silent 2>>"$OUTDIR/logs/errors.log"

    # ── Manual CNAME check + service fingerprinting ──
    log "[7.3] CNAME→dangling check + service fingerprinting..."
    : > "$TAKEOVER_DIR/takeover_eligible.txt"
    while IFS= read -r SUB; do
        local CNAME
        CNAME=$(dig CNAME "$SUB" +short 2>/dev/null | head -1)
        if [ -n "$CNAME" ]; then
            local IP
            IP=$(dig A "$CNAME" +short 2>/dev/null | head -1)
            if [ -z "$IP" ]; then
                echo "DANGLING_CNAME: $SUB -> $CNAME" >> "$TAKEOVER_DIR/dangling_cnames.txt"
                warning "Dangling CNAME: $SUB → $CNAME"

                # Fingerprint which service this CNAME points to — determines takeover feasibility
                local SERVICE="unknown"
                case "$CNAME" in
                    *.github.io*)         SERVICE="GitHub Pages" ;;
                    *.githubusercontent.com*) SERVICE="GitHub" ;;
                    *.herokussl.com*|*.herokuapp.com*) SERVICE="Heroku" ;;
                    *.s3.amazonaws.com*|*.s3-website*) SERVICE="AWS S3" ;;
                    *.cloudfront.net*)    SERVICE="AWS CloudFront" ;;
                    *.elasticbeanstalk.com*) SERVICE="AWS ElasticBeanstalk" ;;
                    *.azurewebsites.net*) SERVICE="Azure Web Apps" ;;
                    *.azureedge.net*)     SERVICE="Azure CDN" ;;
                    *.cloudapp.net*)      SERVICE="Azure" ;;
                    *.fastly.net*)        SERVICE="Fastly" ;;
                    *.zendesk.com*)       SERVICE="Zendesk" ;;
                    *.helpscoutdocs.com*) SERVICE="HelpScout" ;;
                    *.ghost.io*)          SERVICE="Ghost" ;;
                    *.webflow.io*)        SERVICE="Webflow" ;;
                    *.surge.sh*)          SERVICE="Surge.sh" ;;
                    *.netlify.app*|*.netlify.com*) SERVICE="Netlify" ;;
                    *.vercel.app*)        SERVICE="Vercel" ;;
                    *.pantheonsite.io*)   SERVICE="Pantheon" ;;
                    *.shopify.com*)       SERVICE="Shopify" ;;
                    *.bigcartel.com*)     SERVICE="BigCartel" ;;
                    *.cargo.site*)        SERVICE="Cargo" ;;
                    *.statuspage.io*)     SERVICE="StatusPage" ;;
                    *.freshdesk.com*)     SERVICE="Freshdesk" ;;
                    *.uservoice.com*)     SERVICE="UserVoice" ;;
                    *.tumblr.com*)        SERVICE="Tumblr" ;;
                    *.wp.com*)            SERVICE="WordPress" ;;
                esac

                # HTTP probe to confirm dangling (look for known takeover indicators)
                local HTTP_RESP
                HTTP_RESP=$(curl_safe -sk "https://${SUB}" --max-time 8 2>/dev/null | head -c 500)
                local IS_TAKEABLE=0
                case "$SERVICE" in
                    "GitHub Pages")
                        echo "$HTTP_RESP" | grep -qi "There isn't a GitHub Pages site here\|404" && IS_TAKEABLE=1 ;;
                    "Heroku")
                        echo "$HTTP_RESP" | grep -qi "no such app\|herokucdn" && IS_TAKEABLE=1 ;;
                    "AWS S3")
                        echo "$HTTP_RESP" | grep -qi "NoSuchBucket\|The specified bucket" && IS_TAKEABLE=1 ;;
                    "Azure Web Apps")
                        echo "$HTTP_RESP" | grep -qi "does not exist\|404 Web Site not found" && IS_TAKEABLE=1 ;;
                    "Netlify")
                        echo "$HTTP_RESP" | grep -qi "Not Found\|page not found" && IS_TAKEABLE=1 ;;
                    "Fastly")
                        echo "$HTTP_RESP" | grep -qi "Fastly error: unknown domain\|Please check that this domain" && IS_TAKEABLE=1 ;;
                    "Zendesk")
                        echo "$HTTP_RESP" | grep -qi "Help Center Closed\|this help center no longer" && IS_TAKEABLE=1 ;;
                    *)
                        # Unknown service — flag for manual review
                        [ -z "$IP" ] && IS_TAKEABLE=0 ;;
                esac

                if [ "$IS_TAKEABLE" -eq 1 ]; then
                    echo "TAKEOVER_ELIGIBLE: $SUB -> $CNAME [$SERVICE]" >> "$TAKEOVER_DIR/takeover_eligible.txt"
                    vuln "SUBDOMAIN TAKEOVER ELIGIBLE: $SUB → $CNAME ($SERVICE)"
                    notify_vuln "critical" "Subdomain Takeover: $SUB → $CNAME via $SERVICE — register to claim"
                else
                    echo "DANGLING_UNVERIFIED: $SUB -> $CNAME [$SERVICE — manual review needed]" >> "$TAKEOVER_DIR/dangling_cnames.txt"
                fi
            fi
        fi
    done < "$SUB_FILE"

    local DANGLING_CNT ELIGIBLE_CNT
    DANGLING_CNT=$(wc -l < "$TAKEOVER_DIR/dangling_cnames.txt" 2>/dev/null || echo 0)
    ELIGIBLE_CNT=$(wc -l < "$TAKEOVER_DIR/takeover_eligible.txt" 2>/dev/null || echo 0)
    [ "$ELIGIBLE_CNT" -gt 0 ] && {
        vuln "CONFIRMED TAKEOVER ELIGIBLE: $ELIGIBLE_CNT subdomains"
        notify_vuln "critical" "Subdomain Takeover: $ELIGIBLE_CNT confirmed eligible (see takeover_eligible.txt)"
    }

    success "PHASE 7 DONE — Dangling: $DANGLING_CNT | Takeover eligible: $ELIGIBLE_CNT | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 7: Takeover done — $ELIGIBLE_CNT confirmed eligible, $DANGLING_CNT dangling CNAMEs" "⛳"
    mark_done "phase_7"
    echo ""
}

