#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Phải sử dụng người dùng root để chạy script này!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không phát hiện được phiên bản hệ thống, vui lòng liên hệ tác giả script!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Phát hiện kiến trúc thất bại, sử dụng kiến trúc mặc định: ${arch}${plain}"
fi

echo "Kiến trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32 bit (x86), vui lòng sử dụng hệ thống 64 bit (x86_64), nếu phát hiện sai sót, vui lòng liên hệ tác giả"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống CentOS 7 hoặc mới hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống Ubuntu 16 hoặc mới hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống Debian 8 hoặc mới hơn!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/Vietnamvpn/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Phát hiện phiên bản XrayR thất bại, có thể đã vượt giới hạn Github API, vui lòng thử lại sau, hoặc chỉ định thủ công phiên bản XrayR để cài đặt${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản XrayR mới nhất: ${last_version}, bắt đầu cài đặt"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/Vietnamvpn/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống XrayR thất bại, vui lòng đảm bảo máy chủ của bạn có thể tải tệp từ Github${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        url="https://github.com/Vietnamvpn/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "Bắt đầu cài đặt XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống XrayR ${last_version} thất bại, vui lòng đảm bảo phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/Vietnamvpn/XrayR-release/raw/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} cài đặt hoàn tất, đã thiết lập tự động khởi chạy cùng hệ thống"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "Cài đặt mới hoàn toàn, vui lòng tham khảo hướng dẫn trước: https://github.com/Vietnamvpn/XrayR, cấu hình các nội dung cần thiết"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR khởi động lại thành công${plain}"
        else
            echo -e "${red}XrayR có thể khởi động thất bại, vui lòng sử dụng lệnh XrayR log sau để xem thông tin nhật ký, nếu không thể khởi động, có thể do thay đổi định dạng cấu hình, vui lòng truy cập wiki để xem: https://github.com/Vietnamvpn/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/Vietnamvpn/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # Tương thích chữ thường
    chmod +x /usr/bin/xrayr
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Cách sử dụng script quản lý XrayR (Tương thích khi sử dụng lệnh xrayr, không phân biệt hoa thường): "
    echo "------------------------------------------"
    echo "XrayR                    - Hiển thị menu quản lý (Nhiều chức năng hơn)"
    echo "XrayR start              - Khởi động XrayR"
    echo "XrayR stop               - Dừng XrayR"
    echo "XrayR restart            - Khởi động lại XrayR"
    echo "XrayR status             - Xem trạng thái XrayR"
    echo "XrayR enable             - Cài đặt tự động khởi chạy XrayR"
    echo "XrayR disable            - Hủy tự động khởi chạy XrayR"
    echo "XrayR log                - Xem nhật ký XrayR"
    echo "XrayR update             - Cập nhật XrayR"
    echo "XrayR update x.x.x       - Cập nhật XrayR phiên bản chỉ định"
    echo "XrayR config             - Hiển thị nội dung tệp cấu hình"
    echo "XrayR install            - Cài đặt XrayR"
    echo "XrayR uninstall          - Gỡ cài đặt XrayR"
    echo "XrayR version            - Xem phiên bản XrayR"
    echo "------------------------------------------"
}

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
# install_acme
install_XrayR $1
