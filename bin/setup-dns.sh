#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   setup-dns.sh
# Mtime     :   2019-12-20
# Desc      :   Setup DNS for pg testing env
# Path      :   bin/setup-dns.sh
# Depend    :   CentOS 7
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as root (local or remote)
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

#--------------------------------------------------------------#
# Name: setup_dns
# Desc: Write pgtest DNS entries to /etc/hosts
# Note: Run this in localhost and virtual machines
#--------------------------------------------------------------#
function setup_dns() {
	if [[ $(whoami) != "root" ]]; then
		printf "\033[0;31m[INFO] setup-dns.sh require root privilege \033[0m\n" >&2
		return 1
	fi
	if $(grep 'pigsty dns records' /etc/hosts >/dev/null 2>&1); then
		printf "\033[0;33m[INFO]  dns already set in /etc/hosts, skip  \033[0m\n" >&2
		return 0
	fi

	cat >>/etc/hosts <<-EOF
		
		# pigsty dns records
		
		10.10.10.10   n0
		10.10.10.11   n1
		10.10.10.12   n2
		10.10.10.13   n3
		
		10.10.10.10   node0
		10.10.10.11   node1
		10.10.10.12   node2
		10.10.10.13   node3
		
		10.10.10.10   pigsty
		10.10.10.10   c.pigsty
		10.10.10.10   g.pigsty
		10.10.10.10   p.pigsty
		10.10.10.10   pg.pigsty
		10.10.10.10   am.pigsty
		10.10.10.10   yum.pigsty
		
	EOF

	if [[ $? != 0 ]]; then
		printf "\033[0;31m[INFO] write dns record failed \033[0m\n" >&2
		return 2
	fi

	printf "\033[0;32m[INFO] write dns records into /etc/hosts \033[0m\n" >&2
	return 0
}

setup_dns
