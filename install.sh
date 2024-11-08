#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error:${plain} Please run this script with root privileges."
    exit 1
fi

# Check OS and architecture
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo -e "${red}Error:${plain} Failed to detect OS."
    exit 1
fi

if [[ "${release}" != "alpine" ]]; then
    echo -e "${red}This script is only supported on Alpine Linux.${plain}"
    exit 1
fi

echo -e "${green}Detected OS: Alpine Linux${plain}"

# Determine CPU architecture
arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) echo -e "${red}Unsupported CPU architecture!${plain}" && exit 1 ;;
    esac
}

cpu_arch=$(arch)
echo "CPU Architecture: $cpu_arch"

# Install base dependencies
install_base() {
    echo -e "${yellow}Updating package index and installing dependencies...${plain}"
    apk update
    apk add --no-cache wget curl tar tzdata bash openrc gcompat
}

# Function to download and install s-ui
install_s_ui() {
    cd /tmp/

    # Fetch the latest version of s-ui from GitHub
    local version=$(curl -s "https://api.github.com/repos/alireza0/s-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        echo -e "${red}Failed to fetch s-ui version. Check GitHub API access.${plain}"
        exit 1
    fi

    echo -e "Installing s-ui version ${version}..."
    wget -q --no-check-certificate -O s-ui-linux-${cpu_arch}.tar.gz "https://github.com/alireza0/s-ui/releases/download/${version}/s-ui-linux-${cpu_arch}.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Download failed. Check your network connection.${plain}"
        exit 1
    fi

    # Extract the package
    tar -xzf s-ui-linux-${cpu_arch}.tar.gz
    rm -f s-ui-linux-${cpu_arch}.tar.gz
    mv s-ui /usr/local/s-ui

    # Set up permissions
    chmod +x /usr/local/s-ui/sui /usr/local/s-ui/bin/sing-box /usr/local/s-ui/bin/runSingbox.sh

    # Set up a service using OpenRC
    echo -e "${yellow}Configuring OpenRC service...${plain}"
    cat <<EOF > /etc/init.d/s-ui
#!/sbin/openrc-run
command="/usr/local/s-ui/sui"
command_args="run"
pidfile="/run/s-ui.pid"
name="s-ui"
EOF

    chmod +x /etc/init.d/s-ui
    rc-update add s-ui default
    rc-service s-ui start

    echo -e "${green}s-ui version ${version} installation finished and service started.${plain}"
    /usr/local/s-ui/sui help
}

# Start installation
echo -e "${green}Starting installation...${plain}"
install_base
install_s_ui
