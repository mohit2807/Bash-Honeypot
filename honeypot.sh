                                                                                                                                                                                                                                                                                                                                                                  honeypot.sh                                                                                                                                                                                                                                                                                                                                                                               
#!/bin/bash

#############################################
# Simple SSH Honeypot (Fancy Output Version)
# Tools: bash, netcat, Linux utilities
#############################################

HONEYPOT_PORT=2222
LOG_DIR="./honeypot_logs"
CREDS_LOG="$LOG_DIR/credentials.txt"
CMDS_LOG="$LOG_DIR/commands.txt"
IPS_LOG="$LOG_DIR/ip_addresses.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

#############################################
# Setup Logs
#############################################
setup() {
    echo -e "${GREEN}Setting up honeypot...${NC}"

    mkdir -p "$LOG_DIR"

    echo "# SSH Honeypot - Captured Credentials" > "$CREDS_LOG"
    echo "# Format: [Timestamp] IP | Username | Password" >> "$CREDS_LOG"
    echo "----------------------------------------" >> "$CREDS_LOG"

    echo "# SSH Honeypot - Executed Commands" > "$CMDS_LOG"
    echo "# Format: [Timestamp] IP | Command" >> "$CMDS_LOG"
    echo "----------------------------------------" >> "$CMDS_LOG"

    echo "# SSH Honeypot - IP Addresses" > "$IPS_LOG"
    echo "# Format: [Timestamp] IP Address" >> "$IPS_LOG"
    echo "----------------------------------------" >> "$IPS_LOG"

    echo -e "${GREEN}✓ Setup complete!${NC}"
}

#############################################
# Logger
#############################################
log_it() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $2" >> "$1"
}

#############################################
# Fake Shell
#############################################
fake_shell() {
    local ip="$1"
    local user="$2"

    # Fake virtual filesystem (stored in memory)
    declare -gA FAKE_FS
    FAKE_FS["Desktop"]=1
    FAKE_FS["Documents"]=1
    FAKE_FS["Downloads"]=1
    FAKE_FS["Music"]=1
    FAKE_FS["Pictures"]=1
    FAKE_FS["Videos"]=1

    echo ""
    echo "Welcome to Ubuntu 22.04 LTS"
    echo "Last login: $(date)"
    echo ""

    local prompt="\e[1;32m$user@honeypot\e[0m:~$ "

    while true; do
        echo -ne "$prompt"
        read cmd
        if [[ "$cmd" == "exit" || "$cmd" == "logout" ]]; then
             log_it "$CMDS_LOG" "$ip | [SESSION TERMINATED]"
             echo "Goodbye!"
             break
        fi

    # Ignore blank input
        if [[ -z "$cmd" ]]; then
             continue
        fi

        log_it "$CMDS_LOG" "$ip | $cmd"

        case "$cmd" in
            exit|logout)
                echo "Goodbye!"
                break
                ;;

            whoami) echo "$user" ;;
            pwd) echo "/home/$user" ;;

            ls)
                for item in "${!FAKE_FS[@]}"; do
                    echo -n "$item  "
                done
                echo ""
                ;;

            "ls -l"|"ls -la")
                echo "total ${#FAKE_FS[@]}"
                for item in "${!FAKE_FS[@]}"; do
                    echo "drwxr-xr-x 2 $user $user 4096 Nov 16 $item"
                done
                ;;

            mkdir*)
                newdir=$(echo "$cmd" | awk '{print $2}')
                if [ -z "$newdir" ]; then
                    echo "mkdir: missing operand"
                else
                    FAKE_FS["$newdir"]=1
                    echo ""   # mimic real mkdir (silent)
                fi
                ;;

            id)
                echo "uid=1000($user) gid=1000($user) groups=1000($user)"
                ;;

           "cat /etc/passwd")
                echo "root:x:0:0:root:/root:/bin/bash"
                echo "daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin"
                echo "$user:x:1000:1000:Fake User:/home/$user:/bin/bash"
                ;;
            uname|"uname -a")
                echo "Linux server 5.15.0 x86_64 GNU/Linux"
                ;;

            hostname)
                echo "production-server-01"
                ;;

            *)
                echo "bash: $cmd: command not found"
                ;;
        esac
    done
}

#############################################
# Handle Connection
#############################################
handle_connection() {
    local ip="${REMOTE_IP:-unknown}"
    log_it "$IPS_LOG" "$ip"

    echo "SSH-2.0-OpenSSH_8.9p1"
    sleep 0.3

    echo -n "Username: "
    read username
    echo -n "Password: "
    read -s password
    echo ""

    log_it "$CREDS_LOG" "$ip | $username | $password"
    echo -e "${GREEN}[+] Captured $username:$password from $ip${NC}" >&2

    echo "Access granted."
    fake_shell "$ip" "$username"
}

#############################################
# Listener
#############################################
start_listener() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      SSH Honeypot - Starting...       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Port:${NC} $HONEYPOT_PORT"
    echo -e "${GREEN}Logs:${NC} $LOG_DIR"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    while true; do
        nc -l -p "$HONEYPOT_PORT" -c "$0 handle" 2>/dev/null
        sleep 1
    done
}

#############################################
# Check Tools
#############################################
check_requirements() {
    if ! command -v nc &>/dev/null; then
        echo -e "${RED}netcat not installed!${NC}"
        exit 1
    fi

    if ss -tln | grep -q ":$HONEYPOT_PORT "; then
        echo -e "${RED}Port $HONEYPOT_PORT already in use!${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Requirements OK${NC}"
}

#############################################
# Main
#############################################
if [ "$1" = "handle" ]; then
    export REMOTE_IP="${SOCAT_PEERADDR:-127.0.0.1}"
    handle_connection
    exit
fi

clear
echo -e "${BLUE}SSH Honeypot - College Project${NC}"
echo "================================"
echo ""

check_requirements
setup
start_listener
