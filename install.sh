#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# بررسی دسترسی root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# بررسی نسخه آلپاین
if [[ -f /etc/alpine-release ]]; then
    release="alpine"
    os_version=$(cat /etc/alpine-release | cut -d. -f1)
else
    echo -e "${red}Your operating system is not supported by this script.${plain}\n"
    exit 1
fi

# چک معماری سیستم
arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    aarch64 | arm64) echo 'arm64' ;;
    *) echo -e "${red}Unsupported CPU architecture!${plain}" && exit 1 ;;
    esac
}

echo "OS: $release, Version: $os_version, Architecture: $(arch)"

# نصب وابستگی‌ها
install_base() {
    echo -e "${green}Installing dependencies...${plain}"
    apk update
    apk add --no-cache wget curl tar tzdata bash gcompat
}

# نصب و پیکربندی s-ui
install_s-ui() {
    cd /tmp/
    arch=$(arch)

    # دریافت آخرین نسخه از گیت‌هاب
    last_version=$(curl -Ls "https://api.github.com/repos/alireza0/s-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ ! -n "$last_version" ]]; then
        echo -e "${red}Failed to fetch s-ui version, possibly due to Github API restrictions.${plain}"
        exit 1
    fi
    echo -e "Got s-ui latest version: ${last_version}, beginning the installation..."

    wget -O /tmp/s-ui-linux-$arch.tar.gz "https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-$arch.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Failed to download s-ui, please check your connection to Github.${plain}"
        exit 1
    fi

    tar zxvf s-ui-linux-$arch.tar.gz
    rm -f s-ui-linux-$arch.tar.gz

    # نصب فایل‌های اجرایی
    chmod +x s-ui/sui s-ui/bin/sing-box s-ui/bin/runSingbox.sh
    mkdir -p /usr/local/s-ui
    cp -rf s-ui/* /usr/local/s-ui/
    ln -sf /usr/local/s-ui/sui /usr/bin/s-ui

    echo -e "${green}s-ui installation finished, starting services...${plain}"
    start_services
}

# راه‌اندازی سرویس‌ها
start_services() {
    echo -e "${green}Starting s-ui services...${plain}"
    /usr/local/s-ui/bin/runSingbox.sh &
    /usr/local/s-ui/sui &
}

# پیکربندی پس از نصب
config_after_install() {
    echo -e "${yellow}Running migration...${plain}"
    /usr/local/s-ui/sui migrate
    
    echo -e "${yellow}Installation complete!${plain}"
    echo -e "It is recommended to modify panel settings for security."
    read -p "Do you want to configure the panel settings now? [y/n]: " config_confirm

    if [[ "$config_confirm" == "y" || "$config_confirm" == "Y" ]]; then
        echo -e "Enter the ${yellow}panel port${plain} (leave blank for default):"
        read config_port
        echo -e "Enter the ${yellow}panel path${plain} (leave blank for default):"
        read config_path

        echo -e "Enter the ${yellow}subscription port${plain} (leave blank for default):"
        read config_subPort
        echo -e "Enter the ${yellow}subscription path${plain} (leave blank for default):"
        read config_subPath

        # تنظیمات
        params=""
        [ -z "$config_port" ] || params="$params -port $config_port"
        [ -z "$config_path" ] || params="$params -path $config_path"
        [ -z "$config_subPort" ] || params="$params -subPort $config_subPort"
        [ -z "$config_subPath" ] || params="$params -subPath $config_subPath"
        /usr/local/s-ui/sui setting ${params}

        # تنظیمات نام کاربری و رمز عبور
        read -p "Do you want to change admin credentials? [y/n]: " admin_confirm
        if [[ "$admin_confirm" == "y" || "$admin_confirm" == "Y" ]]; then
            read -p "Set your username: " config_account
            read -p "Set your password: " config_password
            /usr/local/s-ui/sui admin -username $config_account -password $config_password
        else
            /usr/local/s-ui/sui admin -show
        fi
    else
        echo -e "${red}Skipping configuration...${plain}"
    fi
}

# اجرای نصب
echo -e "${green}Starting installation...${plain}"
install_base
install_s-ui
config_after_install

echo -e "${green}s-ui installation and setup complete.${plain}"
