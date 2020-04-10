#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   setup-node.sh
# Mtime     :   2020-01-19
# Desc      :   Setup Node Basic Environment
# Path      :   bin/setup-dns.sh
# Depend    :   CentOS 7
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as root (local or remote)
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

function setup_ssh() {
	local ssh_dir="/home/vagrant/.ssh"
	mkdir -p ${ssh_dir}

	# copy ssh key in bin/ssh, write authorized keys
	[ -f /vagrant/bin/ssh/id_rsa ] && cp /vagrant/bin/ssh/id_rsa ${ssh_dir}/id_rsa
	[ -f /vagrant/bin/ssh/id_rsa.pub ] && cp /vagrant/bin/ssh/id_rsa.pub ${ssh_dir}/id_rsa.pub
	[ -f ${ssh_dir}/id_rsa.pub ] && cat ${ssh_dir}/id_rsa.pub >>${ssh_dir}/authorized_keys

	# add important ssh config entry
	[ ! -f ${ssh_dir}/config ] && [ -f /vagrant/bin/ssh/config ] && cp /vagrant/bin/ssh/config ${ssh_dir}/config
	touch ${ssh_dir}/config
	if ! grep -q "StrictHostKeyChecking" ${ssh_dir}/config; then
		echo "StrictHostKeyChecking=no" >>${ssh_dir}/config
	fi

	# change permission
	chown -R vagrant ${ssh_dir}
	chmod 700 ${ssh_dir}
	chmod 600 ${ssh_dir}/*
	printf "\033[0;32m[INFO] setup_ssh complete \033[0m\n" >&2
}

function setup_dns() {
	if [[ $(whoami) != "root" ]]; then
		printf "\033[0;31m[INFO] setup-dns.sh require root privilege \033[0m\n" >&2
		return 1
	fi
	if $(grep 'pigsty dns records' /etc/hosts >/dev/null 2>&1); then
		printf "\033[0;33m[INFO]  dns already set in /etc/hosts, skip  \033[0m\n" >&2
		return 0
	fi

	# static resolv
	cat >>/etc/hosts <<-EOF
		# pigsty dns records

		# control nodes
		10.10.10.10   pigsty
		10.10.10.10   c.pigsty
		10.10.10.10   g.pigsty
		10.10.10.10   p.pigsty
		10.10.10.10   pg.pigsty
		10.10.10.10   am.pigsty
		10.10.10.10   yum.pigsty

		# physicla nodes
		10.10.10.10   n0
		10.10.10.11   n1
		10.10.10.12   n2
		10.10.10.13   n3
		10.10.10.10   node0
		10.10.10.11   node1
		10.10.10.12   node2
		10.10.10.13   node3

		# virtual IP
		10.10.10.2   cluster.testdb
		10.10.10.3   primary.testdb
		10.10.10.4	 standby.testdb
		10.10.10.5	 offline.testdb

		# biz cluster
		10.10.10.10   1.metadb
		10.10.10.11   1.testdb
		10.10.10.12   2.testdb
		10.10.10.13   3.testdb

		
	EOF

	if [[ $? != 0 ]]; then
		printf "\033[0;31m[INFO] write dns record failed \033[0m\n" >&2
		return 2
	fi

	printf "\033[0;32m[INFO] write dns records into /etc/hosts \033[0m\n" >&2
	return 0
}

function setup_resolver() {
	if $(grep 'nameserver 10.10.10.10' /etc/resolv.conf >/dev/null 2>&1); then
		printf "\033[0;33m[INFO] resolver already set in /etc/hosts, skip  \033[0m\n" >&2
		return 0
	fi
	echo 'nameserver 10.10.10.10' >>/etc/resolv.conf
	return 0
}

function main() {
	if [[ $(whoami) != "root" ]]; then
		printf "\033[0;31m[INFO] setup-dns.sh require root privilege \033[0m\n" >&2
		return 1
	fi

	setup_ssh

	setup_dns

	# setup_resolver

	# setup selinux
	sudo sed -ie 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	sudo setenforce 0

	# setup local yum repo
	cat >/etc/yum.repos.d/pigsty.repo <<-EOF
		[pigsty]
		name=Pigsty Yum Repo
		baseurl=http://yum.pigsty/pigsty/
		skip_if_unavailable = 1
		priority = 1
		gpgcheck = 0
		enabled = 1
	EOF

	# setup vagrant alias
	cat >/home/vagrant/.bashrc <<-'EOF'
		export EDITOR="vi"
		export PAGER="less"
		export LANG="en_US.UTF-8"
		export LC_ALL="en_US.UTF-8"
		export PS1="\[\033]0;\w\007\]\[\]\n\[\e[1;36m\][\D{%m-%d %T}] \[\e[1;31m\]\u\[\e[1;33m\]@\H\[\e[1;32m\]:\w \n\[\e[1;35m\]\$ \[\e[0m\]"
		alias a="cd /home/vagrant/ansible"
		alias p="sudo su - postgres"
		alias r="sudo su - root"
		alias st="sudo ntpdate -u time.pool.aliyun.com"
	EOF
	chmod 644 /home/vagrant/.bashrc
	chown vagrant:vagrant /home/vagrant/.bashrc

	return 0
}

main
