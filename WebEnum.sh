#!/bin/bash

# ============================================================
#   WebEnum v2.0 | Advanced Web Recon & Enumeration Tool
#   Author: shadowXg | Enhanced by Silent Programmer
# ============================================================

# ---------- COLORS ----------
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'
BOLD='\033[1m'

# ---------- CONFIG ----------
WORDLIST_DEFAULT="/usr/share/dirb/wordlists/common.txt"
WORDLIST_BIG="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
THREADS=20
OUTPUT_DIR="./webenum_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERBOSE=false
SCAN_ALL=false

# ---------- BANNER ----------
banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
 ██╗    ██╗███████╗██████╗ ███████╗███╗   ██╗██╗   ██╗███╗   ███╗
 ██║    ██║██╔════╝██╔══██╗██╔════╝████╗  ██║██║   ██║████╗ ████║
 ██║ █╗ ██║█████╗  ██████╔╝█████╗  ██╔██╗ ██║██║   ██║██╔████╔██║
 ██║███╗██║██╔══╝  ██╔══██╗██╔══╝  ██║╚██╗██║██║   ██║██║╚██╔╝██║
 ╚███╔███╔╝███████╗██████╔╝███████╗██║ ╚████║╚██████╔╝██║ ╚═╝ ██║
  ╚══╝╚══╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝
EOF
    echo -e "${RESET}"
    echo -e "${MAGENTA}${BOLD}  ╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${MAGENTA}${BOLD}  ║     WebEnum v2.0 | Advanced Web Recon & Enum Tool        ║${RESET}"
    echo -e "${MAGENTA}${BOLD}  ║          Author: shadowXg  |  Silent Programmer          ║${RESET}"
    echo -e "${MAGENTA}${BOLD}  ╚══════════════════════════════════════════════════════════╝${RESET}"
    echo -e "${RED}  ⚠  For authorized penetration testing only. Use responsibly.${RESET}\n"
}

# ---------- LOGGING ----------
log_info()    { echo -e "${CYAN}[*]${RESET} $1"; }
log_success() { echo -e "${GREEN}[+]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
log_error()   { echo -e "${RED}[-]${RESET} $1"; }
log_section() { echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; 
                echo -e "${BLUE}${BOLD}  $1${RESET}";
                echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

# ---------- DEPENDENCY CHECK ----------
check_deps() {
    log_section "🔍 Checking Dependencies"
    local deps=("nmap" "gobuster" "nikto" "whatweb" "curl" "whois")
    local missing=()

    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            log_success "$dep → ${GREEN}Found${RESET}"
        else
            log_warn "$dep → ${YELLOW}Not found (some scans will be skipped)${RESET}"
            missing+=("$dep")
        fi
    done

    # Optional tools
    for opt in "sqlmap" "wpscan" "sslscan" "lolcat"; do
        if command -v "$opt" &>/dev/null; then
            log_success "$opt → ${GREEN}Found (optional)${RESET}"
        else
            echo -e "  ${DIM}[~] $opt → Not installed (optional)${RESET}"
        fi
    done

    echo ""
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing: ${missing[*]}"
        log_warn "Install with: sudo apt install ${missing[*]}"
    fi
}

# ---------- SETUP OUTPUT DIR ----------
setup_output() {
    local target_safe=$(echo "$1" | tr '/:.' '_')
    OUTPUT_DIR="./webenum_${target_safe}_${TIMESTAMP}"
    mkdir -p "$OUTPUT_DIR"
    log_success "Output directory: ${GREEN}$OUTPUT_DIR${RESET}"
    # Start a master log
    MASTER_LOG="$OUTPUT_DIR/master_scan.log"
    echo "WebEnum v2.0 - Scan started: $(date)" > "$MASTER_LOG"
    echo "Target: $1" >> "$MASTER_LOG"
}

# ---------- WHOIS LOOKUP ----------
run_whois() {
    log_section "📋 WHOIS Lookup"
    if command -v whois &>/dev/null; then
        log_info "Running WHOIS on $TARGET_HOST..."
        whois "$TARGET_HOST" 2>/dev/null | tee "$OUTPUT_DIR/whois.txt" | head -30
        log_success "Full WHOIS saved → $OUTPUT_DIR/whois.txt"
    else
        log_warn "whois not installed, skipping."
    fi
}

# ---------- DNS RECON ----------
run_dns() {
    log_section "🌐 DNS Reconnaissance"
    log_info "Resolving DNS records for $TARGET_HOST..."
    {
        echo "=== A Records ==="; dig +short A "$TARGET_HOST"
        echo "=== MX Records ==="; dig +short MX "$TARGET_HOST"
        echo "=== NS Records ==="; dig +short NS "$TARGET_HOST"
        echo "=== TXT Records ==="; dig +short TXT "$TARGET_HOST"
        echo "=== CNAME Records ==="; dig +short CNAME "$TARGET_HOST"
    } 2>/dev/null | tee "$OUTPUT_DIR/dns_recon.txt"
    log_success "DNS recon saved → $OUTPUT_DIR/dns_recon.txt"
}

# ---------- NMAP SCAN ----------
run_nmap() {
    log_section "🔭 Nmap Port Scan"

    echo -e "${YELLOW}Select Nmap scan intensity:${RESET}"
    echo "  1) Quick Scan     (-T4 top 1000 ports)"
    echo "  2) Standard Scan  (-T4 -A all ports + service/OS detection)"
    echo "  3) Stealth Scan   (-sS -T2 SYN scan, slower)"
    echo "  4) Full Vuln Scan (-A --script vuln)"
    echo -n -e "${CYAN}Enter choice [1-4]: ${RESET}"
    read -r nmap_mode

    local nmap_out="$OUTPUT_DIR/nmap"
    log_info "Starting Nmap scan on $TARGET_IP..."

    case $nmap_mode in
        1)
            log_info "Running Quick Scan..."
            nmap -T4 -F -oA "$nmap_out" "$TARGET_IP" | tee "$nmap_out.txt"
            ;;
        2)
            log_info "Running Standard Deep Scan..."
            nmap -T4 -A -p- -sV -O -oA "$nmap_out" "$TARGET_IP" | tee "$nmap_out.txt"
            ;;
        3)
            log_info "Running Stealth SYN Scan..."
            nmap -sS -T2 -p- -oA "$nmap_out" "$TARGET_IP" | tee "$nmap_out.txt"
            ;;
        4)
            log_info "Running Full Scan + Vuln Scripts..."
            nmap -T4 -A -sV -O --script vuln -oA "$nmap_out" "$TARGET_IP" | tee "$nmap_out.txt"
            ;;
        *)
            log_warn "Invalid choice. Running Quick Scan."
            nmap -T4 -F -oA "$nmap_out" "$TARGET_IP" | tee "$nmap_out.txt"
            ;;
    esac

    log_success "Nmap results saved → $nmap_out.*"
}

