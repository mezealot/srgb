#!/usr/bin/env bash

# 下载 IPTABLES 设置防火墙规则 脚本 By 蘭雅sRGB
# wget -qO safe_iptables.sh  git.io/fhJrU

#  初始化安全防火墙规则预设端口,1999和2999是转接端口
tcp_port="80,443,1999,2999"
udp_port="9999,8000"

# 保存防火墙规则文件路径 /etc/iptables/rules.v4  禁用ipv6
mkdir -p /etc/iptables

# 定义文字颜色
Green="\033[32m"  && Red="\033[31m" && GreenBG="\033[42;37m" && RedBG="\033[41;37m" && Font="\033[0m"

# 检查系统
check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    bit=`uname -m`
}


# 保存防火墙规则
save_iptables(){
    if [[ ${release} == "centos" ]]; then
        service iptables save
    else
        iptables-save > /etc/iptables/rules.v4
    fi
}

# 设置防火墙规则，下次开机也生效
set_iptables(){
    if [[ ${release} == "centos" ]]; then
        service iptables save
        chkconfig --level 2345 iptables on
    else
        iptables-save > /etc/iptables/rules.v4
        echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables/rules.v4' > /etc/network/if-pre-up.d/iptables
        chmod +x /etc/network/if-pre-up.d/iptables
    fi
}

# 隐藏的防火墙设置功能菜单  88
hide_menu(){
    echo
    echo -e "${RedBG}   隐藏的高级防火墙设置功能 By 蘭雅sRGB  ${Font}"
    echo -e "${Green}>  1. ss_kcp_speed_udp2raw 端口开放 防火墙规则"
    echo -e ">  2. ss brook 电报代理端口开放 防火墙规则"
    echo -e ">  3. frps_iptables 防火墙规则"
    echo -e ">  4. 菜单项1-2-3全功能开放${Font}"
    echo
    read -p "请输入数字(1-4):" num_x
    case "$num_x" in
        1)
        ss_kcp_speed_udp2raw
        ;;
        2)
        ss_bk_tg
        ;;
        3)
        frps_iptables
        ;;
        4)
        ss_kcp_speed_udp2raw
        ss_bk_tg_frps_iptables
        ;;
        *)
        ;;
        esac
}

# ss_kcp_speed_udp2raw 端口防火墙规则
ss_kcp_speed_udp2raw(){
    # ss+kcp+udp2raw  和  # wg+speed+udp2raw
    iptables -I INPUT -s 127.0.0.1 -p tcp  --dport 40000 -j ACCEPT
    iptables -I INPUT -s 127.0.0.1 -p udp -m multiport --dport 4000,8888,9999 -j ACCEPT

    RELATED_ESTABLISHED
    save_iptables

    wg-quick down wg0   >/dev/null 2>&1
    wg-quick up wg0     >/dev/null 2>&1
}

# ss brook 电报代理端口开放 防火墙规则
ss_bk_tg(){
    ss_bk_tg="2018,7731,7979"
    iptables -D INPUT -p tcp -m multiport --dport ${tcp_port} -j ACCEPT  >/dev/null 2>&1
    iptables -I INPUT -p tcp -m multiport --dport ${tcp_port},${ss_bk_tg} -j ACCEPT

    RELATED_ESTABLISHED
    save_iptables
}

# frps_iptables 防火墙规则
frps_iptables(){
    frps_port="7000,7500,8080,4443,11122,2222"
    iptables -D INPUT -p tcp -m multiport --dport ${tcp_port} -j ACCEPT  >/dev/null 2>&1
    iptables -I INPUT -p tcp -m multiport --dport ${tcp_port},${frps_port} -j ACCEPT

    RELATED_ESTABLISHED
    save_iptables
}

ss_bk_tg_frps_iptables(){
    ss_bk_tg="2018,7731,7979"
    frps_port="7000,7500,8080,4443,11122,2222"
    iptables -D INPUT -p tcp -m multiport --dport ${tcp_port} -j ACCEPT  >/dev/null 2>&1
    iptables -I INPUT -p tcp -m multiport --dport ${tcp_port},${ss_bk_tg},${frps_port} -j ACCEPT

    RELATED_ESTABLISHED
    save_iptables
}

