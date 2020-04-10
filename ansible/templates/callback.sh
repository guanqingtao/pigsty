#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   callback.sh
# Mtime     :   2020-04-07
# Desc      :   Patroni event callback scripts
# Path      :   /pg/bin/callback.sh
# Depend    :   CentOS 7
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as dbsu (postgres)
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

#==============================================================#
function usage() {
	cat <<-'EOF'
		NAME
			callback.sh event role cluster
		
		SYNOPSIS
			This is patroni pg event callback scripts
	EOF
	exit 1
}
#==============================================================#

function pg_role_change_handler() {
	local role=$1
	local cluster=$2
	printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][${HOSTNAME}][PG ROLE CHANGE] [cluster=${cluster}] [newrole=${role}]\033[0m\n" >>/pg/log/event.log

	# update consul registered service according to new role
	case ${role} in
	master)
		role="primary"
		echo '{"node_meta": {"role": "primary"}}' >/etc/consul.d/meta-role.json
		cat >/etc/consul.d/srv-{{ cluster }}.json <<-'EOF'
			{"service": {
				"name": "{{ cluster }}",
				"port": 6432,
				"tags": ["primary", "{{ seq }}"],
				"check": {"http": "http://{{ inventory_hostname }}:8008/master","interval": "5s"}
			}}
		EOF
		;;
	replica)
		role="standby"
		cat >/etc/consul.d/srv-{{ cluster }}.json <<-'EOF'
			{"service": {
				"name": "{{ cluster }}",
				"port": 6432,
				"tags": ["standby", "{{ seq }}"],
				"check": {"http": "http://{{ inventory_hostname }}:8008/replica","interval": "5s"}
			}}
		EOF
		echo '{"node_meta": {"role": "standby"}}' >/etc/consul.d/meta-role.json
		;;
	*)
		# DO NOTHING
		role="standby"
		;;
	esac

	# TODO: call other callbacks, chagne VIP, DNS, or write DCS, send notifications

	# restart to take effect
	consul reload
	sudo systemctl restart consul
	exit 0
}

function pg_stop_handler() {
	local role=$1
	local cluster=$2
	printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][${HOSTNAME}][PG STOP] [cluster=${cluster}] [role=${role}]\033[0m\n" >>/pg/log/event.log
	exit 0
}

function pg_start_handler() {
	local role=$1
	local cluster=$2
	printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][${HOSTNAME}][PG START] [cluster=${cluster}] [role=${role}]\033[0m\n" >>/pg/log/event.log
	exit 0
}

function main() {
	local action=$1
	shift

	case $action in
	on_stop)
		pg_stop_handler $@
		;;
	on_start)
		pg_start_handler $@
		;;
	on_role_change)
		pg_role_change_handler $@
		;;
	*)
		usage
		;;
	esac
}

main $@
