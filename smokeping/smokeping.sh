#!/bin/bash
###
# @Author: MuSiShui
# @Date: 2021-11-22 19:34:07
# @LastEditTime: 2021-11-24 20:29:45
# @LastEditors: Please set LastEditors
###
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit

# 字体颜色/背景
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

# 通知消息颜色
INFO="${Green}[INFO]${Font}"
WARN="${Yellow}[WARN]${Font}"
ERROR="${Red}[ERROR]${Font}"

#定义文件路径
smokeping_ver="/opt/local/smokeping/manager/ver"
smokeping_key="/opt/local/smokeping/manager/key"
smokeping_name="/opt/local/smokeping/manager/name"
smokeping_host="/opt/local/smokeping/manager/host"
tcpping="/usr/bin/tcpping"

version="1.0"
github_branch="main"

function print_msg() {
    if [[ "$1" == "info" ]]; then
        echo -e "${INFO} ${Blue} $2 ${Font}"
    elif [[ "$1" == "warn" ]]; then
        echo -e "${WARN} ${Yellow} $2 ${Font}"
    elif [[ "$1" == "error" ]]; then
        echo -e "${ERROR} ${RedBG} $2 ${Font}"
    else
        echo -e "${ERROR} ${RedBG} 参数错误 ${Font}"
        exit 1
    fi
}

function check_user() {
    if [[ "$EUID" -ne 0 ]]; then
        print_msg "error" "当前用户不是 root 用户，请切换到 root 用户后重新执行脚本"
        exit 1
    fi
}

function check_system() {
    source '/etc/os-release'
    
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        print_msg "info" "当前系统为 Centos ${VERSION_ID} ${VERSION}"
        INS="yum install -y"
        wget -N -P /etc/yum.repos.d/ https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/base/nginx.repo
        
    elif [[ "${ID}" == "ol" ]]; then
        print_msg "info" "当前系统为 Oracle Linux ${VERSION_ID} ${VERSION}"
        INS="yum install -y"
        wget -N -P /etc/yum.repos.d/ https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/base/nginx.repo
        
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 9 ]]; then
        print_msg "info" "当前系统为 Debian ${VERSION_ID} ${VERSION}"
        INS="apt install -y"
        # 清除可能的遗留问题
        rm -f /etc/apt/sources.list.d/nginx.list
        $INS lsb-release gnupg2
        
        echo "deb http://nginx.org/packages/debian $(lsb_release -cs) nginx" >/etc/apt/sources.list.d/nginx.list
        curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
        
        apt update
        
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 18 ]]; then
        print_msg "info" "当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME}"
        INS="apt install -y"
        # 清除可能的遗留问题
        rm -f /etc/apt/sources.list.d/nginx.list
        $INS lsb-release gnupg2
        
        echo "deb http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" >/etc/apt/sources.list.d/nginx.list
        curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
        apt update
        
    else
        print_msg "error" "当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内"
        exit 1
    fi
    
    if [[ $(grep "nogroup" /etc/group) ]]; then
        cert_group="nogroup"
    fi

    # RedHat 系发行版关闭 SELinux
    if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    fi
    # 关闭各类防火墙
    print_msg "info" "关闭防火墙"
    systemctl stop firewalld
    systemctl disable firewalld
    systemctl stop nftables
    systemctl disable nftables
    systemctl stop ufw
    systemctl disable ufw
}

#获取进程PID
function Get_PID(){
	PID=(`ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs`)
}

function check_status() {
    if [[ "$1" == "smokeping" ]]; then
        if [[ -e ${smokeping_ver} ]]; then
            Get_PID
            if [[ `grep "Slaves" ${smokeping_ver}` ]]; then
                mode="Slaves"
                mode2="Slaves端"
                slaves_secret=(`cat ${smokeping_key}`)
                slaves_name=(`cat ${smokeping_name}`)
                server_name=(`cat ${smokeping_host}`)
            elif [[ `grep "Master" ${smokeping_ver}` ]]; then
                mode="Master"
                mode2="Master端"
            elif [[ `grep "Single" ${smokeping_ver}` ]]; then
                mode="Single"
                mode2="单机版"
            fi
            if [[ ! -z "${PID}" ]]; then
                echo -e "当前状态: ${Green}已安装 $mode2 ${Font}并 ${Green}已启动${Font}"
            else
                echo -e "当前状态: ${Green}已安装 $mode2 ${Font}但 ${Red}未启动${Font}"
            fi
        else
            echo -e "当前状态: ${Red}未安装${Font}"
        fi
    elif [[ "$1" == "tcpping" ]]; then
        if [[ ! -e ${tcpping} ]]; then
            echo -e "Tcpping状态: ${Red}未安装${Font}"
        else
            echo -e "Tcpping状态: ${Green}已安装${Font}"
        fi
    else
        print_msg "error" "发生错误"
        exit 1
    fi
}

