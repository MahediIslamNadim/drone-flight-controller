#======================= REPORT GENERATION =======================
generate_html_report() {
    phase_banner "GENERATING INTERACTIVE HTML REPORT"

    local REPORT_DIR="$OUTDIR/reports"
    local HTML_REPORT="$REPORT_DIR/report.html"
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # ── Collect all stats ──
    local SUB_COUNT ALIVE_COUNT PORT_COUNT URL_COUNT PARAM_COUNT VULN_COUNT
    local CRITICAL HIGH MEDIUM LOW INFO
    SUB_COUNT=$(wc -l < "$OUTDIR/subdomains/final_subs.txt" 2>/dev/null || echo 0)
    ALIVE_COUNT=$(wc -l < "$OUTDIR/alive/final_alive.txt" 2>/dev/null || echo 0)
    PORT_COUNT=$(wc -l < "$OUTDIR/ports/all_ports.txt" 2>/dev/null || echo 0)
    URL_COUNT=$(wc -l < "$OUTDIR/urls/all_urls.txt" 2>/dev/null || echo 0)
    PARAM_COUNT=$(wc -l < "$OUTDIR/urls/parameters.txt" 2>/dev/null || echo 0)
    VULN_COUNT=$(wc -l < "$OUTDIR/vulns/all_findings.txt" 2>/dev/null || echo 0)
    CRITICAL=$(grep -ic "\[critical\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); CRITICAL=$(( CRITICAL + 0 ))
    HIGH=$(grep -ic "\[high\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); HIGH=$(( HIGH + 0 ))
    MEDIUM=$(grep -ic "\[medium\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); MEDIUM=$(( MEDIUM + 0 ))
    LOW=$(grep -ic "\[low\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); LOW=$(( LOW + 0 ))
    INFO=$(grep -ic "\[info\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); INFO=$(( INFO + 0 ))

    local TAKEOVER TAKEOVER_ELIGIBLE DANGLING BYPASS CORS_ISSUES METHOD_BYPASS WEAK_CIPHERS
    TAKEOVER=$(wc -l < "$OUTDIR/takeover/nuclei_takeover.txt" 2>/dev/null || echo 0)
    TAKEOVER_ELIGIBLE=$(wc -l < "$OUTDIR/takeover/takeover_eligible.txt" 2>/dev/null || echo 0)
    DANGLING=$(wc -l < "$OUTDIR/takeover/dangling_cnames.txt" 2>/dev/null || echo 0)
    WEAK_CIPHERS=$(grep -c "WEAK\|RC4\|DES\|EXPORT\|NULL\|TLS 1\.0" "$OUTDIR/vulns/weak_ciphers.txt" 2>/dev/null); WEAK_CIPHERS=$(( WEAK_CIPHERS + 0 ))
    BYPASS=$(wc -l < "$OUTDIR/bypass/403_bypassed.txt" 2>/dev/null || echo 0)
    CORS_ISSUES=$(wc -l < "$OUTDIR/bypass/cors_manual.txt" 2>/dev/null || echo 0)
    METHOD_BYPASS=$(wc -l < "$OUTDIR/bypass/method_override.txt" 2>/dev/null || echo 0)

    local JS_SECRETS_NUCLEI JS_SECRETS_TH JS_SECRETS SOURCEMAPS SM_ENDPOINTS SM_CREDS
    JS_SECRETS_NUCLEI=$(wc -l < "$OUTDIR/urls/js_secrets_nuclei.txt" 2>/dev/null || echo 0)
    JS_SECRETS_TH=$(wc -l < "$OUTDIR/urls/trufflehog.jsonl" 2>/dev/null || echo 0)
    JS_SECRETS=$(( JS_SECRETS_NUCLEI + JS_SECRETS_TH ))
    SOURCEMAPS=$(wc -l < "$OUTDIR/urls/sourcemaps/valid_sourcemaps.txt" 2>/dev/null || echo 0)
    SM_ENDPOINTS=$(wc -l < "$OUTDIR/urls/sourcemap_endpoints.txt" 2>/dev/null || echo 0)
    SM_CREDS=$(wc -l < "$OUTDIR/urls/sourcemap_credentials_hits.txt" 2>/dev/null || echo 0)

    local BLOCK_SIGNALS WAF_HITS
    BLOCK_SIGNALS=$(wc -l < "$OUTDIR/alive/block_signals.txt" 2>/dev/null || echo 0)
    WAF_HITS=$(wc -l < "$OUTDIR/alive/waf_detected.txt" 2>/dev/null || echo 0)

    local REPO_DISCOVERED REPO_CLONED REPO_GITLEAKS REPO_TRUFFLEHOG
    REPO_DISCOVERED=$(wc -l < "$OUTDIR/repos/clone_targets.tsv" 2>/dev/null || echo 0)
    REPO_CLONED=$(wc -l < "$OUTDIR/repos/cloned.tsv" 2>/dev/null || echo 0)
    REPO_GITLEAKS=$(wc -l < "$OUTDIR/repos/secret_hits_gitleaks.jsonl" 2>/dev/null || echo 0)
    REPO_TRUFFLEHOG=$(wc -l < "$OUTDIR/repos/secret_hits_trufflehog.jsonl" 2>/dev/null || echo 0)

    # Phase 12 advanced stats
    local JWT_COUNT OAUTH_COUNT IDOR_COUNT APIKEY_COUNT SENSITIVE_COUNT
    JWT_COUNT=$(wc -l < "$OUTDIR/advanced/jwt_findings.txt" 2>/dev/null || echo 0)
    OAUTH_COUNT=$(wc -l < "$OUTDIR/advanced/oauth_findings.txt" 2>/dev/null || echo 0)
    IDOR_COUNT=$(wc -l < "$OUTDIR/advanced/idor_candidates.txt" 2>/dev/null || echo 0)
    APIKEY_COUNT=$(wc -l < "$OUTDIR/advanced/apikey_hits.txt" 2>/dev/null || echo 0)
    SENSITIVE_COUNT=$(wc -l < "$OUTDIR/advanced/sensitive_endpoints.txt" 2>/dev/null || echo 0)

    # Cloud findings
    local CLOUD_S3 CLOUD_GCS CLOUD_AZ CLOUD_FB CLOUD_DO CLOUD_R2 CLOUD_TOTAL
    CLOUD_S3=$(grep -c "200-OPEN" "$OUTDIR/cloud/s3_found.txt" 2>/dev/null); CLOUD_S3=$(( CLOUD_S3 + 0 ))
    CLOUD_GCS=$(grep -c "200-OPEN" "$OUTDIR/cloud/gcs_found.txt" 2>/dev/null); CLOUD_GCS=$(( CLOUD_GCS + 0 ))
    CLOUD_AZ=$(grep -c "200-OPEN" "$OUTDIR/cloud/azure_found.txt" 2>/dev/null); CLOUD_AZ=$(( CLOUD_AZ + 0 ))
    CLOUD_FB=$(grep -c "200-OPEN" "$OUTDIR/cloud/firebase_found.txt" 2>/dev/null); CLOUD_FB=$(( CLOUD_FB + 0 ))
    CLOUD_DO=$(grep -c "200-OPEN" "$OUTDIR/cloud/do_spaces_found.txt" 2>/dev/null); CLOUD_DO=$(( CLOUD_DO + 0 ))
    CLOUD_R2=$(grep -c "200-OPEN" "$OUTDIR/cloud/r2_found.txt" 2>/dev/null); CLOUD_R2=$(( CLOUD_R2 + 0 ))
    CLOUD_TOTAL=$(( CLOUD_S3 + CLOUD_GCS + CLOUD_AZ + CLOUD_FB + CLOUD_DO + CLOUD_R2 ))

    # Scan mode label
    local SCAN_MODE="Aggressive"
    [ "$STEALTH_MODE" -eq 1 ]    && SCAN_MODE="Stealth"
    [ "$RESPECTFUL_MODE" -eq 1 ] && SCAN_MODE="Respectful"
    [ "$WAF_AWARE" -eq 1 ]       && SCAN_MODE="${SCAN_MODE}+WAF"

    # Phase timing from file — use jq to build valid JSON (avoids trailing comma issues)
    local PHASE_TIMING_JSON="{}"
    if [ -f "$OUTDIR/logs/phase_durations.env" ]; then
        PHASE_TIMING_JSON=$(
            jq -Rn '[inputs | split("=") | select(length==2) |
                {(.[0]): (.[1] | tonumber? // 0)}] | add // {}' \
                < "$OUTDIR/logs/phase_durations.env" 2>/dev/null
        ) || PHASE_TIMING_JSON="{}"
    fi

    cat > "$HTML_REPORT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Bug Hunter v${VERSION} — $DOMAIN</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
  :root {
    --bg:#0a0e17;--bg2:#111827;--bg3:#1a2236;--border:#1e3a5f;
    --accent:#00d4ff;--accent2:#7c3aed;
    --red:#ef4444;--orange:#f97316;--yellow:#eab308;
    --green:#22c55e;--blue:#3b82f6;--text:#e2e8f0;--muted:#64748b;
    --critical:#dc2626;--high:#ea580c;--medium:#ca8a04;--low:#16a34a;--info:#2563eb;
  }
  [data-theme="light"] {
    --bg:#f0f4f8;--bg2:#ffffff;--bg3:#e8edf5;--border:#c5d5e8;
    --accent:#0066cc;--accent2:#6d28d9;--text:#1e293b;--muted:#64748b;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--bg);color:var(--text);font-family:'Courier New',monospace;min-height:100vh;transition:background .3s,color .3s}
  body::before{content:'';position:fixed;inset:0;
    background-image:linear-gradient(rgba(0,212,255,.03) 1px,transparent 1px),linear-gradient(90deg,rgba(0,212,255,.03) 1px,transparent 1px);
    background-size:40px 40px;pointer-events:none;z-index:0}
  .container{position:relative;z-index:1;max-width:1500px;margin:0 auto;padding:20px}

  /* ── HEADER ── */
  .header{background:linear-gradient(135deg,#0a0e17,#1a0533 50%,#0a1628);border:1px solid var(--border);border-radius:12px;padding:40px;margin-bottom:20px;position:relative;overflow:hidden}
  .header::after{content:'';position:absolute;top:-50%;right:-20%;width:500px;height:500px;background:radial-gradient(circle,rgba(124,58,237,.15),transparent 70%);pointer-events:none}
  .logo{font-size:26px;font-weight:900;letter-spacing:2px;background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
  .version-badge{background:rgba(0,212,255,.1);border:1px solid var(--accent);color:var(--accent);padding:3px 10px;border-radius:20px;font-size:11px;letter-spacing:1px}
  .target-domain{font-size:34px;font-weight:900;color:white;letter-spacing:-1px;margin-top:16px}
  .target-domain span{color:var(--accent)}
  .scan-meta{display:flex;gap:20px;margin-top:10px;flex-wrap:wrap}
  .scan-meta-item{display:flex;align-items:center;gap:6px;color:var(--muted);font-size:12px}
  .dot{width:6px;height:6px;border-radius:50%;background:var(--accent)}

  /* ── TOOLBAR ── */
  .toolbar{display:flex;gap:12px;align-items:center;margin-bottom:20px;flex-wrap:wrap}
  .search-box{flex:1;min-width:220px;background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:10px 14px;color:var(--text);font-family:inherit;font-size:13px;outline:none}
  .search-box:focus{border-color:var(--accent)}
  .btn{background:var(--bg2);border:1px solid var(--border);color:var(--text);padding:9px 16px;border-radius:8px;cursor:pointer;font-family:inherit;font-size:12px;transition:border-color .2s,background .2s}
  .btn:hover{border-color:var(--accent);background:rgba(0,212,255,.05)}
  .btn.active{border-color:var(--accent);color:var(--accent)}

  /* ── STATS GRID ── */
  .stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:14px;margin-bottom:20px}
  .stat-card{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:18px;position:relative;overflow:hidden;transition:transform .2s,border-color .2s;cursor:default}
  .stat-card:hover{transform:translateY(-2px);border-color:var(--accent)}
  .stat-card::before{content:'';position:absolute;top:0;left:0;right:0;height:2px}
  .stat-card.critical::before{background:var(--critical)}
  .stat-card.high::before{background:var(--high)}
  .stat-card.medium::before{background:var(--medium)}
  .stat-card.low::before{background:var(--low)}
  .stat-card.info::before{background:var(--accent)}
  .stat-card.neutral::before{background:var(--accent2)}
  .stat-label{font-size:10px;text-transform:uppercase;letter-spacing:1px;color:var(--muted);margin-bottom:6px}
  .stat-value{font-size:32px;font-weight:900;line-height:1}
  .stat-value.critical{color:var(--critical)}.stat-value.high{color:var(--high)}
  .stat-value.medium{color:var(--medium)}.stat-value.low{color:var(--low)}
  .stat-value.info{color:var(--accent)}.stat-value.neutral{color:white}
  .stat-sub{font-size:10px;color:var(--muted);margin-top:5px}

  /* ── SECTIONS ── */
  .section{background:var(--bg2);border:1px solid var(--border);border-radius:10px;margin-bottom:16px;overflow:hidden}
  .section-header{padding:14px 22px;background:var(--bg3);border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;cursor:pointer;user-select:none}
  .section-header:hover{background:rgba(0,212,255,.05)}
  .section-title{font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;display:flex;align-items:center;gap:8px}
  .section-count{background:rgba(0,212,255,.1);border:1px solid rgba(0,212,255,.3);color:var(--accent);padding:2px 9px;border-radius:12px;font-size:11px}
  .section-body{padding:18px 22px;display:none}
  .section-body.open{display:block}
  .chevron{transition:transform .3s;color:var(--muted)}
  .chevron.open{transform:rotate(180deg)}

  /* ── CHARTS ── */
  .charts-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;margin-bottom:20px}
  .chart-card{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:18px}
  .chart-title{font-size:11px;text-transform:uppercase;letter-spacing:1px;color:var(--muted);margin-bottom:14px}
  .chart-wrapper{position:relative;height:190px}

  /* ── FINDINGS ── */
  .findings-list{display:flex;flex-direction:column;gap:7px}
  .finding-item{background:var(--bg3);border:1px solid var(--border);border-radius:7px;padding:11px 14px;font-size:11px;font-family:'Courier New',monospace;display:flex;align-items:flex-start;gap:10px;transition:border-color .2s}
  .finding-item:hover{border-color:var(--accent)}
  .finding-item.hidden{display:none}
  .sev-badge{padding:2px 7px;border-radius:4px;font-size:9px;font-weight:700;text-transform:uppercase;flex-shrink:0}
  .sev-badge.critical{background:rgba(220,38,38,.2);color:#fca5a5;border:1px solid #dc2626}
  .sev-badge.high{background:rgba(234,88,12,.2);color:#fdba74;border:1px solid #ea580c}
  .sev-badge.medium{background:rgba(202,138,4,.2);color:#fde68a;border:1px solid #ca8a04}
  .sev-badge.low{background:rgba(22,163,74,.2);color:#86efac;border:1px solid #16a34a}
  .sev-badge.info{background:rgba(37,99,235,.2);color:#93c5fd;border:1px solid #2563eb}
  .finding-text{color:var(--text);line-height:1.5;word-break:break-all}
  /* ── GROUPED FINDINGS ── */
  .vuln-group{background:var(--bg3);border:1px solid var(--border);border-radius:8px;margin-bottom:8px;overflow:hidden}
  .vuln-group-header{display:flex;align-items:center;gap:10px;padding:10px 14px;cursor:pointer;user-select:none}
  .vuln-group-header:hover{background:var(--bg2)}
  .vuln-group-name{font-size:12px;font-weight:600;color:var(--text);font-family:'Courier New',monospace;flex:1}
  .vuln-host-count{font-size:10px;color:var(--muted);background:var(--bg);border:1px solid var(--border);border-radius:10px;padding:1px 8px}
  .vuln-group-hosts{display:none;border-top:1px solid var(--border);padding:8px 14px;font-size:11px;font-family:'Courier New',monospace;color:var(--muted);line-height:1.8}
  .vuln-group-hosts.open{display:block}
  .vuln-group-hosts a{color:var(--accent);text-decoration:none}
  .vuln-group-hosts a:hover{text-decoration:underline}

  /* ── CODE BLOCK ── */
  .code-block{background:#060b14;border:1px solid var(--border);border-radius:8px;padding:14px;font-family:'Courier New',monospace;font-size:11px;color:#7dd3fc;overflow-x:auto;max-height:280px;overflow-y:auto;line-height:1.7}
  .code-block .cmd{color:#22c55e}.code-block .comment{color:var(--muted)}

  /* ── HOSTS GRID ── */
  .hosts-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:9px}
  .host-card{background:var(--bg3);border:1px solid var(--border);border-radius:7px;padding:10px;font-size:11px;transition:border-color .2s}
  .host-card:hover{border-color:var(--accent)}
  .host-url{color:var(--accent);text-decoration:none}.host-url:hover{text-decoration:underline}

  /* ── PROGRESS BARS ── */
  .pb-wrap{display:flex;align-items:center;gap:10px;margin-bottom:9px}
  .pb-label{font-size:11px;color:var(--muted);min-width:75px;text-transform:capitalize}
  .pb-track{flex:1;height:7px;background:var(--bg3);border-radius:4px;overflow:hidden}
  .pb-fill{height:100%;border-radius:4px;transition:width .8s ease}
  .pb-fill.critical{background:var(--critical)}.pb-fill.high{background:var(--high)}
  .pb-fill.medium{background:var(--medium)}.pb-fill.low{background:var(--low)}
  .pb-fill.info{background:var(--info)}
  .pb-count{font-size:11px;color:var(--text);min-width:38px;text-align:right}

  /* ── TABLE ── */
  table{width:100%;border-collapse:collapse;font-size:12px}
  th{background:var(--bg3);color:var(--muted);text-transform:uppercase;font-size:10px;letter-spacing:1px;padding:10px 12px;text-align:left;border-bottom:1px solid var(--border)}
  td{padding:9px 12px;border-bottom:1px solid rgba(30,58,95,.4);color:var(--text);word-break:break-all}
  tr:hover td{background:rgba(0,212,255,.03)}

  /* ── FOOTER ── */
  .footer{text-align:center;padding:22px;color:var(--muted);font-size:11px;border-top:1px solid var(--border);margin-top:36px}
  .footer a{color:var(--accent);text-decoration:none}

  /* ── SCROLLBAR ── */
  ::-webkit-scrollbar{width:5px;height:5px}
  ::-webkit-scrollbar-track{background:var(--bg)}
  ::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}
  ::-webkit-scrollbar-thumb:hover{background:var(--accent)}

  @keyframes pulse-red{0%,100%{box-shadow:0 0 0 0 rgba(220,38,38,.4)}50%{box-shadow:0 0 0 8px rgba(220,38,38,0)}}
  .has-critical{animation:pulse-red 2s ease-in-out infinite}
  @media(max-width:768px){.charts-grid{grid-template-columns:1fr}.stat-value{font-size:24px}.target-domain{font-size:22px}}
</style>
</head>
<body>
<div class="container">

<!-- HEADER -->
<div class="header">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:16px">
    <div>
      <div class="logo">◉ ULTIMATE BUG HUNTER</div>
      <div style="margin-top:6px;display:flex;gap:7px;flex-wrap:wrap">
        <span class="version-badge">v${VERSION}</span>
        <span class="version-badge" style="border-color:var(--accent2);color:var(--accent2)">${CODENAME}</span>
        <span class="version-badge" style="border-color:var(--green);color:var(--green)">NCT EDITION</span>
      </div>
    </div>
    <div style="display:flex;gap:10px;align-items:center">
      <button class="btn" id="themeBtn" onclick="toggleTheme()">☀️ Light</button>
      <button class="btn" onclick="exportJSON()">⬇ Export JSON</button>
    </div>
  </div>
  <div class="target-domain">🎯 <span>$DOMAIN</span></div>
  <div class="scan-meta">
    <div class="scan-meta-item"><div class="dot"></div>$TIMESTAMP</div>
    <div class="scan-meta-item"><div class="dot"></div>Threads: $THREADS</div>
    <div class="scan-meta-item"><div class="dot"></div>Mode: $SCAN_MODE</div>
    <div class="scan-meta-item"><div class="dot"></div>WAF Signals: $BLOCK_SIGNALS</div>
    <div class="scan-meta-item"><div class="dot"></div>Output: $OUTDIR</div>
  </div>
</div>

<!-- TOOLBAR -->
<div class="toolbar">
  <input class="search-box" type="text" id="searchBox" placeholder="🔍 Search findings, hosts, paths..." oninput="filterAll()">
  <button class="btn" onclick="filterSev('critical')">💀 Critical</button>
  <button class="btn" onclick="filterSev('high')">🔴 High</button>
  <button class="btn" onclick="filterSev('medium')">🟡 Medium</button>
  <button class="btn" onclick="filterSev('all')">⬜ All</button>
  <button class="btn" onclick="expandAll()">↕ Expand All</button>
  <button class="btn" onclick="collapseAll()">↕ Collapse All</button>
</div>

<!-- STATS GRID -->
<div class="stats-grid">
  <div class="stat-card neutral"><div class="stat-label">Subdomains</div><div class="stat-value neutral">$SUB_COUNT</div><div class="stat-sub">Enumerated</div></div>
  <div class="stat-card info"><div class="stat-label">Alive Hosts</div><div class="stat-value info">$ALIVE_COUNT</div><div class="stat-sub">HTTP/HTTPS</div></div>
  <div class="stat-card neutral"><div class="stat-label">Open Ports</div><div class="stat-value neutral">$PORT_COUNT</div><div class="stat-sub">Discovered</div></div>
  <div class="stat-card neutral"><div class="stat-label">URLs</div><div class="stat-value neutral">$URL_COUNT</div><div class="stat-sub">$PARAM_COUNT with params</div></div>
  <div class="stat-card critical $([ "$CRITICAL" -gt 0 ] && echo "has-critical")"><div class="stat-label">Critical</div><div class="stat-value critical">$CRITICAL</div><div class="stat-sub">Vulnerabilities</div></div>
  <div class="stat-card high"><div class="stat-label">High</div><div class="stat-value high">$HIGH</div><div class="stat-sub">Vulnerabilities</div></div>
  <div class="stat-card medium"><div class="stat-label">Medium</div><div class="stat-value medium">$MEDIUM</div><div class="stat-sub">Vulnerabilities</div></div>
  <div class="stat-card low"><div class="stat-label">Low / Info</div><div class="stat-value low">$LOW</div><div class="stat-sub">$INFO informational</div></div>
  <div class="stat-card neutral"><div class="stat-label">Takeovers</div><div class="stat-value $([ "$TAKEOVER_ELIGIBLE" -gt 0 ] && echo "critical" || [ "$TAKEOVER" -gt 0 ] && echo "high" || echo "neutral")">$TAKEOVER_ELIGIBLE</div><div class="stat-sub">Eligible | $DANGLING dangling | $TAKEOVER nuclei</div></div>
  <div class="stat-card neutral"><div class="stat-label">Weak TLS</div><div class="stat-value $([ "$WEAK_CIPHERS" -gt 0 ] && echo "medium" || echo "neutral")">$WEAK_CIPHERS</div><div class="stat-sub">RC4/DES/EXPORT/TLS1.0</div></div>
  <div class="stat-card neutral"><div class="stat-label">403 Bypassed</div><div class="stat-value $([ "$BYPASS" -gt 0 ] && echo "medium" || echo "neutral")">$BYPASS</div><div class="stat-sub">+$CORS_ISSUES CORS | $METHOD_BYPASS method</div></div>
  <div class="stat-card neutral"><div class="stat-label">JS Secrets</div><div class="stat-value $([ "$JS_SECRETS" -gt 0 ] && echo "high" || echo "neutral")">$JS_SECRETS</div><div class="stat-sub">$SOURCEMAPS source maps | $SM_CREDS cred hits</div></div>
  <div class="stat-card neutral"><div class="stat-label">Open Cloud</div><div class="stat-value $([ "$CLOUD_TOTAL" -gt 0 ] && echo "high" || echo "neutral")">$CLOUD_TOTAL</div><div class="stat-sub">S3:$CLOUD_S3 GCS:$CLOUD_GCS AZ:$CLOUD_AZ FB:$CLOUD_FB</div></div>
  <div class="stat-card neutral"><div class="stat-label">JWT / OAuth</div><div class="stat-value $([ "$JWT_COUNT" -gt 0 ] && echo "medium" || echo "neutral")">$JWT_COUNT</div><div class="stat-sub">$OAUTH_COUNT oauth endpoints</div></div>
  <div class="stat-card neutral"><div class="stat-label">IDOR Candidates</div><div class="stat-value $([ "$IDOR_COUNT" -gt 0 ] && echo "medium" || echo "neutral")">$IDOR_COUNT</div><div class="stat-sub">Object-ref URLs</div></div>
  <div class="stat-card neutral"><div class="stat-label">API Keys Hit</div><div class="stat-value $([ "$APIKEY_COUNT" -gt 0 ] && echo "critical" || echo "neutral")">$APIKEY_COUNT</div><div class="stat-sub">Validated keys</div></div>
  <div class="stat-card neutral"><div class="stat-label">Sensitive Files</div><div class="stat-value $([ "$SENSITIVE_COUNT" -gt 0 ] && echo "high" || echo "neutral")">$SENSITIVE_COUNT</div><div class="stat-sub">Exposed endpoints</div></div>
  <div class="stat-card neutral"><div class="stat-label">Repo OSINT</div><div class="stat-value neutral">$REPO_DISCOVERED</div><div class="stat-sub">$REPO_CLONED cloned | $REPO_GITLEAKS GL | $REPO_TRUFFLEHOG TH</div></div>
  <div class="stat-card neutral"><div class="stat-label">Total Vulns</div><div class="stat-value neutral">$VULN_COUNT</div><div class="stat-sub">All severities</div></div>
</div>

<!-- CHARTS -->
<div class="charts-grid">
  <div class="chart-card">
    <div class="chart-title">📊 Vulnerability Severity</div>
    <div class="chart-wrapper"><canvas id="severityChart"></canvas></div>
  </div>
  <div class="chart-card">
    <div class="chart-title">📈 Discovery Overview</div>
    <div class="chart-wrapper"><canvas id="overviewChart"></canvas></div>
  </div>
  <div class="chart-card">
    <div class="chart-title">⏱ Phase Timing (seconds)</div>
    <div class="chart-wrapper"><canvas id="timingChart"></canvas></div>
  </div>
  <div class="chart-card">
    <div class="chart-title">☁️ Cloud Asset Findings</div>
    <div class="chart-wrapper"><canvas id="cloudChart"></canvas></div>
  </div>
</div>

<!-- SEVERITY BREAKDOWN -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🎯</span> Severity Breakdown</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count">$VULN_COUNT findings</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body open">
    <div class="pb-wrap"><span class="pb-label">Critical</span><div class="pb-track"><div class="pb-fill critical" style="width:$(awk "BEGIN{printf \"%.1f\", ($VULN_COUNT>0?$CRITICAL/$VULN_COUNT*100:0)}")%"></div></div><span class="pb-count">$CRITICAL</span></div>
    <div class="pb-wrap"><span class="pb-label">High</span><div class="pb-track"><div class="pb-fill high" style="width:$(awk "BEGIN{printf \"%.1f\", ($VULN_COUNT>0?$HIGH/$VULN_COUNT*100:0)}")%"></div></div><span class="pb-count">$HIGH</span></div>
    <div class="pb-wrap"><span class="pb-label">Medium</span><div class="pb-track"><div class="pb-fill medium" style="width:$(awk "BEGIN{printf \"%.1f\", ($VULN_COUNT>0?$MEDIUM/$VULN_COUNT*100:0)}")%"></div></div><span class="pb-count">$MEDIUM</span></div>
    <div class="pb-wrap"><span class="pb-label">Low</span><div class="pb-track"><div class="pb-fill low" style="width:$(awk "BEGIN{printf \"%.1f\", ($VULN_COUNT>0?$LOW/$VULN_COUNT*100:0)}")%"></div></div><span class="pb-count">$LOW</span></div>
    <div class="pb-wrap"><span class="pb-label">Info</span><div class="pb-track"><div class="pb-fill info" style="width:$(awk "BEGIN{printf \"%.1f\", ($VULN_COUNT>0?$INFO/$VULN_COUNT*100:0)}")%"></div></div><span class="pb-count">$INFO</span></div>
  </div>
</div>

<!-- CRITICAL FINDINGS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>💀</span> Critical Findings</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count" style="border-color:var(--critical);color:var(--critical)">$CRITICAL</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body open">
$(if grep -qi "\[critical\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null; then
    grep -i "\[critical\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null | \
    awk -F'[][]' '{tmpl=$2; line=$0; count[tmpl]++; if(length(hosts[tmpl])<2000) hosts[tmpl]=hosts[tmpl]"\n"line}
    END{for(t in count) print count[t]"\t"t"\t"hosts[t]}' | sort -rn | head -40 | \
    while IFS=$'\t' read -r CNT TMPL HOSTLINES; do
        STMPL=$(printf '%s' "$TMPL" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
        GID="crit_$(printf '%s' "$TMPL" | tr -dc '[:alnum:]' | head -c 20)"
        echo "<div class='vuln-group'>"
        echo "  <div class='vuln-group-header' onclick=\"var h=document.getElementById('$GID');h.classList.toggle('open')\">"
        echo "    <span class='sev-badge critical'>CRIT</span>"
        echo "    <span class='vuln-group-name'>$STMPL</span>"
        echo "    <span class='vuln-host-count'>${CNT} host$([ "$CNT" -gt 1 ] && echo 's' || true)</span>"
        echo "  </div>"
        echo "  <div class='vuln-group-hosts' id='$GID'>"
        printf '%s' "$HOSTLINES" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | grep -v '^$' | \
            while IFS= read -r HL; do echo "    $HL<br>"; done
        echo "  </div>"
        echo "</div>"
    done
else
    echo "<div style='color:var(--muted);font-size:12px;padding:10px'>✓ No critical findings</div>"
fi)
  </div>
</div>

<!-- HIGH FINDINGS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🔴</span> High Findings</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count" style="border-color:var(--high);color:var(--high)">$HIGH</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
$(if grep -qi "\[high\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null; then
    grep -i "\[high\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null | \
    awk -F'[][]' '{tmpl=$2; line=$0; count[tmpl]++; if(length(hosts[tmpl])<2000) hosts[tmpl]=hosts[tmpl]"\n"line}
    END{for(t in count) print count[t]"\t"t"\t"hosts[t]}' | sort -rn | head -40 | \
    while IFS=$'\t' read -r CNT TMPL HOSTLINES; do
        STMPL=$(printf '%s' "$TMPL" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
        GID="high_$(printf '%s' "$TMPL" | tr -dc '[:alnum:]' | head -c 20)"
        echo "<div class='vuln-group'>"
        echo "  <div class='vuln-group-header' onclick=\"var h=document.getElementById('$GID');h.classList.toggle('open')\">"
        echo "    <span class='sev-badge high'>HIGH</span>"
        echo "    <span class='vuln-group-name'>$STMPL</span>"
        echo "    <span class='vuln-host-count'>${CNT} host$([ "$CNT" -gt 1 ] && echo 's' || true)</span>"
        echo "  </div>"
        echo "  <div class='vuln-group-hosts' id='$GID'>"
        printf '%s' "$HOSTLINES" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | grep -v '^$' | \
            while IFS= read -r HL; do echo "    $HL<br>"; done
        echo "  </div>"
        echo "</div>"
    done
else
    echo "<div style='color:var(--muted);font-size:12px;padding:10px'>✓ No high findings</div>"
fi)
  </div>
</div>

<!-- MEDIUM FINDINGS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🟡</span> Medium Findings</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count" style="border-color:var(--medium);color:var(--medium)">$MEDIUM</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
$(if grep -qi "\[medium\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null; then
    grep -i "\[medium\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null | \
    awk -F'[][]' '{tmpl=$2; line=$0; count[tmpl]++; if(length(hosts[tmpl])<2000) hosts[tmpl]=hosts[tmpl]"\n"line}
    END{for(t in count) print count[t]"\t"t"\t"hosts[t]}' | sort -rn | head -30 | \
    while IFS=$'\t' read -r CNT TMPL HOSTLINES; do
        STMPL=$(printf '%s' "$TMPL" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
        GID="med_$(printf '%s' "$TMPL" | tr -dc '[:alnum:]' | head -c 20)"
        echo "<div class='vuln-group'>"
        echo "  <div class='vuln-group-header' onclick=\"var h=document.getElementById('$GID');h.classList.toggle('open')\">"
        echo "    <span class='sev-badge medium'>MED</span>"
        echo "    <span class='vuln-group-name'>$STMPL</span>"
        echo "    <span class='vuln-host-count'>${CNT} host$([ "$CNT" -gt 1 ] && echo 's' || true)</span>"
        echo "  </div>"
        echo "  <div class='vuln-group-hosts' id='$GID'>"
        printf '%s' "$HOSTLINES" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | grep -v '^$' | \
            while IFS= read -r HL; do echo "    $HL<br>"; done
        echo "  </div>"
        echo "</div>"
    done
else
    echo "<div style='color:var(--muted);font-size:12px;padding:10px'>✓ No medium findings</div>"
fi)
  </div>
</div>

<!-- CLOUD FINDINGS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>☁️</span> Cloud Asset Findings</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count" style="border-color:$([ "$CLOUD_TOTAL" -gt 0 ] && echo 'var(--high)' || echo 'var(--accent)');color:$([ "$CLOUD_TOTAL" -gt 0 ] && echo 'var(--high)' || echo 'var(--accent)')">$CLOUD_TOTAL open</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
    <table>
      <tr><th>Provider</th><th>Open</th><th>Details</th></tr>
      <tr><td>AWS S3</td><td style="color:$([ "$CLOUD_S3" -gt 0 ] && echo '#ea580c' || echo 'var(--muted)')">$CLOUD_S3</td><td>$(grep "200-OPEN" "$OUTDIR/cloud/s3_found.txt" 2>/dev/null | head -5 | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>Google GCS</td><td style="color:$([ "$CLOUD_GCS" -gt 0 ] && echo '#ea580c' || echo 'var(--muted)')">$CLOUD_GCS</td><td>$(grep "200-OPEN" "$OUTDIR/cloud/gcs_found.txt" 2>/dev/null | head -5 | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>Azure Blob</td><td style="color:$([ "$CLOUD_AZ" -gt 0 ] && echo '#ea580c' || echo 'var(--muted)')">$CLOUD_AZ</td><td>$(grep "200-OPEN" "$OUTDIR/cloud/azure_found.txt" 2>/dev/null | head -5 | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>Firebase</td><td style="color:$([ "$CLOUD_FB" -gt 0 ] && echo '#dc2626' || echo 'var(--muted)')">$CLOUD_FB</td><td>$(grep "200-OPEN" "$OUTDIR/cloud/firebase_found.txt" 2>/dev/null | head -5 | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>DO Spaces</td><td style="color:$([ "$CLOUD_DO" -gt 0 ] && echo '#ea580c' || echo 'var(--muted)')">$CLOUD_DO</td><td>$(grep "200-OPEN" "$OUTDIR/cloud/do_spaces_found.txt" 2>/dev/null | head -5 | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>Cloudflare R2</td><td style="color:$([ "$CLOUD_R2" -gt 0 ] && echo '#ea580c' || echo 'var(--muted)')">$CLOUD_R2</td><td>$(grep "200-OPEN" "$OUTDIR/cloud/r2_found.txt" 2>/dev/null | head -5 | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | tr '\n' ' ' || echo "—")</td></tr>
    </table>
  </div>
</div>

<!-- ADVANCED VULNS (Phase 12) -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🔑</span> Advanced Vulnerabilities (JWT / OAuth / IDOR / API Keys)</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count">$((JWT_COUNT+OAUTH_COUNT+IDOR_COUNT+APIKEY_COUNT+SENSITIVE_COUNT)) findings</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
    <table>
      <tr><th>Category</th><th>Count</th><th>File</th></tr>
      <tr><td>JWT Findings</td><td style="color:$([ "$JWT_COUNT" -gt 0 ] && echo 'var(--high)' || echo 'var(--muted)')">$JWT_COUNT</td><td><code>advanced/jwt_findings.txt</code></td></tr>
      <tr><td>OAuth / SSO</td><td style="color:$([ "$OAUTH_COUNT" -gt 0 ] && echo 'var(--medium)' || echo 'var(--muted)')">$OAUTH_COUNT</td><td><code>advanced/oauth_findings.txt</code></td></tr>
      <tr><td>IDOR Candidates</td><td style="color:$([ "$IDOR_COUNT" -gt 0 ] && echo 'var(--medium)' || echo 'var(--muted)')">$IDOR_COUNT</td><td><code>advanced/idor_candidates.txt</code></td></tr>
      <tr><td>Validated API Keys</td><td style="color:$([ "$APIKEY_COUNT" -gt 0 ] && echo 'var(--critical)' || echo 'var(--muted)')">$APIKEY_COUNT</td><td><code>advanced/apikey_hits.txt</code></td></tr>
      <tr><td>Sensitive Endpoints</td><td style="color:$([ "$SENSITIVE_COUNT" -gt 0 ] && echo 'var(--high)' || echo 'var(--muted)')">$SENSITIVE_COUNT</td><td><code>advanced/sensitive_endpoints.txt</code></td></tr>
    </table>
    $([ "$APIKEY_COUNT" -gt 0 ] && {
        echo "<div style='margin-top:14px'><div class='findings-list'>"
        head -10 "$OUTDIR/advanced/apikey_hits.txt" 2>/dev/null | while IFS= read -r L; do
            CL=$(printf '%s' "$L" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
            echo "<div class='finding-item'><span class='sev-badge critical'>KEY</span><span class='finding-text'>$CL</span></div>"
        done
        echo "</div></div>"
    } || :)
  </div>
</div>

<!-- BYPASS RESULTS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🔓</span> Bypass Results (403 / CORS / Method Override)</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count">$((BYPASS+CORS_ISSUES+METHOD_BYPASS)) total</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
    <table>
      <tr><th>Type</th><th>Count</th><th>Sample</th></tr>
      <tr><td>403 Bypassed</td><td>$BYPASS</td><td>$(head -3 "$OUTDIR/bypass/403_bypassed.txt" 2>/dev/null | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>CORS Misconfig</td><td>$CORS_ISSUES</td><td>$(head -3 "$OUTDIR/bypass/cors_manual.txt" 2>/dev/null | tr '\n' ' ' || echo "—")</td></tr>
      <tr><td>Method Override</td><td>$METHOD_BYPASS</td><td>$(head -3 "$OUTDIR/bypass/method_override.txt" 2>/dev/null | tr '\n' ' ' || echo "—")</td></tr>
    </table>
  </div>
</div>

<!-- SOURCE MAPS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🗺️</span> JavaScript Source Maps</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count">$SOURCEMAPS maps | $SM_ENDPOINTS endpoints | $SM_CREDS cred hits</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
    $([ "$SM_CREDS" -gt 0 ] && {
        echo "<div class='findings-list' style='margin-bottom:14px'>"
        head -10 "$OUTDIR/urls/sourcemap_credentials_hits.txt" 2>/dev/null | while IFS= read -r L; do
            CL=$(printf '%s' "$L" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
            echo "<div class='finding-item'><span class='sev-badge high'>CRED</span><span class='finding-text'>$CL</span></div>"
        done
        echo "</div>"
    } || echo "<div style='color:var(--muted);font-size:12px;margin-bottom:10px'>No credential hits in source maps</div>")
    <div class="code-block">
$(head -20 "$OUTDIR/urls/sourcemap_endpoints.txt" 2>/dev/null | while IFS= read -r L; do
    printf '%s\n' "$L" | sed 's/</\&lt;/g;s/>/\&gt;/g'
done || echo "No endpoints extracted from source maps")
    </div>
  </div>
</div>

<!-- REPOSITORY OSINT -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🐙</span> Repository OSINT</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count">$REPO_DISCOVERED repos | $((REPO_GITLEAKS+REPO_TRUFFLEHOG)) secret hits</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
    <table>
      <tr><th>Metric</th><th>Count</th></tr>
      <tr><td>Repos discovered</td><td>$REPO_DISCOVERED</td></tr>
      <tr><td>Repos cloned</td><td>$REPO_CLONED</td></tr>
      <tr><td>Gitleaks hits</td><td style="color:$([ "$REPO_GITLEAKS" -gt 0 ] && echo 'var(--high)' || echo 'var(--muted)')">$REPO_GITLEAKS</td></tr>
      <tr><td>TruffleHog hits</td><td style="color:$([ "$REPO_TRUFFLEHOG" -gt 0 ] && echo 'var(--high)' || echo 'var(--muted)')">$REPO_TRUFFLEHOG</td></tr>
    </table>
    $([ -s "$OUTDIR/repos/SUMMARY.md" ] && {
        echo "<div class='code-block' style='margin-top:12px'>"
        cat "$OUTDIR/repos/SUMMARY.md" 2>/dev/null | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' | head -30
        echo "</div>"
    } || :)
  </div>
</div>

<!-- ALIVE HOSTS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>🌐</span> Alive Hosts</div>
    <div style="display:flex;align-items:center;gap:10px"><span class="section-count">$ALIVE_COUNT</span><span class="chevron">▼</span></div>
  </div>
  <div class="section-body">
    <div class="hosts-grid">
$(head -60 "$OUTDIR/alive/final_alive.txt" 2>/dev/null | while IFS= read -r URL; do
    CLEAN=$(printf '%s' "$URL" | sed 's/&/\&amp;/g;s/"/\&quot;/g;s/'"'"'/\&#39;/g;s/</\&lt;/g;s/>/\&gt;/g')
    # Only allow http/https in href — prevents javascript: protocol injection
    if [[ "$URL" =~ ^https?:// ]]; then
        echo "<div class='host-card'><a class='host-url' href='$CLEAN' target='_blank' rel='noopener noreferrer'>$CLEAN</a></div>"
    else
        echo "<div class='host-card'><span class='host-url'>$CLEAN</span></div>"
    fi
done)
    </div>
    $([ "$ALIVE_COUNT" -gt 60 ] && echo "<div style='color:var(--muted);font-size:11px;margin-top:10px'>... and $((ALIVE_COUNT-60)) more — see alive/final_alive.txt</div>" || :)
  </div>
</div>

<!-- TECHNOLOGY STACK -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>⚙️</span> Technology Stack</div>
    <span class="chevron">▼</span>
  </div>
  <div class="section-body">
    <div class="code-block">
$(cat "$OUTDIR/alive/tech_summary.txt" 2>/dev/null | head -40 | \
    sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' || echo "No technology data")
    </div>
  </div>
</div>

<!-- NEXT STEPS -->
<div class="section">
  <div class="section-header" onclick="toggle(this)">
    <div class="section-title"><span>⚡</span> Next Steps — Manual Testing Commands</div>
    <span class="chevron">▼</span>
  </div>
  <div class="section-body">
    <div class="code-block">
<span class="comment"># ── Critical review ──</span>
<span class="cmd">grep</span> -i '\[critical\]' $OUTDIR/vulns/all_findings.txt

<span class="comment"># ── XSS / SQLi ──</span>
<span class="cmd">dalfox</span> file $OUTDIR/urls/parameters.txt --skip-bav -o xss.txt
<span class="cmd">sqlmap</span> -m $OUTDIR/urls/parameters.txt --batch --level 3 --risk 2 --dbs

<span class="comment"># ── JWT testing ──</span>
<span class="cmd">cat</span> $OUTDIR/advanced/jwt_findings.txt
<span class="cmd">cat</span> $OUTDIR/advanced/apikey_hits.txt  # ← VALIDATE IMMEDIATELY

<span class="comment"># ── IDOR manual testing ──</span>
<span class="cmd">cat</span> $OUTDIR/advanced/idor_candidates.txt

<span class="comment"># ── Cloud open buckets ──</span>
<span class="cmd">cat</span> $OUTDIR/cloud/all_open.txt
<span class="cmd">aws</span> s3 ls s3://BUCKET_NAME --no-sign-request

<span class="comment"># ── Source map secrets ──</span>
<span class="cmd">cat</span> $OUTDIR/urls/sourcemap_credentials_hits.txt

<span class="comment"># ── Repository secrets ──</span>
<span class="cmd">cat</span> $OUTDIR/repos/secret_hits_gitleaks.jsonl | jq .
<span class="cmd">cat</span> $OUTDIR/repos/secret_hits_trufflehog.jsonl | jq .

<span class="comment"># ── Takeover candidates ──</span>
<span class="cmd">cat</span> $OUTDIR/takeover/dangling_cnames.txt

<span class="comment"># ── CORS issues ──</span>
<span class="cmd">cat</span> $OUTDIR/bypass/cors_manual.txt

<span class="comment"># ── Sensitive endpoints ──</span>
<span class="cmd">cat</span> $OUTDIR/advanced/sensitive_endpoints.txt
    </div>
  </div>
</div>

<!-- FOOTER -->
<div class="footer">
  <div>Generated by <strong>Ultimate Bug Hunter v${VERSION} (${CODENAME})</strong></div>
  <div style="margin-top:7px"><strong>NexCore Technologies</strong> · <a href="https://nexcoreltd.com">nexcoreltd.com</a> · Sylhet, Bangladesh</div>
  <div style="margin-top:7px;color:#374151">⚠️ For authorized security testing only. Unauthorized use is illegal.</div>
</div>
</div>

<script>
// ── Data for export ──
const scanData = {
  target: "$DOMAIN", timestamp: "$TIMESTAMP", version: "${VERSION}",
  stats: {
    subdomains:$SUB_COUNT, alive:$ALIVE_COUNT, ports:$PORT_COUNT,
    urls:$URL_COUNT, params:$PARAM_COUNT, total_vulns:$VULN_COUNT,
    critical:$CRITICAL, high:$HIGH, medium:$MEDIUM, low:$LOW, info:$INFO,
    takeover:$TAKEOVER, bypass:$BYPASS, cors:$CORS_ISSUES,
    js_secrets:$JS_SECRETS, source_maps:$SOURCEMAPS,
    cloud_open:$CLOUD_TOTAL, jwt:$JWT_COUNT, idor:$IDOR_COUNT,
    api_keys:$APIKEY_COUNT, sensitive:$SENSITIVE_COUNT,
    repo_discovered:$REPO_DISCOVERED, repo_cloned:$REPO_CLONED
  },
  timings: ${PHASE_TIMING_JSON}
};

// ── Theme toggle ──
function toggleTheme() {
  const html = document.documentElement;
  const isDark = !html.getAttribute('data-theme');
  html.setAttribute('data-theme', isDark ? 'light' : '');
  document.getElementById('themeBtn').textContent = isDark ? '🌙 Dark' : '☀️ Light';
}

// ── Section toggle ──
function toggle(header) {
  const body = header.nextElementSibling;
  const chev = header.querySelector('.chevron');
  body.classList.toggle('open');
  chev.classList.toggle('open');
}
function expandAll()   { document.querySelectorAll('.section-body').forEach(b=>{b.classList.add('open');b.previousElementSibling.querySelector('.chevron').classList.add('open')}); }
function collapseAll() { document.querySelectorAll('.section-body').forEach(b=>{b.classList.remove('open');b.previousElementSibling.querySelector('.chevron').classList.remove('open')}); }

// ── Search + severity filter ──
let currentSev = 'all';
function filterAll() {
  const q = document.getElementById('searchBox').value.toLowerCase();
  document.querySelectorAll('.finding-item').forEach(el => {
    const txt = el.textContent.toLowerCase();
    const sev = el.dataset.sev || '';
    const matchSev = currentSev === 'all' || sev === currentSev;
    const matchQ   = !q || txt.includes(q);
    el.classList.toggle('hidden', !(matchSev && matchQ));
  });
}
function filterSev(sev) {
  currentSev = sev;
  document.querySelectorAll('.toolbar .btn').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  filterAll();
}

// ── Export JSON ──
function exportJSON() {
  const blob = new Blob([JSON.stringify(scanData, null, 2)], {type:'application/json'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'bughunter_${DOMAIN}_${TIMESTAMP//[: ]/_}.json';
  a.click();
}

// ── Charts ──
const CHART_OPTS = { responsive:true, maintainAspectRatio:false,
  plugins:{ legend:{ labels:{ color:'#94a3b8', font:{family:'Courier New',size:10}, padding:10 } } } };

// Severity donut
new Chart(document.getElementById('severityChart'), {
  type: 'doughnut',
  data: { labels:['Critical','High','Medium','Low','Info'],
    datasets:[{ data:[$CRITICAL,$HIGH,$MEDIUM,$LOW,$INFO],
      backgroundColor:['#dc2626','#ea580c','#ca8a04','#16a34a','#2563eb'],
      borderColor:'#111827', borderWidth:3, hoverOffset:8 }] },
  options: { ...CHART_OPTS }
});

// Discovery bar
new Chart(document.getElementById('overviewChart'), {
  type: 'bar',
  data: { labels:['Subs','Alive','Ports','URLs÷100','Params÷10','Vulns'],
    datasets:[{ label:'Count',
      data:[$SUB_COUNT,$ALIVE_COUNT,$PORT_COUNT,
            Math.round($URL_COUNT/100), Math.round($PARAM_COUNT/10), $VULN_COUNT],
      backgroundColor:['#7c3aed','#00d4ff','#22c55e','#f97316','#eab308','#ef4444'],
      borderRadius:5, borderSkipped:false }] },
  options: { ...CHART_OPTS, plugins:{legend:{display:false}},
    scales:{ x:{grid:{color:'rgba(255,255,255,.05)'}, ticks:{color:'#94a3b8',font:{family:'Courier New',size:9}}},
             y:{grid:{color:'rgba(255,255,255,.05)'}, ticks:{color:'#94a3b8',font:{family:'Courier New',size:9}}} } }
});

// Phase timing bar
const timings = scanData.timings;
const phaseLabels = Object.keys(timings).map(k=>k.replace('phase_','Ph'));
const phaseData   = Object.values(timings);
new Chart(document.getElementById('timingChart'), {
  type: 'bar',
  data: { labels: phaseLabels.length ? phaseLabels : ['No data'],
    datasets:[{ label:'Seconds', data: phaseData.length ? phaseData : [0],
      backgroundColor:'rgba(0,212,255,.6)', borderColor:'#00d4ff', borderWidth:1, borderRadius:4 }] },
  options: { ...CHART_OPTS, indexAxis:'y', plugins:{legend:{display:false}},
    scales:{ x:{grid:{color:'rgba(255,255,255,.05)'}, ticks:{color:'#94a3b8',font:{family:'Courier New',size:9}}},
             y:{grid:{color:'rgba(255,255,255,.05)'}, ticks:{color:'#94a3b8',font:{family:'Courier New',size:9}}} } }
});

// Cloud assets polar
new Chart(document.getElementById('cloudChart'), {
  type: 'polarArea',
  data: { labels:['AWS S3','GCS','Azure','Firebase','DO Spaces','CF R2'],
    datasets:[{ data:[$CLOUD_S3,$CLOUD_GCS,$CLOUD_AZ,$CLOUD_FB,$CLOUD_DO,$CLOUD_R2],
      backgroundColor:['rgba(255,153,0,.7)','rgba(66,133,244,.7)','rgba(0,164,239,.7)',
                       'rgba(255,196,0,.7)','rgba(0,116,212,.7)','rgba(245,130,31,.7)'],
      borderColor:'#111827', borderWidth:2 }] },
  options: { ...CHART_OPTS }
});
</script>
</body>
</html>
HTMLEOF

    success "HTML Report: $HTML_REPORT"

    # ── Markdown summary ──
    cat > "$REPORT_DIR/SUMMARY.md" << MDEOF
# 🎯 Bug Hunter v${VERSION} — $DOMAIN

**Date:** $TIMESTAMP | **Version:** $VERSION ($CODENAME)

## Stats
| Metric | Count |
|--------|-------|
| Subdomains | $SUB_COUNT |
| Alive Hosts | $ALIVE_COUNT |
| Open Ports | $PORT_COUNT |
| URLs | $URL_COUNT |
| Parameters | $PARAM_COUNT |
| **Critical** | **$CRITICAL** |
| **High** | **$HIGH** |
| Medium | $MEDIUM |
| Low | $LOW |
| Info | $INFO |
| Total Findings | $VULN_COUNT |
| Takeover Candidates | $TAKEOVER |
| 403 Bypassed | $BYPASS |
| CORS Issues | $CORS_ISSUES |
| Method Bypass | $METHOD_BYPASS |
| JS Secrets | $JS_SECRETS |
| Source Maps | $SOURCEMAPS |
| SM Endpoints | $SM_ENDPOINTS |
| SM Credential Hits | $SM_CREDS |
| Cloud Open (total) | $CLOUD_TOTAL |
| JWT Findings | $JWT_COUNT |
| IDOR Candidates | $IDOR_COUNT |
| Validated API Keys | $APIKEY_COUNT |
| Sensitive Endpoints | $SENSITIVE_COUNT |
| Repo Inventory | $REPO_DISCOVERED |
| Repo Cloned | $REPO_CLONED |
| Repo Gitleaks Hits | $REPO_GITLEAKS |
| Repo TruffleHog Hits | $REPO_TRUFFLEHOG |
| WAF Detections | $WAF_HITS |
| Block Signals | $BLOCK_SIGNALS |
| Scan Mode | $SCAN_MODE |

## Output
\`\`\`
$OUTDIR/
├── subdomains/final_subs.txt
├── alive/final_alive.txt
├── ports/all_ports.txt
├── urls/{all_urls,parameters,js_files}.txt
├── urls/sourcemap_{endpoints,credentials_hits}.txt
├── api/{api_found,graphql_introspection}.txt
├── cloud/{s3,gcs,azure,firebase,do_spaces,r2}_found.txt
├── cloud/all_open.txt
├── bypass/{403_bypassed,cors_manual,method_override}.txt
├── injections/{dalfox_xss,lfi,ssrf,open_redirect}.txt
├── vulns/{all_findings,nuclei_cves}.txt
├── advanced/{jwt_findings,apikey_hits,idor_candidates,sensitive_endpoints}.txt
├── repos/{SUMMARY.md,secret_hits_gitleaks.jsonl,secret_hits_trufflehog.jsonl}
└── reports/report.html ← Interactive Report
\`\`\`

> ⚠️ Authorized testing only
MDEOF

    success "REPORTS DONE — Open $HTML_REPORT in browser"
    notify "✅ Scan COMPLETE: $DOMAIN | Critical: $CRITICAL | High: $HIGH | Cloud: $CLOUD_TOTAL | APIkeys: $APIKEY_COUNT | Total: $VULN_COUNT" "🎉"
    echo ""
}

#======================= FINAL SUMMARY =======================
print_final_summary() {
    local TOTAL_END
    TOTAL_END=$(date +%s)
    local TOTAL_DURATION=$(( TOTAL_END - SCAN_START_TIME ))
    local HOURS=$(( TOTAL_DURATION / 3600 ))
    local MINS=$(( TOTAL_DURATION % 3600 / 60 ))
    local SECS=$(( TOTAL_DURATION % 60 ))

    local SUB ALIVE PORTS URLS VULNS CRITICAL HIGH CLOUD_TOTAL ADV_KEYS
    SUB=$(wc -l < "$OUTDIR/subdomains/final_subs.txt" 2>/dev/null || echo 0)
    ALIVE=$(wc -l < "$OUTDIR/alive/final_alive.txt" 2>/dev/null || echo 0)
    PORTS=$(wc -l < "$OUTDIR/ports/all_ports.txt" 2>/dev/null || echo 0)
    URLS=$(wc -l < "$OUTDIR/urls/all_urls.txt" 2>/dev/null || echo 0)
    VULNS=$(wc -l < "$OUTDIR/vulns/all_findings.txt" 2>/dev/null || echo 0)
    CRITICAL=$(grep -ic "\[critical\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); CRITICAL=$(( CRITICAL + 0 ))
    HIGH=$(grep -ic "\[high\]" "$OUTDIR/vulns/all_findings.txt" 2>/dev/null); HIGH=$(( HIGH + 0 ))
    CLOUD_TOTAL=$(wc -l < "$OUTDIR/cloud/all_open.txt" 2>/dev/null || echo 0)
    ADV_KEYS=$(wc -l < "$OUTDIR/advanced/apikey_hits.txt" 2>/dev/null || echo 0)

    echo -e "\n${GREEN}"
    cat << 'DONEEOF'
  ███╗   ███╗██╗███████╗███████╗██╗ ██████╗ ███╗   ██╗
  ████╗ ████║██║██╔════╝██╔════╝██║██╔═══██╗████╗  ██║
  ██╔████╔██║██║███████╗███████╗██║██║   ██║██╔██╗ ██║
  ██║╚██╔╝██║██║╚════██║╚════██║██║██║   ██║██║╚██╗██║
  ██║ ╚═╝ ██║██║███████║███████║██║╚██████╔╝██║ ╚████║
  ╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
                     COMPLETE
DONEEOF
    echo -e "${NC}"

    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${GREEN}         🎯 ULTIMATE BUG HUNTER v${VERSION} — MISSION COMPLETE       ${WHITE}║${NC}"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${WHITE}║${CYAN}  %-64s${WHITE}║${NC}\n" "Target:    $DOMAIN"
    printf "${WHITE}║${CYAN}  %-64s${WHITE}║${NC}\n" "Duration:  ${HOURS}h ${MINS}m ${SECS}s"
    printf "${WHITE}║${CYAN}  %-64s${WHITE}║${NC}\n" "Output:    $OUTDIR"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${WHITE}║${BLUE}  %-64s${WHITE}║${NC}\n" "Subdomains:  $SUB"
    printf "${WHITE}║${BLUE}  %-64s${WHITE}║${NC}\n" "Alive Hosts: $ALIVE"
    printf "${WHITE}║${BLUE}  %-64s${WHITE}║${NC}\n" "Open Ports:  $PORTS"
    printf "${WHITE}║${BLUE}  %-64s${WHITE}║${NC}\n" "URLs:        $URLS"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${WHITE}║${RED}  %-64s${WHITE}║${NC}\n" "CRITICAL:    $CRITICAL  ← PATCH IMMEDIATELY"
    printf "${WHITE}║${YELLOW}  %-64s${WHITE}║${NC}\n" "HIGH:        $HIGH"
    printf "${WHITE}║${CYAN}  %-64s${WHITE}║${NC}\n" "Total Vulns: $VULNS"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${WHITE}║${MAGENTA}  %-64s${WHITE}║${NC}\n" "Open Cloud:  $CLOUD_TOTAL buckets/assets"
    printf "${WHITE}║${MAGENTA}  %-64s${WHITE}║${NC}\n" "API Keys:    $ADV_KEYS validated keys found"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}║${GREEN}  📄 Report: $OUTDIR/reports/report.html${WHITE}║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}  ⚡ grep -i '\\[critical\\]' $OUTDIR/vulns/all_findings.txt${NC}"
    echo -e "${CYAN}  ⚡ cat $OUTDIR/advanced/apikey_hits.txt${NC}"
    echo -e "${CYAN}  ⚡ cat $OUTDIR/cloud/all_open.txt${NC}"
    echo -e "${CYAN}  ⚡ open $OUTDIR/reports/report.html${NC}"
    echo ""
    echo -e "${GRAY}  Powered by NCT · nexcoreltd.com${NC}"
    echo ""
}