# 安全防火墙规则
safe_iptables(){
    iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 22  -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A INPUT -j DROP
    iptables -P FORWARD DROP
    iptables -A OUTPUT -j ACCEPT
}

# 建立相关链接的优先
RELATED_ESTABLISHED(){
    iptables -D INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
}


# 禁止网卡IPV6功能
disable_ipv6(){
    ni=$(ls /sys/class/net | awk {print} | grep -e eth. -e ens. -e venet.)
    echo 1 > /proc/sys/net/ipv6/conf/${ni}/disable_ipv6
}

# 初始化安全防火墙规则
init_iptables(){
    # 清除防火墙规则
    iptables -F
    disable_ipv6

    # 添加 预置 tcp 和 udp端口
    iptables -I INPUT -p tcp -m multiport --dport ${tcp_port} -j ACCEPT
    iptables -I INPUT -p udp -m multiport --dport ${udp_port} -j ACCEPT

    safe_iptables
    set_iptables
}

add_tcp_chain(){
    echo -e "${GreenBG} 追加TCP端口段到 Chain INPUT ( multiport dports) ${Font}"
    read -p "请输入TCP端口段(示例: 7000,7500:7510 ): " port

    iptables -D INPUT -p tcp -m multiport --dport ${tcp_port} -j ACCEPT  >/dev/null 2>&1
    iptables -I INPUT -p tcp -m multiport --dport ${tcp_port},${port} -j ACCEPT

    RELATED_ESTABLISHED
    save_iptables
}

add_udp_chain(){
    echo -e "${GreenBG} 追加UDP端口段到 Chain INPUT ( multiport dports) ${Font}"
    read -p "请输入UDP端口段(示例: 7000,7500:7510 ): " port

    iptables -D INPUT -p udp -m multiport --dport ${udp_port} -j ACCEPT  >/dev/null 2>&1
    iptables -I INPUT -p udp -m multiport --dport ${udp_port},${port} -j ACCEPT

    RELATED_ESTABLISHED
    save_iptables
}

# 删除指定INPUT Chain 序号行
del_chain(){
    iptables -nvL --line
    echo -e "${RedBG} 删除指定INPUT Chain 序号行 ${Font}"
    read -p "请检查INPUT Chain序号行，输入序号(2-X): " no_x

    if [[ ${no_x} -ge 2 ]] && [[ ${no_x} -le 20 ]]; then
      iptables -D INPUT ${no_x}
    else
       echo -e "${RedBG}::  INPUT Chain序号行选择错误，没有删除！${Font}"
    fi

    save_iptables
}

# 禁止ICMP，禁止Ping服务器
no_ping(){
    iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT
}

# 设置菜单
start_menu(){
    echo
    echo -e "${GreenBG}   IPTABLES 设置防火墙规则 脚本 By 蘭雅sRGB  特别感谢 TaterLi 指导  ${Font}"
    echo -e   "${RedBG}   规则不宜超过10条，3-5条最好，每增加规则系统都忙很多。 ${Font}"
    echo -e "${Green}>  1. 追加 TCP 多端口到防火墙规则"
    echo -e ">  2. 追加 UDP 多端口到防火墙规则"
    echo -e ">  3. 删除指定INPUT Chain 序号行(不浪费防火墙效率)"
    echo -e ">  4. 禁止ICMP，禁止Ping服务器"
    echo -e ">  5. 重置 初始化安全防火墙规则预设端口"
    echo -e ">  6. 退出设置${Font}"
    echo
    read -p "请输入数字(1-6):" num
    case "$num" in
        1)
        add_tcp_chain
        ;;
        2)
        add_udp_chain
        ;;
        3)
        del_chain
        ;;
        4)
        no_ping
        ;;
        5)
        init_iptables
        ;;
        6)
        exit 1
        ;;
        88)
        hide_menu
        ;;
        *)
        echo
        ;;
        esac
        iptables -nvL --line
}

check_sys
start_menu