# 安装依赖
function install_dependency() {
    print_msg "info" "安装 SmokePing 依赖"
    $INS $(curl -fsSL https://git.io/Jyv0j)
}

# 安装 Fping 5.0
function install_fping() {
    cd /root
    print_msg "info" "安装 FPing"
    wget -N --no-check-certificate https://fping.org/dist/fping-5.0.tar.gz
    tar -zxvf fping-5.0.tar.gz
    cd fping-5.0
    ./configure
    make && make install
}

# 安装 SmokePing
function make_somkeping() {
    cd /root
    print_msg "info" "安装 SmokePing"
    wget -N --no-check-certificate https://oss.oetiker.ch/smokeping/pub/smokeping-2.8.2.tar.gz
    tar -xzvf smokeping-2.8.2.tar.gz
    cd smokeping-2.8.2
    ./configure --prefix=/opt/local/smokeping
    /usr/bin/gmake install
}


# 清除安装历史
function clean_history() {
    print_msg "info" "清除安装历史"
    kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
    rm -rf /opt/local/smokeping
}

# 清除文件
function del_tmp_files(){
    print_msg "info" "清除文件"
    rm -rf /root/smokeping-2.8.*
}

# 配置 SomkePing
function configure_somkeping(){
    print_msg "info" "配置 SmokePing"
    cd /opt/local/smokeping/htdocs
    mkdir var cache data
    mv smokeping.fcgi.dist smokeping.fcgi
    cd /opt/local/smokeping/etc
    rm -rf config*
    wget -O config https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/config
    wget -O /opt/local/smokeping/lib/Smokeping/Graphs.pm https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/Graphs.pm
    chmod 600 /opt/local/smokeping/etc/smokeping_secrets.dist
}

# 配置 SmokePing Master
function configure_somkeping_master(){
    print_msg "info" "配置 SmokePing Master"
    cd /opt/local/smokeping/etc
    sed -i "s/some.url/$server_name/g" config
}

# 安装 Nginx
function nginx_install() {
    print_msg "info" "安装 Nginx"
    if ! command -v nginx >/dev/null 2>&1; then
        ${INS} nginx spawn-fcgi
        print_msg "info" "Nginx 安装"
    else
        print_msg "warn" "Nginx 已存在"
        ${INS} nginx spawn-fcgi
    fi
    # 遗留问题处理
    mkdir -p /etc/nginx/conf.d >/dev/null 2>&1
}

# 修改 Nginx 配置文件
function configure_nginx() {
    print_msg "info" "修改 Single Nginx 配置文件"
    wget -O /etc/nginx/conf.d/smokeping.conf -N --no-check-certificate https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/smokeping.conf
    rm -rf /etc/nginx/nginx.conf
    rm -rf /etc/nginx/conf.d/default.conf
    wget -O /etc/nginx/nginx.conf -N --no-check-certificate https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/nginx.conf
    
    systemctl enable nginx
    systemctl restart nginx
}

# 修改 Nginx 配置文件 Master
function configure_master_nginx() {
    print_msg "info" "修改 Master Nginx 配置文件"
    wget -O /etc/nginx/conf.d/smokeping.conf -N --no-check-certificate https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/smokeping-master.conf
    sed -i "s/local/$server_name/g" /etc/nginx/conf.d/smokeping.conf
    rm -rf /etc/nginx/nginx.conf
    rm -rf /etc/nginx/conf.d/default.conf
    wget -O /etc/nginx/nginx.conf -N --no-check-certificate https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/nginx.conf
    
    systemctl enable nginx
    systemctl restart nginx   
}

# 修改 SomkePing 权限
function change_access() {
    print_msg "info" "修改 SomkePing 权限"
    chown -R nginx:nginx /opt/local/smokeping/htdocs
    chown -R nginx:nginx /opt/local/smokeping/etc/smokeping_secrets.dist
}

# 配置 Supervisor
function configure_supervisor(){
    print_msg "info" "配置 Supervisor"
    wget -O /etc/supervisord.d/spawnfcgi.ini -N --no-check-certificate https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/spawnfcgi.ini
    supervisord -c /etc/supervisord.conf
    systemctl enable supervisord.service
    supervisorctl reload
    supervisorctl stop spawnfcgi
}

# 同步时间
function time_synchronization(){
    print_msg "info" "同步时间"
    cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 2>/dev/null
    date -s "$(curl -sk --head https://dash.cloudflare.com | grep ^Date: | sed 's/Date: //g')"
}

function install_somkeping() {
    clear
    check_system
    if [[ "$1" == "Master" ]]; then
        print_msg "info" "开始安装 Master"
        read -rp "info" "请输入Master地址 : " server_name
    elif [[ "$1" == "Slaves" ]]; then
        print_msg "info" "开始安装 Slaves"
        read -rp  "info" "请输入Master地址 : " server_name
        read -rp  "info" "请输入Slaves名称 : " slaves_name
        read -rp  "info" "请输入Slaves密钥 : " slaves_secret
    elif [[ "$1" == "Single" ]]; then
        print_msg "info" "开始安装 Single"
    fi
    clean_history
    install_dependency
    install_fping
    make_somkeping
    # 设置Slaves密钥
    if [[ "$1" == "Slaves" ]]; then
        print_msg "info" "设置Slaves密钥"
        rm -rf /opt/local/smokeping/etc/smokeping_secrets.dist
        echo -e "${slaves_secret}" > /opt/local/smokeping/etc/smokeping_secrets.dist
    fi
    # 配置 config Master
    configure_somkeping
    if [[ "$1" == "Master" ]]; then
        configure_somkeping_master
    fi
    # 安装Nginx及其他软件
    print_msg "info" "安装Nginx及其他软件"
    if [[ ! "$1" == "Slaves" ]]; then
        nginx_install
        if [[ "$1" == "Single" ]]; then
            configure_nginx
        elif [[ "$1" == "Master" ]]; then
            configure_master_nginx
        fi
        change_access
        configure_supervisor
    fi
    time_synchronization
    del_tmp_files
    mkdir -p /opt/local/smokeping/manager
    echo $1 > ${smokeping_ver}
    if [[ "$1" == "Slaves" ]]; then
        echo -e "${slaves_secret}" > ${smokeping_key}
        echo -e "${slaves_name}" > ${smokeping_name}
        echo -e "${server_name}" > ${smokeping_host}
    fi
    print_msg "info" "安装 SmokePing $1端完成"
    print_msg "info" "配置文件地址: /opt/local/smokeping/etc/config"
}

function check_install() {
    if [[ "$1" == "smokeping" ]]; then
        if [[ -e ${smokeping_ver} ]]; then
            read -rp "已经安装 $mode2，是否重新安装 [y/n]: " install
            case $install in
                [yY][eE][sS] | [yY])
                    print_msg "info" "继续安装"
                    sleep 2
                ;;
                *)
                    print_msg "error" "安装终止"
                    exit 2
                ;;
            esac
            kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
            rm -rf /opt/local/smokeping
            rm -rf /usr/bin/tcpping
            supervisorctl stop spawnfcgi
            print_msg "info" "Smokeping ${mode2} 卸载完成! 开始安装 $2 端!"
            sleep 5
        elif [[ -e $2 ]]; then
            print_msg "error" "Smokeping 没有安装，请检查!"
            exit 1
        fi
    elif [[ "$1" == "tcpping" ]]; then
        if [[ -e ${tcpping} ]]; then
            read -rp "已经安装 Tcpping，是否重新安装 [y/n]: " install
            case $install in
                [yY][eE][sS] | [yY])
                    print_msg "info" "继续安装"
                    sleep 2
                ;;
                *)
                    print_msg "error" "安装终止"
                    exit 2
                ;;
            esac
            rm -rf /usr/bin/tcpping
            print_msg "info" "卸载完成! 开始安装 Tcpping!"
            sleep 5
        fi
    else
        print_msg "error" "发生错误"
        exit 1
    fi
}