# ---------- WHATWEB FINGERPRINT ----------
run_whatweb() {
    log_section "🕵️ Web Technology Fingerprint (WhatWeb)"
    if command -v whatweb &>/dev/null; then
        log_info "Fingerprinting $FULL_URL..."
        whatweb -v "$FULL_URL" 2>/dev/null | tee "$OUTPUT_DIR/whatweb.txt"
        log_success "WhatWeb results saved → $OUTPUT_DIR/whatweb.txt"
    else
        log_warn "whatweb not found, skipping."
    fi
}

# ---------- HTTP HEADERS ----------
run_headers() {
    log_section "📨 HTTP Header Analysis"
    log_info "Fetching headers from $FULL_URL..."
    curl -sk -I --max-time 10 "$FULL_URL" | tee "$OUTPUT_DIR/http_headers.txt"

    # Security header check
    echo -e "\n${YELLOW}Security Header Check:${RESET}"
    local headers_content
    headers_content=$(curl -sk -I --max-time 10 "$FULL_URL" 2>/dev/null)
    for h in "Strict-Transport-Security" "Content-Security-Policy" "X-Frame-Options" "X-XSS-Protection" "X-Content-Type-Options" "Referrer-Policy"; do
        if echo "$headers_content" | grep -qi "$h"; then
            echo -e "  ${GREEN}✔${RESET} $h"
        else
            echo -e "  ${RED}✘${RESET} $h ${DIM}(missing)${RESET}"
        fi
    done
    log_success "Headers saved → $OUTPUT_DIR/http_headers.txt"
}

# ---------- SSL/TLS CHECK ----------
run_ssl() {
    log_section "🔒 SSL/TLS Analysis"
    if command -v sslscan &>/dev/null; then
        log_info "Running sslscan on $TARGET_HOST..."
        sslscan "$TARGET_HOST" 2>/dev/null | tee "$OUTPUT_DIR/sslscan.txt"
        log_success "SSL scan saved → $OUTPUT_DIR/sslscan.txt"
    else
        log_info "Checking cert via openssl..."
        echo | openssl s_client -connect "$TARGET_HOST:443" -servername "$TARGET_HOST" 2>/dev/null \
            | openssl x509 -noout -text 2>/dev/null | grep -E "Subject:|Issuer:|Not Before:|Not After:" \
            | tee "$OUTPUT_DIR/ssl_cert.txt"
        log_success "SSL cert info saved → $OUTPUT_DIR/ssl_cert.txt"
    fi
}

