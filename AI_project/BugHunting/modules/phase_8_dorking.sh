#======================= PHASE 8: DORKING =======================
phase_8_dorking() {
    if phase_done "phase_8"; then return 0; fi
    phase_banner "PHASE 8: ADVANCED DORKING (GOOGLE / GITHUB / SHODAN / CENSYS / FOFA)"

    local START_TIME=$(date +%s)
    local DORK_DIR="$OUTDIR/dorking"

    # Google Dorks
    cat > "$DORK_DIR/google_dorks.txt" << EOF
# Admin and Login
site:$DOMAIN inurl:admin
site:$DOMAIN inurl:login
site:$DOMAIN inurl:wp-admin
site:$DOMAIN inurl:phpmyadmin
site:$DOMAIN inurl:cpanel
site:$DOMAIN inurl:dashboard
site:$DOMAIN inurl:panel
site:$DOMAIN inurl:portal

# APIs
site:$DOMAIN inurl:api
site:$DOMAIN inurl:swagger
site:$DOMAIN inurl:graphql
site:$DOMAIN inurl:openapi
site:$DOMAIN inurl:rest

# Dev and Test
site:$DOMAIN inurl:debug
site:$DOMAIN inurl:test
site:$DOMAIN inurl:dev
site:$DOMAIN inurl:staging
site:$DOMAIN inurl:beta
site:$DOMAIN inurl:sandbox

# Sensitive files
site:$DOMAIN inurl:.env
site:$DOMAIN inurl:.git
site:$DOMAIN inurl:.sql
site:$DOMAIN inurl:config
site:$DOMAIN inurl:backup
site:$DOMAIN filetype:pdf
site:$DOMAIN filetype:sql
site:$DOMAIN filetype:log
site:$DOMAIN filetype:conf
site:$DOMAIN filetype:yaml
site:$DOMAIN filetype:env
site:$DOMAIN filetype:xml intitle:"directory listing"
site:$DOMAIN filetype:json

# Credentials and Secrets
site:$DOMAIN intext:"api_key"
site:$DOMAIN intext:"access_token"
site:$DOMAIN intext:"password" filetype:log
site:$DOMAIN intext:"AWS_ACCESS_KEY"
site:$DOMAIN intext:"private_key"
site:$DOMAIN intext:"BEGIN RSA"

# Directory Listings
site:$DOMAIN intitle:"index of"
site:$DOMAIN intitle:"Index of /"
site:$DOMAIN intitle:"Directory listing"

# Error pages
site:$DOMAIN intext:"stack trace"
site:$DOMAIN intext:"exception" intext:"$DOMAIN"
site:$DOMAIN intext:"fatal error"
site:$DOMAIN intext:"syntax error"
site:$DOMAIN intext:"ORA-"
site:$DOMAIN intext:"MySQL server version"
EOF

    # GitHub Dorks
    cat > "$DORK_DIR/github_dorks.txt" << EOF
"$DOMAIN" api_key language:json
"$DOMAIN" api_key language:python
"$DOMAIN" api_key language:javascript
"$DOMAIN" api_secret
"$DOMAIN" access_token
"$DOMAIN" auth_token
"$DOMAIN" password
"$DOMAIN" secret
"$DOMAIN" private_key
"$DOMAIN" database_password
"$DOMAIN" db_password
"$DOMAIN" connection_string
"$DOMAIN" mongodb://
"$DOMAIN" postgres://
"$DOMAIN" mysql://
"$DOMAIN" .env
"$DOMAIN" config.json
"$DOMAIN" credentials
"$DOMAIN" jwt_secret
"$DOMAIN" stripe_key
"$DOMAIN" aws_access_key_id
"$DOMAIN" aws_secret_access_key
"$DOMAIN" firebase_token
"$DOMAIN" slack_token
"$DOMAIN" twilio_token
"$DOMAIN" sendgrid_key
"$DOMAIN" sentry_dsn
"$DOMAIN" AKIA
"$DOMAIN" hooks.slack.com
"$DOMAIN" BEGIN RSA PRIVATE KEY
EOF

    # Shodan Dorks
    cat > "$DORK_DIR/shodan_dorks.txt" << EOF
hostname:$DOMAIN
ssl:$DOMAIN
http.html:"$DOMAIN"
http.title:"$DOMAIN"
org:"$DOMAIN"
net:$DOMAIN
port:443 hostname:$DOMAIN
port:8080 hostname:$DOMAIN
port:8443 hostname:$DOMAIN
port:9200 hostname:$DOMAIN
port:27017 hostname:$DOMAIN
port:5432 hostname:$DOMAIN
port:6379 hostname:$DOMAIN
port:3306 hostname:$DOMAIN
vuln:CVE-2021-44228 hostname:$DOMAIN
vuln:CVE-2022-22965 hostname:$DOMAIN
product:apache hostname:$DOMAIN
product:nginx hostname:$DOMAIN
product:iis hostname:$DOMAIN
product:wordpress hostname:$DOMAIN
product:jenkins hostname:$DOMAIN
product:kibana hostname:$DOMAIN
product:grafana hostname:$DOMAIN
product:prometheus hostname:$DOMAIN
EOF

    # FOFA Dorks
    cat > "$DORK_DIR/fofa_dorks.txt" << EOF
domain="$DOMAIN"
host="$DOMAIN"
cert.subject.cn="$DOMAIN"
cert.issuer.cn="$DOMAIN"
title="$DOMAIN"
body="$DOMAIN" && is_domain=true
icon_hash="-247388890" && domain="$DOMAIN"
app="WordPress" && domain="$DOMAIN"
app="Joomla" && domain="$DOMAIN"
app="Drupal" && domain="$DOMAIN"
EOF

    # Censys Queries
    cat > "$DORK_DIR/censys_queries.txt" << EOF
services.http.response.html_tags.title: "$DOMAIN"
services.tls.certificates.leaf_data.names: "$DOMAIN"
services.dns.resolved_records.name: "$DOMAIN"
parsed.subject_dn: "CN=*.$DOMAIN"
parsed.names: "$DOMAIN"
services.port: 8080 AND services.http.response.html_tags.title: "$DOMAIN"
services.port: 9200 AND services.http.response.html_tags.title: "$DOMAIN"
EOF

    log "[8.1] Running theHarvester..."
    if command -v theHarvester &>/dev/null; then
        theHarvester -d "$DOMAIN" -b all \
            -f "$DORK_DIR/theharvester" \
            2>>"$OUTDIR/logs/errors.log" \
            || {
                local _TH_EC=$?
                warning "theHarvester failed (exit ${_TH_EC}) — check $OUTDIR/logs/errors.log"
                echo "[theHarvester] exit ${_TH_EC} at $(date)" >> "$OUTDIR/logs/errors.log"
            }
    fi

    run_repo_osint

    success "PHASE 8 DONE - Dorks and repo OSINT complete | Time: $(($(date +%s)-START_TIME))s"
    notify "Phase 8: Dorking and repository OSINT complete" "OSINT"
    echo ""
}