# 更换 Linux 软件源
function change_mirrors() {
    print_msg "info" "更换 Linux 软件源"
    [ -f "ChangeMirrors.sh" ] && rm -rf ./ChangeMirrors.sh
    wget -N --no-check-certificate https://raw.githubusercontent.com/SuperManito/LinuxMirrors/main/ChangeMirrors.sh && chmod +x ChangeMirrors.sh && ./ChangeMirrors.sh
}

# 启动 Single 服务
function Single_Run_SmokePing(){
    print_msg "info" "启动 Single 服务"
    cd /opt/local/smokeping/bin
    ./smokeping --config=/opt/local/smokeping/etc/config --logfile=smoke.log
    supervisorctl reload
    change_access
}

# 启动 Master 服务
function Master_Run_SmokePing(){
    print_msg "info" "启动 Master 服务"
    cd /opt/local/smokeping/bin
    ./smokeping --config=/opt/local/smokeping/etc/config --logfile=smoke.log
    supervisorctl reload
    change_access
}

# 启动 Slaves 服务
function Slaves_Run_SmokePing(){
    print_msg "info" "启动 Slaves 服务"
    cd /opt/local/smokeping/bin
    ./smokeping --master-url=http://$server_name/smokeping.fcgi --cache-dir=/opt/local/smokeping/htdocs/cache --shared-secret=/opt/local/smokeping/etc/smokeping_secrets.dist --slave-name=$slaves_name --logfile=/opt/local/smokeping/slave.log
}