# ---------- DIRECTORY ENUM ----------
run_gobuster() {
    log_section "📂 Directory & File Enumeration (Gobuster)"

    echo -e "${YELLOW}Select wordlist:${RESET}"
    echo "  1) Common (fast)    → $WORDLIST_DEFAULT"
    echo "  2) Medium (thorough) → $WORDLIST_BIG"
    echo "  3) Custom wordlist"
    echo -n -e "${CYAN}Enter choice [1-3]: ${RESET}"
    read -r wl_choice

    local wordlist
    case $wl_choice in
        1) wordlist="$WORDLIST_DEFAULT" ;;
        2) wordlist="$WORDLIST_BIG" ;;
        3)
            echo -n -e "${CYAN}Enter wordlist path: ${RESET}"
            read -r wordlist
            [[ ! -f "$wordlist" ]] && { log_error "File not found: $wordlist"; return; }
            ;;
        *) wordlist="$WORDLIST_DEFAULT" ;;
    esac

    echo -e "${YELLOW}Include file extensions? (e.g. php,html,txt) or press Enter to skip:${RESET}"
    echo -n -e "${CYAN}Extensions: ${RESET}"
    read -r exts

    local ext_flag=""
    [[ -n "$exts" ]] && ext_flag="-x $exts"

    log_info "Running Gobuster on $FULL_URL with $THREADS threads..."
    gobuster dir \
        -u "$FULL_URL" \
        -w "$wordlist" \
        -t "$THREADS" \
        $ext_flag \
        -o "$OUTPUT_DIR/gobuster.txt" \
        --no-error \
        -q 2>/dev/null | tee /dev/tty

    log_success "Gobuster results saved → $OUTPUT_DIR/gobuster.txt"
}

# ---------- NIKTO SCAN ----------
run_nikto() {
    log_section "🔎 Nikto Web Vulnerability Scanner"
    if command -v nikto &>/dev/null; then
        log_info "Running Nikto on $FULL_URL..."
        nikto -h "$FULL_URL" -o "$OUTPUT_DIR/nikto.txt" -Format txt 2>/dev/null | tee /dev/tty
        log_success "Nikto results saved → $OUTPUT_DIR/nikto.txt"
    else
        log_warn "nikto not found, skipping."
    fi
}

# ---------- SQLMAP (OPTIONAL) ----------
run_sqlmap() {
    log_section "💉 SQL Injection Test (SQLMap)"
    if command -v sqlmap &>/dev/null; then
        echo -n -e "${CYAN}Enter URL to test for SQLi (e.g. http://site.com/page?id=1): ${RESET}"
        read -r sqli_url
        log_info "Running SQLMap on $sqli_url..."
        sqlmap -u "$sqli_url" --batch --level=2 --risk=1 \
            --output-dir="$OUTPUT_DIR/sqlmap" 2>/dev/null | tee /dev/tty
        log_success "SQLMap results saved → $OUTPUT_DIR/sqlmap/"
    else
        log_warn "sqlmap not found. Install with: sudo apt install sqlmap"
    fi
}

# ---------- WPSCAN (WORDPRESS) ----------
run_wpscan() {
    log_section "📰 WordPress Scan (WPScan)"
    if command -v wpscan &>/dev/null; then
        log_info "Running WPScan on $FULL_URL..."
        wpscan --url "$FULL_URL" --enumerate u,p,t \
            --output "$OUTPUT_DIR/wpscan.txt" 2>/dev/null | tee /dev/tty
        log_success "WPScan results saved → $OUTPUT_DIR/wpscan.txt"
    else
        log_warn "wpscan not found. Install with: gem install wpscan"
    fi
}

