#======================= REPOSITORY OSINT =======================
repo_osint_safe_name() {
    printf '%s\n' "$1" | sed 's|[^a-zA-Z0-9._-]|_|g'
}

repo_osint_write_terms() {
    local REPO_DIR="$1"
    local CLEAN_DOMAIN="${DOMAIN#www.}"
    local ROOT_LABEL="${CLEAN_DOMAIN%%.*}"
    local ROOT_SPACED="${ROOT_LABEL//-/ }"
    local ROOT_COMPACT="${ROOT_LABEL//-/}"

    cat > "$REPO_DIR/search_terms.txt" << EOF
$CLEAN_DOMAIN
$ROOT_LABEL
$ROOT_SPACED
$ROOT_COMPACT
EOF

    sort -u "$REPO_DIR/search_terms.txt" -o "$REPO_DIR/search_terms.txt"
}

repo_osint_search_github() {
    local REPO_DIR="$1"
    local TMP_FILE="$REPO_DIR/tmp_github.json"
    local GITHUB_REPOS="$REPO_DIR/github_repos.jsonl"
    local GITHUB_OWNERS="$REPO_DIR/github_owners.txt"
    local HDR=()

    [ "$REPO_OSINT_MODE" -ne 1 ] && return
    [ -n "$GITHUB_TOKEN" ] && HDR+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    HDR+=(-H "Accept: application/vnd.github+json")

    : > "$GITHUB_REPOS"
    : > "$GITHUB_OWNERS"

    log "[8.2] GitHub repository discovery..."
    while IFS= read -r TERM; do
        [ -z "$TERM" ] && continue

        local QUERY
        for QUERY in "\"$TERM\" in:name,description,readme archived:false" "\"$TERM\" in:name,description archived:false"; do
            local PAGE=1
            while [ "$PAGE" -le "$REPO_SEARCH_PAGES" ]; do
                local URL="${GITHUB_API_URL}/search/repositories?q=$(jq -nr --arg v "$QUERY" '$v|@uri')&per_page=$REPO_SEARCH_PER_PAGE&page=$PAGE"
                if ! curl_safe "${HDR[@]}" -o "$TMP_FILE" "$URL" 2>/dev/null; then
                    break
                fi

                local COUNT
                COUNT=$(jq '.items | length' "$TMP_FILE" 2>/dev/null || echo 0)
                [ "$COUNT" -eq 0 ] && break

                jq -rc '.items[]? | {
                    platform: "github",
                    source: "search",
                    name: .full_name,
                    web_url: .html_url,
                    clone_url: .clone_url,
                    visibility: (if .private then "private" else "public" end),
                    archived: .archived,
                    fork: .fork,
                    stars: .stargazers_count,
                    default_branch: .default_branch,
                    description: (.description // "")
                }' "$TMP_FILE" 2>/dev/null >> "$GITHUB_REPOS"
                PAGE=$((PAGE + 1))
            done
        done

        for QUERY in "$TERM type:org" "$TERM type:user"; do
            local URL="${GITHUB_API_URL}/search/users?q=$(jq -nr --arg v "$QUERY" '$v|@uri')&per_page=$REPO_SEARCH_PER_PAGE&page=1"
            if curl_safe "${HDR[@]}" -o "$TMP_FILE" "$URL" 2>/dev/null; then
                jq -r '.items[]? | [.login, .type] | @tsv' "$TMP_FILE" 2>/dev/null >> "$GITHUB_OWNERS"
            fi
        done
    done < "$REPO_DIR/search_terms.txt"

    if [ -s "$GITHUB_OWNERS" ]; then
        sort -u "$GITHUB_OWNERS" -o "$GITHUB_OWNERS"
        while IFS=$'\t' read -r OWNER TYPE; do
            [ -z "$OWNER" ] && continue
            local PAGE=1
            while [ "$PAGE" -le "$REPO_SEARCH_PAGES" ]; do
                local URL="${GITHUB_API_URL}/users/${OWNER}/repos?type=owner&sort=updated&per_page=$REPO_SEARCH_PER_PAGE&page=$PAGE"
                if ! curl_safe "${HDR[@]}" -o "$TMP_FILE" "$URL" 2>/dev/null; then
                    break
                fi

                local COUNT
                COUNT=$(jq 'length' "$TMP_FILE" 2>/dev/null || echo 0)
                [ "$COUNT" -eq 0 ] && break

                jq -rc --arg owner "$OWNER" '.[]? | {
                    platform: "github",
                    source: "owner",
                    owner: $owner,
                    name: .full_name,
                    web_url: .html_url,
                    clone_url: .clone_url,
                    visibility: (if .private then "private" else "public" end),
                    archived: .archived,
                    fork: .fork,
                    stars: .stargazers_count,
                    default_branch: .default_branch,
                    description: (.description // "")
                }' "$TMP_FILE" 2>/dev/null >> "$GITHUB_REPOS"
                PAGE=$((PAGE + 1))
            done
        done < "$GITHUB_OWNERS"
    fi

    [ -f "$TMP_FILE" ] && rm -f "$TMP_FILE"
    [ -f "$GITHUB_REPOS" ] && sort -u "$GITHUB_REPOS" -o "$GITHUB_REPOS"
}

