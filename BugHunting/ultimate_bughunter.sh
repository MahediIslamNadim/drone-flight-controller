#!/bin/bash
# shellcheck disable=SC1090,SC2034
set -uo pipefail   # nounset + pipefail only; NOT -e (phases return non-zero intentionally)
#===============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── PATH FIXUP: preserve user tool dirs when running as root via sudo ──────
# Detect the real user who called sudo (or current user if not sudo)
_REAL_USER="${SUDO_USER:-${USER:-$(logname 2>/dev/null)}}"
_REAL_HOME=$(getent passwd "$_REAL_USER" 2>/dev/null | cut -d: -f6)
[ -z "$_REAL_HOME" ] && _REAL_HOME="$HOME"

export PATH="\
${_REAL_HOME}/go/bin:\
${_REAL_HOME}/.local/bin:\
${_REAL_HOME}/.cargo/bin:\
${_REAL_HOME}/.npm-global/bin:\
/root/go/bin:\
/usr/local/go/bin:\
/usr/local/bin:\
${PATH}"

# Also export GOPATH so go tools can find their dependencies
export GOPATH="${_REAL_HOME}/go"
export HOME="${_REAL_HOME}"
# ───────────────────────────────────────────────────────────────────────────

source "$DIR/modules/config.sh"

ENV_FILE="$DIR/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

source "$DIR/modules/utils.sh"
source "$DIR/modules/phase_1_subdomain.sh"
source "$DIR/modules/phase_2_alive.sh"
source "$DIR/modules/phase_3_port.sh"
source "$DIR/modules/phase_4_url.sh"
source "$DIR/modules/js_analysis.sh"
source "$DIR/modules/phase_5_api.sh"
source "$DIR/modules/phase_6_cloud.sh"
source "$DIR/modules/phase_7_takeover.sh"
source "$DIR/modules/phase_8_dorking.sh"
source "$DIR/modules/repo_osint.sh"
source "$DIR/modules/phase_9_vuln.sh"
source "$DIR/modules/phase_10_injections.sh"
source "$DIR/modules/phase_11_bypass.sh"
source "$DIR/modules/phase_12_advanced_vulns.sh"
source "$DIR/modules/phase_13_oob.sh"
source "$DIR/modules/phase_14_network_recon.sh"
source "$DIR/modules/phase_15_injections2.sh"
source "$DIR/modules/phase_16_graphql.sh"
source "$DIR/modules/phase_17_websocket.sh"
source "$DIR/modules/phase_18_smuggling.sh"
source "$DIR/modules/phase_19_intelligence.sh"
source "$DIR/modules/phase_20_infrastructure.sh"
source "$DIR/modules/phase_21_ai_analysis.sh"
source "$DIR/modules/phase_22_cve_correlation.sh"
source "$DIR/modules/monitor.sh"
source "$DIR/modules/report.sh"

#======================= MAIN =======================
SCAN_START_TIME=$(date +%s)
RUNNER_PATH="$DIR/ultimate_bughunter.sh"

parse_args "$@"
banner
check_root
check_dependencies
setup_environment
prepare_axiom_mode
prepare_respectful_mode
prepare_monitor_mode
notify "Scan started on $DOMAIN — v$VERSION $CODENAME" "🚀"

if [ "$PARALLEL_MODE" -eq 1 ]; then
    # Run independent phases in parallel
    timed_phase phase_1 phase_1_subdomain_enum
    timed_phase phase_2 phase_2_alive_check
    # Phase 3, 4 can run in parallel after 2
    timed_phase phase_3 phase_3_port_scan   &
    timed_phase phase_4 phase_4_url_discovery &
    wait
    load_phase_durations
    # Phase 5, 6, 7, 8 in parallel
    timed_phase phase_5 phase_5_api_discovery &
    timed_phase phase_6 phase_6_cloud_discovery &
    timed_phase phase_7 phase_7_subdomain_takeover &
    timed_phase phase_8 phase_8_dorking &
    wait
    load_phase_durations
    # Phase 9–12 sequentially (depend on earlier phases)
    timed_phase phase_9  phase_9_vuln_scan
    timed_phase phase_10 phase_10_injections
    timed_phase phase_11 phase_11_bypass
    timed_phase phase_12 phase_12_advanced_vulns
    # Phase 13–16 can run in parallel (OOB, network recon, injections2, graphql)
    timed_phase phase_13 phase_13_oob_testing      &
    timed_phase phase_14 phase_14_network_recon    &
    timed_phase phase_15 phase_15_injections2      &
    timed_phase phase_16 phase_16_graphql          &
    wait
    load_phase_durations
    # Phase 17–20 in parallel
    timed_phase phase_17 phase_17_websocket        &
    timed_phase phase_18 phase_18_smuggling        &
    timed_phase phase_19 phase_19_intelligence     &
    timed_phase phase_20 phase_20_infrastructure   &
    wait
    load_phase_durations
    # Phase 21–22 sequentially (AI depends on all findings; CVE after versions extracted)
    timed_phase phase_21 phase_21_ai_analysis
    timed_phase phase_22 phase_22_cve_correlation
else
    # Sequential
    timed_phase phase_1  phase_1_subdomain_enum
    timed_phase phase_2  phase_2_alive_check
    timed_phase phase_3  phase_3_port_scan
    timed_phase phase_4  phase_4_url_discovery
    timed_phase phase_5  phase_5_api_discovery
    timed_phase phase_6  phase_6_cloud_discovery
    timed_phase phase_7  phase_7_subdomain_takeover
    timed_phase phase_8  phase_8_dorking
    timed_phase phase_9  phase_9_vuln_scan
    timed_phase phase_10 phase_10_injections
    timed_phase phase_11 phase_11_bypass
    timed_phase phase_12 phase_12_advanced_vulns
    timed_phase phase_13 phase_13_oob_testing
    timed_phase phase_14 phase_14_network_recon
    timed_phase phase_15 phase_15_injections2
    timed_phase phase_16 phase_16_graphql
    timed_phase phase_17 phase_17_websocket
    timed_phase phase_18 phase_18_smuggling
    timed_phase phase_19 phase_19_intelligence
    timed_phase phase_20 phase_20_infrastructure
    timed_phase phase_21 phase_21_ai_analysis
    timed_phase phase_22 phase_22_cve_correlation
fi

generate_html_report
run_monitoring_diff
print_final_summary