# ---------- SUMMARY REPORT ----------
generate_report() {
    log_section "📄 Generating Summary Report"
    local report="$OUTPUT_DIR/SUMMARY_REPORT.txt"

    {
        echo "========================================"
        echo "  WebEnum v2.0 - Scan Summary Report"
        echo "========================================"
        echo "Target Host : $TARGET_HOST"
        echo "Target IP   : $TARGET_IP"
        echo "Protocol    : $PROTOCOL"
        echo "Full URL    : $FULL_URL"
        echo "Scan Date   : $(date)"
        echo "Output Dir  : $OUTPUT_DIR"
        echo ""
        echo "Files Generated:"
        ls -lh "$OUTPUT_DIR"/ | awk 'NR>1 {print "  "$NF" ("$5")"}'
        echo ""
        echo "========================================"
        echo "  Key Findings"
        echo "========================================"

        # Pull open ports from nmap
        if [[ -f "$OUTPUT_DIR/nmap.nmap" ]]; then
            echo "[NMAP] Open Ports:"
            grep "^[0-9].*open" "$OUTPUT_DIR/nmap.nmap" | sed 's/^/  /'
        fi

        # Pull interesting dirs from gobuster
        if [[ -f "$OUTPUT_DIR/gobuster.txt" ]]; then
            echo ""
            echo "[GOBUSTER] Interesting Paths:"
            grep "Status: 200\|Status: 301\|Status: 302" "$OUTPUT_DIR/gobuster.txt" | head -20 | sed 's/^/  /'
        fi

        # Nikto highlights
        if [[ -f "$OUTPUT_DIR/nikto.txt" ]]; then
            echo ""
            echo "[NIKTO] Vulnerabilities Found:"
            grep "OSVDB\|CVE\|+" "$OUTPUT_DIR/nikto.txt" | head -20 | sed 's/^/  /'
        fi

    } | tee "$report"

    echo ""
    log_success "Summary report saved → ${GREEN}$report${RESET}"
}

# ---------- SCAN MENU ----------
scan_menu() {
    log_section "🎯 Select Scans to Run"
    echo -e "${WHITE}Target: ${GREEN}$FULL_URL${RESET} (IP: ${CYAN}$TARGET_IP${RESET})\n"
    echo -e "${YELLOW}Available Scans:${RESET}"
    echo "  1) WHOIS Lookup"
    echo "  2) DNS Recon"
    echo "  3) Nmap Port Scan"
    echo "  4) WhatWeb Fingerprint"
    echo "  5) HTTP Header Analysis"
    echo "  6) SSL/TLS Check"
    echo "  7) Directory Enumeration (Gobuster)"
    echo "  8) Nikto Web Scanner"
    echo "  9) SQL Injection Test (SQLMap)"
    echo " 10) WordPress Scan (WPScan)"
    echo " 11) Run ALL scans"
    echo "  0) Exit"
    echo ""
    echo -e "${DIM}Tip: Enter multiple choices separated by spaces (e.g: 1 2 3 7)${RESET}"
    echo -n -e "${CYAN}Your choice(s): ${RESET}"
    read -r -a choices

    for choice in "${choices[@]}"; do
        case $choice in
            1)  run_whois ;;
            2)  run_dns ;;
            3)  run_nmap ;;
            4)  run_whatweb ;;
            5)  run_headers ;;
            6)  run_ssl ;;
            7)  run_gobuster ;;
            8)  run_nikto ;;
            9)  run_sqlmap ;;
            10) run_wpscan ;;
            11) run_whois; run_dns; run_nmap; run_whatweb; run_headers
                run_ssl; run_gobuster; run_nikto ;;
            0)  log_info "Exiting WebEnum. Stay ethical!"; exit 0 ;;
            *)  log_warn "Unknown option: $choice" ;;
        esac
    done

    generate_report
}

# ---------- INPUT COLLECTION ----------
collect_targets() {
    log_section "🎯 Target Configuration"

    echo -n -e "${CYAN}Enter Target IP or Hostname: ${RESET}"
    read -r TARGET_HOST

    # If it looks like an IP, use directly; else resolve
    if [[ "$TARGET_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        TARGET_IP="$TARGET_HOST"
    else
        log_info "Resolving $TARGET_HOST..."
        TARGET_IP=$(dig +short A "$TARGET_HOST" 2>/dev/null | head -1)
        if [[ -z "$TARGET_IP" ]]; then
            log_warn "Could not resolve IP for $TARGET_HOST. Using hostname as-is."
            TARGET_IP="$TARGET_HOST"
        else
            log_success "Resolved → $TARGET_IP"
        fi
    fi

    echo -n -e "${CYAN}Protocol [http/https] (default: http): ${RESET}"
    read -r proto_input
    PROTOCOL="${proto_input:-http}"

    FULL_URL="${PROTOCOL}://${TARGET_HOST}"

    echo ""
    log_success "Target set: ${GREEN}$FULL_URL${RESET}"
    log_success "IP address: ${GREEN}$TARGET_IP${RESET}"

    setup_output "$TARGET_HOST"
}

# ---------- MAIN ----------
main() {
    banner
    check_deps
    collect_targets
    scan_menu
}

main "$@"
