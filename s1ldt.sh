#!/usr/bin/env bash

# Initialize log file for error and debugging
LOG_FILE="/var/log/sentinel_one_install.log"
echo "Starting SentinelOne Installation at $(date)" > "$LOG_FILE"

# Start the timer
SECONDS=0

# Function to log messages
log_message() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Log the start of script
log_message "Script started."

# Function to display help menu
display_help() {
    log_message "Usage: $0 -token YOUR_TOKEN [-site YOUR_FQDN]"
    log_message ""
    log_message "Examples:"
    log_message "  sudo ./s1ldt.sh -token YOUR_TOKEN_VALUE"
    log_message "  sudo ./s1ldt.sh -token YOUR_TOKEN_VALUE -site YOUR_FQDN"
    log_message ""
    log_message "Options:"
    log_message "    -token    The token for SentinelOne (required)"
    log_message "    -site     FQDN of the SentinelOne site (optional)"
    log_message "    -h, -help Show this help message"
}

# Script must be run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check for required parameters
TOKEN=""
FQDN="usea1-dfir.sentinelone.net"  # Default FQDN
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -token)
            TOKEN="$2"
            shift
            ;;
        -site)
            FQDN="$2"
            shift
            ;;
        -h | -help)
            display_help
            exit 0
            ;;
        *)
            echo "Unknown parameter passed: $1"
            display_help
            exit 1
            ;;
    esac
    shift
done

# Check if TOKEN is empty
if [[ -z "$TOKEN" ]]; then
    echo "Error: No Site Token flag provided. Site Token is required."
    display_help
    exit 1
fi

if [ "$FQDN" == "usea1-dfir.sentinelone.net" ]; then
  echo "No custom FQDN provided, using default: $FQDN"
fi

# Detect the operating system and package manager
if grep -Ei 'debian|ubuntu|mint' /etc/os-release > /dev/null; then
    SUPPORTED_OS=true
elif grep -Ei 'rhel|amazon|fedora|suse|opensuse|alma|rocky|centos|virtuozzo' /etc/os-release > /dev/null; then
    SUPPORTED_OS=true
elif [[ $(uname) == "Darwin" ]]; then
    echo "Whoa there, cowboy! This script doesn't ride well with macOS. Time to mosey on!"
    exit 1
elif [[ $(uname) == "FreeBSD" ]] || grep -Ei 'freebsd|openbsd|netbsd' /etc/os-release > /dev/null; then
    echo "Ahoy, matey! Yarrrr on a FreeBSD/BSD ship, but this script be no pirate's treasure! Arrr!"
    exit 1
else
    echo "Yikes! Unsupported OS! Even the cows are confused!"
    exit 1
fi

# Array of funny S1 variations
declare -a banner_lines=(
  "Mooove aside, malware! SentinelOne is patrolling the pasture!"
  "Don't have a cow, man! SentinelOne's got your endpoints covered!"
  "Udder chaos without SentinelOne! Even cows know better!"
  "Why did SentinelOne cross the road? To kick malware off the network!"
  "Security's no bull rodeo, but SentinelOne sure knows how to lasso in threats!"
  "Holy cow! SentinelOne makes other EDRs look like calves!"
  "Where's the beef? It's in the cloud, safely guarded by SentinelOne!"
  "Who let the cows out? Not SentinelOne, we keep your farm secure!"
)

# Script version
VERSION="1.4-alpha"