repo_osint_search_gitlab() {
    local REPO_DIR="$1"
    local TMP_FILE="$REPO_DIR/tmp_gitlab.json"
    local GITLAB_REPOS="$REPO_DIR/gitlab_repos.jsonl"
    local GITLAB_GROUPS="$REPO_DIR/gitlab_groups.txt"
    local HDR=()

    [ "$REPO_OSINT_MODE" -ne 1 ] && return
    [ -n "$GITLAB_TOKEN" ] && HDR+=(-H "PRIVATE-TOKEN: $GITLAB_TOKEN")

    : > "$GITLAB_REPOS"
    : > "$GITLAB_GROUPS"

    log "[8.3] GitLab repository discovery..."
    while IFS= read -r TERM; do
        [ -z "$TERM" ] && continue

        local PAGE=1
        while [ "$PAGE" -le "$REPO_SEARCH_PAGES" ]; do
            local URL="${GITLAB_API_URL}/projects?search=$(jq -nr --arg v "$TERM" '$v|@uri')&simple=true&per_page=$REPO_SEARCH_PER_PAGE&page=$PAGE"
            if ! curl_safe "${HDR[@]}" -o "$TMP_FILE" "$URL" 2>/dev/null; then
                break
            fi

            local COUNT
            COUNT=$(jq 'length' "$TMP_FILE" 2>/dev/null || echo 0)
            [ "$COUNT" -eq 0 ] && break

            jq -rc '.[]? | {
                platform: "gitlab",
                source: "project-search",
                name: .path_with_namespace,
                web_url: .web_url,
                clone_url: .http_url_to_repo,
                visibility: (.visibility // "public"),
                archived: (.archived // false),
                fork: false,
                stars: (.star_count // 0),
                default_branch: (.default_branch // ""),
                description: (.description // "")
            }' "$TMP_FILE" 2>/dev/null >> "$GITLAB_REPOS"
            PAGE=$((PAGE + 1))
        done

        local URL="${GITLAB_API_URL}/groups?search=$(jq -nr --arg v "$TERM" '$v|@uri')&per_page=$REPO_SEARCH_PER_PAGE&page=1"
        if curl_safe "${HDR[@]}" -o "$TMP_FILE" "$URL" 2>/dev/null; then
            jq -r '.[]? | [.id, .full_path] | @tsv' "$TMP_FILE" 2>/dev/null >> "$GITLAB_GROUPS"
        fi
    done < "$REPO_DIR/search_terms.txt"

    if [ -s "$GITLAB_GROUPS" ]; then
        sort -u "$GITLAB_GROUPS" -o "$GITLAB_GROUPS"
        while IFS=$'\t' read -r GROUP_ID GROUP_PATH; do
            [ -z "$GROUP_ID" ] && continue
            local PAGE=1
            while [ "$PAGE" -le "$REPO_SEARCH_PAGES" ]; do
                local URL="${GITLAB_API_URL}/groups/${GROUP_ID}/projects?include_subgroups=true&simple=true&per_page=$REPO_SEARCH_PER_PAGE&page=$PAGE"
                if ! curl_safe "${HDR[@]}" -o "$TMP_FILE" "$URL" 2>/dev/null; then
                    break
                fi

                local COUNT
                COUNT=$(jq 'length' "$TMP_FILE" 2>/dev/null || echo 0)
                [ "$COUNT" -eq 0 ] && break

                jq -rc --arg grp "$GROUP_PATH" '.[]? | {
                    platform: "gitlab",
                    source: "group",
                    group: $grp,
                    name: .path_with_namespace,
                    web_url: .web_url,
                    clone_url: .http_url_to_repo,
                    visibility: (.visibility // "public"),
                    archived: (.archived // false),
                    fork: false,
                    stars: (.star_count // 0),
                    default_branch: (.default_branch // ""),
                    description: (.description // "")
                }' "$TMP_FILE" 2>/dev/null >> "$GITLAB_REPOS"
                PAGE=$((PAGE + 1))
            done
        done < "$GITLAB_GROUPS"
    fi

    [ -f "$TMP_FILE" ] && rm -f "$TMP_FILE"
    [ -f "$GITLAB_REPOS" ] && sort -u "$GITLAB_REPOS" -o "$GITLAB_REPOS"
}

repo_osint_build_inventory() {
    local REPO_DIR="$1"
    local INVENTORY="$REPO_DIR/repo_inventory.jsonl"
    local TARGETS="$REPO_DIR/clone_targets.tsv"

    cat "$REPO_DIR"/github_repos.jsonl "$REPO_DIR"/gitlab_repos.jsonl 2>/dev/null | \
        jq -rc --argjson include_forks "$REPO_INCLUDE_FORKS" '
            select(.clone_url != null and .web_url != null) |
            select((.visibility // "public") == "public") |
            select((.archived // false) != true) |
            select($include_forks == 1 or (.fork // false) != true)
        ' 2>/dev/null | sort -u > "$INVENTORY" || :

    if [ -s "$INVENTORY" ]; then
        jq -r '[.platform, .name, .clone_url, .web_url] | @tsv' "$INVENTORY" 2>/dev/null | \
            awk -F '\t' '!seen[$3]++' > "$TARGETS"
    else
        : > "$TARGETS"
    fi
}

repo_osint_clone_targets() {
    local REPO_DIR="$1"
    local TARGETS="$REPO_DIR/clone_targets.tsv"
    local CLONES_DIR="$REPO_DIR/clones"

    : > "$REPO_DIR/cloned.tsv"
    : > "$REPO_DIR/failed_clones.tsv"

    [ ! -s "$TARGETS" ] && return

    log "[8.4] Cloning public repositories..."
    head -n "$REPO_MAX_CLONES" "$TARGETS" | while IFS=$'\t' read -r PLATFORM NAME CLONE_URL WEB_URL; do
        [ -z "$CLONE_URL" ] && continue
        local SAFE_NAME
        SAFE_NAME=$(repo_osint_safe_name "${PLATFORM}_${NAME}")
        local DEST="$CLONES_DIR/$SAFE_NAME"

        if [ -d "$DEST/.git" ]; then
            echo -e "${PLATFORM}\t${NAME}\t${DEST}\t${WEB_URL}" >> "$REPO_DIR/cloned.tsv"
            continue
        fi

        if ! command -v git &>/dev/null; then
            warning "git not found, repo cloning skipped"
            break
        fi

        if network_run git clone --depth "$REPO_CLONE_DEPTH" "$CLONE_URL" "$DEST" >> "$OUTDIR/logs/master.log" 2>>"$OUTDIR/logs/errors.log"; then
            echo -e "${PLATFORM}\t${NAME}\t${DEST}\t${WEB_URL}" >> "$REPO_DIR/cloned.tsv"
        else
            echo -e "${PLATFORM}\t${NAME}\t${CLONE_URL}\t${WEB_URL}" >> "$REPO_DIR/failed_clones.tsv"
        fi
    done
}

repo_osint_scan_clones() {
    local REPO_DIR="$1"
    local CLONED="$REPO_DIR/cloned.tsv"
    local SCAN_DIR="$REPO_DIR/scan_reports"

    : > "$REPO_DIR/developer_emails.txt"
    : > "$REPO_DIR/domain_hits.txt"
    : > "$REPO_DIR/endpoint_hits.txt"
    : > "$REPO_DIR/high_signal_files.txt"
    : > "$REPO_DIR/secret_hits_gitleaks.jsonl"
    : > "$REPO_DIR/secret_hits_trufflehog.jsonl"

    [ ! -s "$CLONED" ] && return

    log "[8.5] Scanning cloned repositories for leaks..."
    while IFS=$'\t' read -r PLATFORM NAME DEST WEB_URL; do
        [ -z "$DEST" ] && continue
        [ ! -d "$DEST" ] && continue

        local SAFE_NAME
        SAFE_NAME=$(repo_osint_safe_name "${PLATFORM}_${NAME}")

        git -C "$DEST" log --format='%ae' 2>/dev/null | \
            grep -v '^$' | sort -u | sed "s|^|${NAME}\t|" >> "$REPO_DIR/developer_emails.txt" || :

        grep -RInF "$DOMAIN" "$DEST" 2>/dev/null | \
            sed "s|$DEST|$NAME|g" >> "$REPO_DIR/domain_hits.txt" || :

        {
            grep -RhoE "https?://[^[:space:]\"'<>)]+" "$DEST" 2>/dev/null
            grep -RhoE "/(api|graphql|graphiql|auth|oauth|internal|admin|v[0-9]+)[A-Za-z0-9._~!$&'()*+,;=:@%/?-]*" "$DEST" 2>/dev/null
        } | sort -u | sed "s|^|${NAME}\t|" >> "$REPO_DIR/endpoint_hits.txt" || :

        find "$DEST" -type f \( \
            -iname ".env" -o \
            -iname ".env.*" -o \
            -iname "*.tfvars" -o \
            -iname "*credentials*" -o \
            -iname "*secret*" -o \
            -path "*/.github/workflows/*" -o \
            -path "*/.gitlab-ci.yml" -o \
            -iname "docker-compose*.yml" -o \
            -iname "docker-compose*.yaml" \
        \) 2>/dev/null | sed "s|$DEST|$NAME|g" >> "$REPO_DIR/high_signal_files.txt" || :

        if [ "$REPO_GITLEAKS_MODE" -eq 1 ] && command -v gitleaks &>/dev/null; then
            local GITLEAKS_REPORT="$SCAN_DIR/${SAFE_NAME}_gitleaks.json"
            gitleaks detect --source "$DEST" --no-banner --report-format json --report-path "$GITLEAKS_REPORT" \
                >> "$OUTDIR/logs/master.log" 2>>"$OUTDIR/logs/errors.log" || true
            jq -c '.[]?' "$GITLEAKS_REPORT" 2>/dev/null >> "$REPO_DIR/secret_hits_gitleaks.jsonl" || :
        fi

        if [ "$REPO_TRUFFLEHOG_MODE" -eq 1 ] && command -v trufflehog &>/dev/null; then
            local TRUFFLEHOG_REPORT="$SCAN_DIR/${SAFE_NAME}_trufflehog.jsonl"
            trufflehog filesystem "$DEST" --json > "$TRUFFLEHOG_REPORT" 2>>"$OUTDIR/logs/errors.log" || \
            trufflehog git "file://$DEST" --json > "$TRUFFLEHOG_REPORT" 2>>"$OUTDIR/logs/errors.log" || true
            [ -s "$TRUFFLEHOG_REPORT" ] && cat "$TRUFFLEHOG_REPORT" >> "$REPO_DIR/secret_hits_trufflehog.jsonl"
        fi
    done < "$CLONED"

    sort -u "$REPO_DIR/developer_emails.txt" -o "$REPO_DIR/developer_emails.txt" 2>/dev/null || :
    sort -u "$REPO_DIR/domain_hits.txt" -o "$REPO_DIR/domain_hits.txt" 2>/dev/null || :
    sort -u "$REPO_DIR/endpoint_hits.txt" -o "$REPO_DIR/endpoint_hits.txt" 2>/dev/null || :
    sort -u "$REPO_DIR/high_signal_files.txt" -o "$REPO_DIR/high_signal_files.txt" 2>/dev/null || :
}

repo_osint_write_summary() {
    local REPO_DIR="$1"
    local DISCOVERED
    local CLONED
    local FAILED
    local GITLEAKS_HITS
    local TRUFFLEHOG_HITS
    local EMAILS
    local DOMAIN_HITS
    local ENDPOINTS

    DISCOVERED=$(wc -l < "$REPO_DIR/clone_targets.tsv" 2>/dev/null || echo 0)
    CLONED=$(wc -l < "$REPO_DIR/cloned.tsv" 2>/dev/null || echo 0)
    FAILED=$(wc -l < "$REPO_DIR/failed_clones.tsv" 2>/dev/null || echo 0)
    GITLEAKS_HITS=$(wc -l < "$REPO_DIR/secret_hits_gitleaks.jsonl" 2>/dev/null || echo 0)
    TRUFFLEHOG_HITS=$(wc -l < "$REPO_DIR/secret_hits_trufflehog.jsonl" 2>/dev/null || echo 0)
    EMAILS=$(wc -l < "$REPO_DIR/developer_emails.txt" 2>/dev/null || echo 0)
    DOMAIN_HITS=$(wc -l < "$REPO_DIR/domain_hits.txt" 2>/dev/null || echo 0)
    ENDPOINTS=$(wc -l < "$REPO_DIR/endpoint_hits.txt" 2>/dev/null || echo 0)

    cat > "$REPO_DIR/SUMMARY.md" << EOF
# Repository OSINT Summary

| Metric | Count |
|--------|-------|
| Repositories discovered | $DISCOVERED |
| Repositories cloned | $CLONED |
| Failed clones | $FAILED |
| Gitleaks hits | $GITLEAKS_HITS |
| TruffleHog hits | $TRUFFLEHOG_HITS |
| Developer emails | $EMAILS |
| Domain references | $DOMAIN_HITS |
| Endpoint hits | $ENDPOINTS |

## Important Files
- clone_targets.tsv
- cloned.tsv
- developer_emails.txt
- domain_hits.txt
- endpoint_hits.txt
- high_signal_files.txt
- secret_hits_gitleaks.jsonl
- secret_hits_trufflehog.jsonl
EOF

    local SECRET_TOTAL=$((GITLEAKS_HITS + TRUFFLEHOG_HITS))
    if [ "$SECRET_TOTAL" -gt 0 ]; then
        notify_vuln "high" "Repository OSINT found ${SECRET_TOTAL} secret-related hits for $DOMAIN"
    fi
}

run_repo_osint() {
    if [ "$REPO_OSINT_MODE" -ne 1 ]; then
        return
    fi

    local REPO_DIR="$OUTDIR/repos"
    mkdir -p "$REPO_DIR/clones" "$REPO_DIR/scan_reports"

    repo_osint_write_terms "$REPO_DIR"
    repo_osint_search_github "$REPO_DIR"
    repo_osint_search_gitlab "$REPO_DIR"
    repo_osint_build_inventory "$REPO_DIR"
    repo_osint_clone_targets "$REPO_DIR"
    repo_osint_scan_clones "$REPO_DIR"
    repo_osint_write_summary "$REPO_DIR"
}