# 安装 Tcpping
function install_tcpping(){
    print_msg "info" "安装 Tcpping"
    $INS tcptraceroute
    rm -rf /usr/bin/tcpping
    wget -N --no-check-certificate https://raw.githubusercontent.com/ZMuSiShui/My-Shell/${github_branch}/smokeping/tcpping
    chmod 777 tcpping
    mv tcpping /usr/bin/
    print_msg "info" "安装 tcpping 完成"
}

# 卸载 SmokePing
function uninstall() {
    read -rp "已经安装 $mode2，是否卸载 [y/n]: " unins
    case $unins in
        [yY][eE][sS] | [yY])
            print_msg "info" "确认卸载"
            sleep 2
        ;;
        *)
            print_msg "error" "卸载已取消!"
            exit 2
        ;;
    esac
    kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
    rm -rf /opt/local/smokeping
    rm -rf /usr/bin/tcpping
    rm -rf /etc/supervisord.d/spawnfcgi.ini
    supervisorctl reload
    print_msg "info" "SmokePing 卸载完成!"
}

function set_passwd() {
    print_msg "info" "设置 Web 访问密码"
    sed -i 's/# //g' /etc/nginx/conf.d/smokeping.conf
    read -rp "请输入访问用户名: " web_username
    read -rp "请输入访问密码: " web_password
    htpasswd -bc /opt/local/smokeping/passwd $web_username $web_password
    [[ -e "/opt/local/smokeping/passwd" ]] && print_msg "info" "设置 Web 访问密码成功"
    nginx -s reload
}

function main() {
    check_user
    clear
    echo -e "\t SmokePing 一键管理脚本 ${Green}[${version}]${Font}"
    
    echo -e "当前已安装版本: ${shell_mode}"
    echo -e "—————————————— 安装向导 ——————————————"""
    echo -e "${Green}1.${Font}  安装 SmokePing Master端"
    echo -e "${Green}2.${Font}  安装 SmokePing Slaves端"
    echo -e "${Green}3.${Font}  安装 SmokePing 单机版"
    echo -e "${Green}4.${Font}  安装 Tcpping"
    echo -e "—————————————— 执行操作 ——————————————"
    echo -e "${Green}5.${Font}  启动 SmokePing"
    echo -e "${Green}6.${Font}  停止 SmokePing"
    echo -e "${Green}7.${Font}  重启 SmokePing"
    echo -e "—————————————— 其他选项 ——————————————"
    echo -e "${Green}8.${Font}  更换 Linux 软件源"
    echo -e "${Green}9.${Font}  设置 Web 访问密码"
    echo -e "${Green}10.${Font} 卸载 SmokePing"
    echo -e "${Green}0.${Font}  退出"
    echo -e "——————————————"
    check_status "smokeping"
    check_status "tcpping"
    read -rp "请输入数字: " menu_num
    case $menu_num in
        1)
            check_install "smokeping" "Master"
            install_somkeping "Master"
        ;;
        2)
            check_install "smokeping" "Slaves"
            install_somkeping "Slaves"
        ;;
        3)
            check_install "smokeping" "Single"
            install_somkeping "Single"
        ;;
        4)
            check_install "tcpping"
            install_tcpping
        ;;
        5)
            [[ ! -e ${smokeping_ver} ]] && echo -e "${ERROR} Smokeping 没有安装，请检查!" && exit 1
            ${mode}_Run_SmokePing
        ;;
        6)
            [[ ! -e ${smokeping_ver} ]] && echo -e "${ERROR} Smokeping 没有安装，请检查!" && exit 1
            kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
            supervisorctl stop spawnfcgi
        ;;
        7)
            [[ ! -e ${smokeping_ver} ]] && echo -e "${ERROR} Smokeping 没有安装，请检查!" && exit 1
            kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
            ${mode}_Run_SmokePing
        ;;
        8)
            change_mirrors
        ;;
        9)
            set_passwd
        ;;
        10)
            [[ ! -e ${smokeping_ver} ]] && echo -e "${ERROR} Smokeping 没有安装，请检查!" && exit 1
            uninstall
        ;;
        0)
            exit 0
        ;;
        *)
            print_msg "error" "请输入正确的数字"
        ;;
    esac
}
main "$@"