#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   setup-ssh-local.sh
# Mtime     :   2019-12-20
# Desc      :   Setup local DNS & SSH access to vagrant
# Path      :   bin/setup-ssh-local.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

#--------------------------------------------------------------#
# Name: setup_ssh
# Desc: Write ssh config to ~/.ssh/pigsty_config
# Note: Will add an Include line to ~/.ssh/config
#--------------------------------------------------------------#
function setup_ssh() {
	local conf_file="${HOME}/.ssh/config"
	local include_file="${HOME}/.ssh/pigsty_config"
	local include_str='Include ~/.ssh/pigsty_config'

	if [[ ! -d ${HOME}/.ssh ]]; then
		printf "\033[0;33m[WARN] ${HOME}/.ssh not exist, create \033[0m\n" >&2
		mkdir -p ${HOME}/.ssh
	fi
	if [[ ! -f ${conf_file} ]]; then
		printf "\033[0;33m[WARN] ${conf_file} not exist, create \033[0m\n" >&2
		touch ${conf_file}
	fi

	# write include str to the very first line of .ssh/config
	if grep --quiet "pigsty_config" ${conf_file}; then
		printf "\033[0;33m[WARN] ${conf_file} already contains ${include_str} , continue \033[0m\n" >&2
	else
		printf "\033[0;32m[INFO] write ${include_str} to ${conf_file} \033[0m\n" >&2
		(echo ${include_str} && cat ${conf_file}) >"${conf_file}.tmp" && mv "${conf_file}.tmp" ${conf_file}
	fi

	# get active vagrant nodes
	local active_node_list=$(vagrant status | grep running | awk '{print $1}' | xargs 2>/dev/null)
	if [[ $? != 0 ]]; then
		printf "\033[0;31m[ERROR] write ${include_str} to ${conf_file} \033[0m\n" >&2
		return 1
	fi

	# write pigsty config
	printf "\033[0;32m[INFO] update ${include_file} with active vagrant nodes: ${active_node_list} \033[0m\n" >&2
	vagrant ssh-config ${active_node_list} >${include_file} 2>/dev/null
	if [[ $? != 0 ]]; then
		printf "\033[0;31m[ERROR] vagrant ssh-config failed \033[0m\n" >&2
		return 2
	fi

	return 0
}


setup_ssh