# Select a random line
random_line=${banner_lines[RANDOM % ${#banner_lines[@]}]}

# Simulate cowsay-style banner
echo " ---------------------------------------------"
echo "< $random_line >"
echo " ---------------------------------------------"
echo "        \\   ^__^"
echo "         \\  (oo)\\_______"
echo "            (__)\\       )\\/\\"
echo "                ||----w |"
echo "                ||     ||"
echo "----------------------------------------------"
echo "SentinelOne Linux Deployment Toolkit v$VERSION"
echo ""

# Function to install DEB package
install_deb () {
    echo "Starting DEB package installation..."
    
    url="https://github.com/w0rm3r/S1Agents/raw/main/Linux/x86/s1agent_x86_latest.deb"

    # Download the DEB package
    if command -v wget > /dev/null; then
        wget "$url"
    elif command -v curl > /dev/null; then
        curl -O "$url"
    fi

    chmod +x s1agent_x86_latest.deb
    sudo dpkg -i s1agent_x86_latest.deb
    echo "DEB package installed."
    sudo rm -rf s1agent_x86_latest.deb

}

# Function to install RPM package
install_rpm () {
    echo "Starting RPM package installation..."

    url="https://github.com/w0rm3r/S1Agents/raw/main/Linux/x86/s1agent_x86_latest.rpm"
    gpg_url="https://github.com/w0rm3r/S1Agents/raw/main/Linux/sentinel_one.gpg"

    # Download the RPM package and GPG key
    if command -v wget > /dev/null; then
        wget "$url"
        wget "$gpg_url"
    elif command -v curl > /dev/null; then
        curl -O "$url"
        curl -O "$gpg_url"
    fi

    chmod +x s1agent_x86_latest.rpm

    if sudo rpm -i --nodigest s1agent_x86_latest.rpm; then
        echo "RPM package installed using rpm."
        sudo rm -rf s1agent_x86_latest.rpm
    else
        echo "RPM installation failed, trying with yum."

        rpm --import sentinel_one.gpg

        if sudo yum install -y s1agent_x86_latest.rpm; then
            echo "RPM package installed using yum."
            sudo rm -rf s1agent_x86_latest.rpm
        else
            echo "Both rpm and yum installations failed."
            exit 1
        fi
    fi
}

ARCH=$(uname -m)

if [[ "$SUPPORTED_OS" = true ]]; then
    case $ARCH in
        x86_64)
            if grep -Ei 'debian|ubuntu|mint' /etc/os-release > /dev/null; then
                install_deb
            elif grep -Ei 'rhel|amazon|fedora|suse|opensuse|alma|rocky|centos|virtuozzo' /etc/os-release > /dev/null; then
                install_rpm
            fi
            ;;
        aarch64)
            echo "ARM64 architecture detected. Replace this line with ARM64 installation steps."
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
fi

# Run sentinelctl commands
sudo /opt/sentinelone/bin/sentinelctl management token set "$TOKEN"
sudo /opt/sentinelone/bin/sentinelctl control start 2>>"$LOG_FILE" | tee -a "$LOG_FILE"
sudo /opt/sentinelone/bin/sentinelctl control status 2>>"$LOG_FILE" | tee -a "$LOG_FILE"
sudo /opt/sentinelone/bin/sentinelctl version 2>>"$LOG_FILE" | tee -a "$LOG_FILE"

# Check agent status and connectivity
agent_status=$(sudo /opt/sentinelone/bin/sentinelctl control status | grep -o "Agent state: Enabled")

# DNS Check
FQDN="usea1-dfir.sentinelone.net"
if command -v dig > /dev/null; then
    if dig +short "$FQDN" > /dev/null; then
        echo "DNS Check: Successful for $FQDN."
    else
        echo "DNS Check: Unsuccessful for $FQDN. Please check your DNS settings."
    fi
elif command -v nslookup > /dev/null; then
    if nslookup "$FQDN" > /dev/null; then
        echo "DNS Check: Successful for $FQDN."
    else
        echo "DNS Check: Unsuccessful for $FQDN. Please check your DNS settings."
    fi
else
    echo "Neither dig nor nslookup are available for DNS check. Proceeding without DNS verification."
fi

# Your existing SSL verification code
if [ "$agent_status" == "Agent state: Enabled" ]; then
    if echo | openssl s_client -showcerts -servername "$FQDN" -connect "$FQDN":443 -tls1_2 2>>"$LOG_FILE" | openssl x509 -text | grep --quiet "CYbikAHNxGrAiZXCtTYwLQYDVR0RBCYwJIIRK"; then
        log_message "Your Agent Connects to $FQDN!"
        log_message "The Agent is installed and is able to communicate with the Management Console."
    else
        log_message "Your Agent Does NOT Connect to $FQDN!"
        log_message "Please verify Internet and DNS settings."
    fi
else
    log_message ""
fi

# Calculate and display script execution time
execution_time=$SECONDS
if (( execution_time >= 60 )); then
    log_message "Script took $((execution_time / 60)) min $((execution_time % 60)) sec."
else
    log_message "Script took $execution_time sec."
fi
