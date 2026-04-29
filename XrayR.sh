#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mặc định $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Bạn có muốn khởi động lại XrayR không?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn Enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/Vietnamvpn/XrayR-release/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản chỉ định (Mặc định là bản mới nhất): " && read version
    else
        version=$2
    fi
#   confirm "Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất hiện tại, dữ liệu sẽ không bị mất, tiếp tục?" "n"
#   if [[ $? != 0 ]]; then
#       echo -e "${red}Đã hủy${plain}"
#       if [[ $1 != 0 ]]; then
#           before_show_menu
#       fi
#       return 0
#   fi
    bash <(curl -Ls https://raw.githubusercontent.com/Vietnamvpn/XrayR-release/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cập nhật hoàn tất, đã tự động khởi động lại XrayR, vui lòng dùng lệnh XrayR log để xem nhật ký chạy${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "XrayR sẽ tự động thử khởi động lại sau khi sửa đổi cấu hình"
    vi /etc/XrayR/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Trạng thái XrayR: ${green}Đang chạy${plain}"
            ;;
        1)
            echo -e "Phát hiện XrayR chưa được khởi động hoặc tự động khởi động lại thất bại, bạn có muốn xem nhật ký không? [Y/n]" && echo
            read -e -p "(Mặc định: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Trạng thái XrayR: ${red}Chưa cài đặt${plain}"
    esac
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt XrayR không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/XrayR/ -rf
    rm /usr/local/XrayR/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công, nếu bạn muốn xóa script này, thì hãy thoát script sau đó chạy lệnh ${green}rm /usr/bin/XrayR -f${plain} để xóa"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}XrayR đang chạy, không cần khởi động lại, nếu cần khởi động lại vui lòng chọn khởi động lại${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR khởi động thành công, vui lòng dùng lệnh XrayR log để xem nhật ký${plain}"
        else
            echo -e "${red}XrayR có thể đã khởi động thất bại, vui lòng dùng lệnh XrayR log sau đó để xem thông tin nhật ký${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop XrayR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}XrayR đã dừng thành công${plain}"
    else
        echo -e "${red}XrayR dừng thất bại, có thể do thời gian dừng vượt quá 2 giây, vui lòng kiểm tra thông tin nhật ký sau${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart XrayR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR khởi động lại thành công, vui lòng dùng lệnh XrayR log để xem nhật ký chạy${plain}"
    else
        echo -e "${red}XrayR có thể đã khởi động thất bại, vui lòng dùng lệnh XrayR log sau đó để xem thông tin nhật ký${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status XrayR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}Cài đặt tự động khởi chạy XrayR cùng hệ thống thành công${plain}"
    else
        echo -e "${red}Cài đặt tự động khởi chạy XrayR cùng hệ thống thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}Hủy tự động khởi chạy XrayR cùng hệ thống thành công${plain}"
    else
        echo -e "${red}Hủy tự động khởi chạy XrayR cùng hệ thống thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/Vietnamvpn/Linux-NetSpeed/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}Cài đặt bbr thành công, vui lòng khởi động lại máy chủ${plain}"
    #else
    #    echo ""
    #    echo -e "${red}Tải script cài đặt bbr thất bại, vui lòng kiểm tra xem máy có thể kết nối với Github không${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/XrayR -N --no-check-certificate https://raw.githubusercontent.com/Vietnamvpn/XrayR-release/master/XrayR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Tải script thất bại, vui lòng kiểm tra xem máy có thể kết nối với Github không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/XrayR
        echo -e "${green}Cập nhật script thành công, vui lòng chạy lại script${plain}" && exit 0
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

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}XrayR đã được cài đặt, vui lòng không cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt XrayR trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái XrayR: ${green}Đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái XrayR: ${yellow}Chưa chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái XrayR: ${red}Chưa cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự động chạy cùng hệ thống: ${green}Có${plain}"
    else
        echo -e "Tự động chạy cùng hệ thống: ${red}Không${plain}"
    fi
}

show_XrayR_version() {
    echo -n "Phiên bản XrayR: "
    /usr/local/XrayR/XrayR version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "Cách sử dụng script quản lý XrayR: "
    echo "------------------------------------------"
    echo "XrayR              - Hiển thị menu quản lý (Nhiều chức năng hơn)"
    echo "XrayR start        - Khởi động XrayR"
    echo "XrayR stop         - Dừng XrayR"
    echo "XrayR restart      - Khởi động lại XrayR"
    echo "XrayR status       - Xem trạng thái XrayR"
    echo "XrayR enable       - Cài đặt tự động khởi chạy XrayR"
    echo "XrayR disable      - Hủy tự động khởi chạy XrayR"
    echo "XrayR log          - Xem nhật ký XrayR"
    echo "XrayR update       - Cập nhật XrayR"
    echo "XrayR update x.x.x - Cập nhật XrayR phiên bản chỉ định"
    echo "XrayR install      - Cài đặt XrayR"
    echo "XrayR uninstall    - Gỡ cài đặt XrayR"
    echo "XrayR version      - Xem phiên bản XrayR"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Script quản lý backend XrayR,${plain}${red}không áp dụng cho docker${plain}
--- https://github.com/Vietnamvpn/XrayR ---
  ${green}0.${plain} Sửa đổi cấu hình
————————————————
  ${green}1.${plain} Cài đặt XrayR
  ${green}2.${plain} Cập nhật XrayR
  ${green}3.${plain} Gỡ cài đặt XrayR
————————————————
  ${green}4.${plain} Khởi động XrayR
  ${green}5.${plain} Dừng XrayR
  ${green}6.${plain} Khởi động lại XrayR
  ${green}7.${plain} Xem trạng thái XrayR
  ${green}8.${plain} Xem nhật ký XrayR
————————————————
  ${green}9.${plain} Cài đặt XrayR tự động khởi chạy
 ${green}10.${plain} Hủy XrayR tự động khởi chạy
————————————————
 ${green}11.${plain} Cài đặt bbr với 1 click (Kernel mới nhất)
 ${green}12.${plain} Xem phiên bản XrayR 
 ${green}13.${plain} Cập nhật script bảo trì
 "
 #Các bản cập nhật sau có thể thêm vào chuỗi phía trên
    show_status
    echo && read -p "Vui lòng nhập lựa chọn [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_XrayR_version
        ;;
        13) update_shell
        ;;
        *) echo -e "${red}Vui lòng nhập đúng số [0-13]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_XrayR_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
