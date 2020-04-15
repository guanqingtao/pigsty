#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   setup.sh
# Mtime     :   2019-12-20
# Desc      :   Setup Control Node of pigsty
# Path      :   control/setup.sh
# Depend    :   CentOS 7
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as root
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

#==============================================================#
#                             Usage                            #
#==============================================================#
function usage() {
	cat <<-'EOF'
		NAME
			control/setup.sh
		
		SYNOPSIS
			control/setup.sh
		
			bootstrap pigsty control node
		
			it may takes a long time for first time launch (download 500M yum pkgs)
			after that, run control/cache.sh will cache yum packages
			and bootstrap from cache will be a lot faster
		
		DESCRIPTION
			create os group:user ${user} (256:256)
			create dir PG_ROOT=/exporter PG_BKUP=/var/backup
			setup sudo ulimit bashrc for $dbsu
			install pgdg repo
			install postgresql packages
			install postgresql systemd service (CentOS7)
	EOF
	exit 1
}

#--------------------------------------------------------------#
# Name: install_yum_repo
# Note: write prometheus, grafana, nginx, pgdg repodefinition
#       to /etc/yum.repos.d
#--------------------------------------------------------------#
function install_yum_repo() {
	printf "\033[0;32m[INFO] install_yum_repo: write repo files to /etc/yum.repos.d/ \033[0m\n" >&2
	rm -rf /etc/yum.repos.d/{prometheus,grafana,pigsty,nginx,pgdg-redhat-all}.repo

	# alternative: pgdg & nginx rpm: origin source
	# curl -s -o pgdg-redhat-repo-latest.noarch.rpm -s https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
	# curl -s -o nginx-release-centos-7-0.el7.ngx.noarch.rpm http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
	# rpm -i pgdg-redhat-repo-latest.noarch.rpm
	# rpm -i nginx-release-centos-7-0.el7.ngx.noarch.rpm

	# pgdg repo
	cat >/etc/yum.repos.d/pgdg-redhat-all.repo <<-'EOF'
		# PGDG Red Hat Enterprise Linux / CentOS stable repositories:
		
		[pgdg12]
		name=PostgreSQL 12 for RHEL/CentOS $releasever - $basearch
		baseurl=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-$releasever-$basearch
		enabled=1
		gpgcheck=0
		
		[pgdg11]
		name=PostgreSQL 11 for RHEL/CentOS $releasever - $basearch
		baseurl=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-$releasever-$basearch
		enabled=1
		gpgcheck=0
		
		[pgdg10]
		name=PostgreSQL 10 for RHEL/CentOS $releasever - $basearch
		baseurl=https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-$releasever-$basearch
		enabled=1
		gpgcheck=0
		
		[pgdg96]
		name=PostgreSQL 9.6 for RHEL/CentOS $releasever - $basearch
		baseurl=https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-$releasever-$basearch
		enabled=1
		gpgcheck=0
		
		[pgdg95]
		name=PostgreSQL 9.5 for RHEL/CentOS $releasever - $basearch
		baseurl=https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-$releasever-$basearch
		enabled=1
		gpgcheck=0
		
		[pgdg94]
		name=PostgreSQL 9.4 for RHEL/CentOS $releasever - $basearch
		baseurl=https://download.postgresql.org/pub/repos/yum/9.4/redhat/rhel-$releasever-$basearch
		enabled=1
		gpgcheck=0
		
		[pgdg13-updates-testing]
		name=PostgreSQL 13 for RHEL/CentOS $releasever - $basearch - Updates testing
		baseurl=https://download.postgresql.org/pub/repos/yum/testing/13/redhat/rhel-$releasever-$basearch
		enabled=0
		gpgcheck=0
		
	EOF

	# nginx repo
	cat >/etc/yum.repos.d/nginx.repo <<-'EOF'
		[nginx]
		name=nginx repo
		baseurl=http://nginx.org/packages/centos/7/$basearch/
		gpgcheck=0
		enabled=1
	EOF

	# prometheus repo
	cat >/etc/yum.repos.d/prometheus.repo <<-'EOF'
		[prometheus]
		name=prometheus
		baseurl=https://packagecloud.io/prometheus-rpm/release/el/$releasever/$basearch
		repo_gpgcheck=1
		enabled=1
		gpgkey=https://packagecloud.io/prometheus-rpm/release/gpgkey
		       https://raw.githubusercontent.com/lest/prometheus-rpm/master/RPM-GPG-KEY-prometheus-rpm
		gpgcheck=1
		metadata_expire=3000
	EOF

	# grafana repo
	cat >/etc/yum.repos.d/grafana.repo <<-'EOF'
		[grafana]
		name=grafana
		baseurl=https://packages.grafana.com/oss/rpm
		repo_gpgcheck=1
		enabled=1
		gpgcheck=1
		gpgkey=https://packages.grafana.com/gpg.key
		sslverify=1
		sslcacert=/etc/pki/tls/certs/ca-bundle.crt
		metadata_expire=3000
	EOF
}

#--------------------------------------------------------------#
# Name: write_nginx_files
# Note: setup nginx.conf index.html and pigsty repo download url
# List:
#    - /etc/nginx/conf.d/nginx.conf
#    - /www/index.html
#    - /www/pigsty.repo
#--------------------------------------------------------------#
function write_nginx_files() {
	printf "\033[0;32m[INFO] write_nginx_files: /etc/nginx/conf.d/nginx.conf /www/index.html /www/pigsty.repo  \033[0m\n" >&2
	rm -rf /etc/nginx/conf.d/*
	mkdir -p /etc/nginx/conf.d/

	if [[ -f /vagrant/control/nginx/nginx.conf ]]; then
		cp -f /vagrant/control/nginx/nginx.conf /etc/nginx/conf.d/nginx.conf
	else
		cat >/etc/nginx/conf.d/nginx.conf <<-'EOF'
			server {
				listen       80;
				server_name  *.pigsty;
				location / {
					root   /www;
					index  index.html index.htm;
					autoindex on;
					autoindex_exact_size on;
					autoindex_localtime on;
					autoindex_format html;
				}
			
				location /nginx_status {
					stub_status on;
					access_log off;
				}
			}
			server {
				listen       80;
				server_name  g.pigsty;
				location / {
					proxy_pass http://localhost:3000/;
				}
			}
			server {
				listen       80;
				server_name  pg.pigsty;
				location / {
					proxy_pass http://localhost:5050/;
				}
			}
			server {
				listen       80;
				server_name  c.pigsty;
				location / {
					proxy_pass http://localhost:8500/;
				}
			}
			server {
				listen       80;
				server_name  p.pigsty;
				location / {
					proxy_pass http://localhost:9090/;
				}
			}
			server {
				listen       80;
				server_name  am.pigsty;
				location / {
					proxy_pass http://localhost:9093/;
				}
			}
			server {
				listen       80;
				server_name  ha.pigsty;
				location / {
					proxy_pass http://localhost:8000/;
				}
			}
		EOF
	fi

	if [[ -d /vagrant/control/nginx/www ]]; then
		cp -rf /vagrant/control/nginx/www/* /www/
	else
		cat >/www/index.html <<-'EOF'
			<html lang="en"><head><title>Pigsty Home</title></head><br>
			<h1>Pigsty -- PostgreSQL Testing Environment</h1>
			<div><ul>
					<li><h2><a href="http://pigsty">Home</a></h2></li>
					<li><h2><a href="http://c.pigsty">Consul</a></h2></li>
					<li><h2><a href="http://g.pigsty">Grafana</a></h2></li>
					<li><h2><a href="http://p.pigsty">Prometheus</a></h2></li>
					<li><h2><a href="http://pg.pigsty">PgAdmin4</a></h2></li>
					<li><h2><a href="http://am.pigsty">Alertmanager</a></h2></li>
					<li><h2><a href="http://yum.pigsty/pigsty">Yum Repo</a></h2></li>
			</ul></div>
			</br><p><code>curl -s  -o /etc/yum.repos.d/pigsty.repo http://pigsty/pigsty.repo</code></p></br>
			</body></html>
		EOF

		cat >/www/pigsty.repo <<-'EOF'
			[pigsty]
			name=Pigsty Yum Repo
			baseurl=http://yum.pigsty/pigsty/
			skip_if_unavailable = 1
			priority = 1
			gpgcheck = 0
			enabled = 1
		EOF
	fi
}

#--------------------------------------------------------------#
# Name: yum_bootstrap
# Desc: create and download necessary asset for local yum
# inventory:
#	 * prometheus:	prometheus.repo
#	 * grafana:		grafana.repo
#	 * local yum:	pigsty.repo
#	 * nginx:		nginx-release-centos-7-0.el7.ngx.noarch.rpm
#	 * postgres:	pgdg-redhat-repo-latest.noarch.rpm
#
#    * nginx conf:	nginx.conf
#    * homepage:	index.html
#    * packages:	nginx, epel-release, wget, yum-utils
#
#    if cache dir is provided (which is a copy of /www/pigsty)
#    it will bootstrap from cache to accelerate
#--------------------------------------------------------------#
function yum_bootstrap() {
	local cache_dir="/vagrant/control/yum"
	# if cache dir is properly bootstraped last time, bootstrap from cache
	if [[ -f ${cache_dir}/boot/ok ]]; then
		yum_bootstrap_from_cache
		return $?
	fi

	# otherwise perform normal boostrap and create cache properly
	printf "\033[0;32m[INFO] yum_bootstrap: mkdir -p /www/pigsty/boot \033[0m\n" >&2
	rm -rf /www
	mkdir -p /www/pigsty/boot
	cd /www/pigsty/boot

	# setup yum repo, and download and install bootstrap packages
	install_yum_repo
	printf "\033[0;32m[INFO] yum_bootstrap: download and install bootstrap packages \033[0m\n" >&2
	yumdownloader -y --resolve nginx epel-release yum-utils yum-priorities wget createrepo && yum localinstall -q -y *.rpm
	if [[ $? != 0 ]]; then
		printf "\033[0;31m[ERROR] yum_bootstrap: fail to download bootstrap packages \033[0m\n" >&2
		return 1
	fi

	# download real packages
	printf "\033[0;32m[INFO] yum_bootstrap: download local yum packages to /www/pigsty \033[0m\n" >&2
	cd /www/pigsty
	cp -rf /www/pigsty/boot/* .
	yumdownloader -y --resolve \
		ntp uuid readline lz4 nc pv jq vim bash libxml2 libxslt lsof wget unzip git zlib openssl openssl-libs bind-utils net-tools sysstat \
		bind-utils net-tools sysstat dnsutils dnsmasq keepalived haproxy \
		rpm-build rpm-devel rpmlint make bash coreutils diffutils patch rpmdevtools \
		python python-pip python-ipython python2-psycopg2 ansible \
		'postgresql12*' 'postgresql11*' 'postgresql10*' 'postgresql96*' \
		'postgis30_12*' 'postgis30_11*' 'postgis30_10*' 'postgis30_96*' \
		'pgbouncer*' 'pgpool-II-12*' wal2json12 wal2json12-debuginfo pg_repack12 pg_stat_kcache12 pg_stat_kcache12-debuginfo pgrouting_12 pgadmin4 \
		nginx grafana prometheus2 pushgateway alertmanager \
		node_exporter postgres_exporter nginx_exporter consul_exporter ping_exporter redis_exporter blackbox_exporter \
		etcd consul
	if [[ $? != 0 ]]; then
		printf "\033[0;31m[ERROR] yum_bootstrap: fail to download yum packages \033[0m\n" >&2
		return 2
	fi

	# download some 3rd party packages
	# download pg_exporter from Github
	printf "\033[0;32m[INFO] yum_bootstrap: download pg_exporter \033[0m\n" >&2
	wget https://github.com/Vonng/pg_exporter/releases/download/v0.2.0/pg_exporter-0.2.0-1.el7.x86_64.rpm

	printf "\033[0;32m[INFO] yum_bootstrap: download patroni \033[0m\n" >&2
	wget https://github.com/cybertec-postgresql/patroni-packaging/releases/download/1.6.4-2/patroni-1.6.4-2.rhel7.x86_64.rpm

	printf "\033[0;32m[INFO] yum_bootstrap: download consul \033[0m\n" >&2
	wget https://copr-be.cloud.fedoraproject.org/results/harbottle/main/epel-7-x86_64/01309161-consul/consul-1.7.2-1.el7.harbottle.x86_64.rpm

	# create repo (yum is ready after nginx start)
	printf "\033[0;32m[INFO] yum_bootstrap: createrepo on /www/pigsty \033[0m\n" >&2
	createrepo .

	# write nginx files
	printf "\033[0;32m[INFO] yum_bootstrap: setup nginx \033[0m\n" >&2
	write_nginx_files
	systemctl enable nginx
	systemctl start nginx

	# install repo definition via nginx
	sleep 1s
	curl -s -o /etc/yum.repos.d/pigsty.repo http://localhost/pigsty.repo
	if [[ $? != 0 ]]; then
		printf "\033[0;31m[ERROR] yum_bootstrap: fail to access repo file from nginx \033[0m\n" >&2
		return 3
	fi
	touch /www/pigsty/boot/ok
	printf "\033[0;32m[INFO] yum_bootstrap: complete \033[0m\n" >&2
	cd -
}

#--------------------------------------------------------------#
# Name: yum_bootstrap_from_cache
# Desc: this will bootstrap a yum repo from cache
#    Presumption:
#    /www/pigsty is a dir initialized by yum_bootstrap before
#	 /www/pigsty/boot contains bootstrap assets
#	 /www/pigsty/boot/ok is set which indicate a success bootstrap
#--------------------------------------------------------------#
function yum_bootstrap_from_cache() {
	local cache_dir=${1-"/vagrant/control/yum"}

	# if flag is not set properly
	if [[ ! -f ${cache_dir}/boot/ok ]]; then
		printf "\033[0;31m[INFO] yum_bootstrap_from_cache: invalid cache directory ${cache_dir} \033[0m\n" >&2
		return 1
	fi

	# copy cache dir to /www/pigsty
	printf "\033[0;32m[INFO] yum_bootstrap_from_cache: copy cache dir ${cache_dir} to /www/pigsty \033[0m\n" >&2
	rm -rf /www && mkdir /www
	cp -rf ${cache_dir} /www/pigsty
	cd /www/pigsty/boot

	# install all bootstrap packages from /www/pigsty/boot
	printf "\033[0;32m[INFO] yum_bootstrap_from_cache: install bootstrap packages from /www/pigsty/boot \033[0m\n" >&2
	rm -rf /etc/yum.repos.d/pigsty.repo
	yum localinstall -q -y *.rpm

	# setup nginx
	printf "\033[0;32m[INFO] yum_bootstrap_from_cache: setup nginx \033[0m\n" >&2
	write_nginx_files
	systemctl enable nginx
	systemctl start nginx

	# install repo definition via nginx
	sleep 1s
	curl -s -o /etc/yum.repos.d/pigsty.repo http://localhost/pigsty.repo
	if [[ $? != 0 ]]; then
		printf "\033[0;31m[ERROR] yum_bootstrap_from_cache: fail to access repo file from nginx \033[0m\n" >&2
		return 3
	fi
	touch /www/pigsty/boot/ok
	printf "\033[0;32m[INFO] yum_bootstrap_from_cache: complete \033[0m\n" >&2

	cd -
}

#--------------------------------------------------------------#
# setup control nodes
# local yum server already available @ localhost:80
#
# components:
#
# consul server listen 			@ 8500
# grafana server listen 		@ 3000
# pgadmin4 server listen 		@ 5050
# prometheus server listen 		@ 9090
# alertmanager server listen 	@ 9093
#
# domains:
#
# http://g.pigsty   -> Grafana      @ 3000
# http://pg.pigsty  -> PgAdmin4   	@ 5050
# http://c.pigsty   -> Consul      	@ 8500
# http://p.pigsty   -> Prometheus   @ 9090
# http://am.pigsty 	-> Alertmanager @ 9093
# http://yum.pigsty	-> Yum Repo		@ 80
#--------------------------------------------------------------#
function setup_control() {
	local yumcmd="yum"
	if [[ -f /etc/yum.repos.d/pigsty.repo ]]; then
		yumcmd='yum install --disablerepo=* --enablerepo=pigsty'
	fi
	${yumcmd} -q -y \
		prometheus2 alertmanager grafana consul etcd postgresql12 postgresql12-server \
		node_exporter pg_exporter consul_exporter nginx_exporter \
		python-pip python-ipython python2-psycopg2 ansible \
		ntp lz4 nc jq pv git bind-utils net-tools sysstat dnsutils pgadmin4 dnsmasq haproxy keepalived

	# setup postgresql tools
	ln -s /usr/pgsql-12 /usr/pgsql
	echo 'export PATH=/usr/pgsql/bin:/pg/bin:$PATH' >/etc/profile.d/pgsql.sh

	# setup prometheus
	local prometheus_dir="${PROG_DIR-'.'}/prometheus"
	if [[ -d ${prometheus_dir} ]]; then
		cp -rf ${prometheus_dir}/* /etc/prometheus/
		chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
	fi

	# setup grafana
	local grafana_dir="${PROG_DIR-'.'}/grafana"
	if [[ -d ${grafana_dir} ]]; then
		[[ -f ${grafana_dir}/grafana.ini ]] && cp -f ${grafana_dir}/grafana.ini /etc/grafana/grafana.ini
		[[ -f ${grafana_dir}/grafana.db ]] && cp -f ${grafana_dir}/grafana.db /var/lib/grafana/grafana.db
		chown -R grafana:grafana /etc/grafana /var/lib/grafana
	fi

	# setup consul
	if [[ -f "${PROG_DIR-'.'}/consul.json" ]]; then
		rm -rf /etc/consul.d/*
		cp -f "${PROG_DIR-'.'}/consul.json" /etc/consul.d/consul.json
		chown -R consul:consul /etc/consul.d
	fi

	# add consul service
	cat >/usr/lib/systemd/system/consul.service <<-'EOF'
		[Unit]
		Description="HashiCorp Consul - A service mesh solution"
		Documentation=https://www.consul.io/
		Requires=network-online.target
		After=network-online.target
		
		[Service]
		User=consul
		Group=consul
		ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
		ExecReload=/usr/bin/consul reload
		KillMode=process
		Restart=on-failure
		LimitNOFILE=65536
		
		[Install]
		WantedBy=multi-user.target
	EOF
	ntpdate -u pool.ntp.org

	# copy ansible playbooks
	if [[ -d /vagrant/ansible ]]; then
		rm -rf /home/vagrant/ansible
		cp -rf /vagrant/ansible /home/vagrant/ansible
		chown -R vagrant:vagrant /home/vagrant/ansible
	fi

	# setup dnsmasq
	cat >/etc/dnsmasq.d/config <<-'EOF'
		port=53
		listen-address=10.10.10.10
		server=/consul/127.0.0.1#8600
	EOF

	# setup keepalived
	if [[ -f /vagrant/control/keepalived.conf ]]; then
		cp -f /vagrant/control/keepalived.conf /etc/keepalived/keepalived.conf
	fi
	systemctl start keepalived

	# setup haproxy
	if [[ -f /vagrant/control/haproxy.cfg ]]; then
		cp -f /vagrant/control/haproxy.cfg /etc/haproxy/haproxy.cfg
	fi
	systemctl start haproxy

	# launch services
	systemctl daemon-reload
	systemctl enable ntpd
	systemctl enable consul
	systemctl enable dnsmasq
	systemctl enable haproxy
	systemctl enable keepalived
	systemctl enable prometheus
	systemctl enable alertmanager
	systemctl enable grafana-server

	systemctl start ntpd
	systemctl start consul
	systemctl start dnsmasq
	systemctl start prometheus
	systemctl start alertmanager
	systemctl start grafana-server

	# setup pgadmin4 (this stupid software is broken ,require manual setup)
	pip2 install flask_compress
	if [[ -f /vagrant/control/pgadmin4.db ]]; then
		cp -f /vagrant/control/pgadmin4.db /etc/haproxy/pgadmin4.db
	fi
	systemctl enable pgadmin4
	systemctl start pgadmin4

}

#--------------------------------------------------------------#
# setup control node main
#
#  all   : both yum and pkges (default)
#  yum   : only create local yum repo
#  pkg   : only setup control nodes
#  repo  : only write yum repo files to /etc/yum.repos.d
#  nginx : only write nginx related files
#--------------------------------------------------------------#
function main() {
	# precheck
	if [[ "$(whoami)" != "root" ]]; then
		printf "\033[0;31m[ERROR] permission denied: run this as root \033[0m\n" >&2
		return 1
	fi

	local os_release=$(cat /etc/redhat-release)
	if [[ ${os_release} != "CentOS Linux release 8"* && ${os_release} != "CentOS Linux release 7"* ]]; then
		printf "\033[0;31m[ERROR] unsupported linux version: ${os_release} \033[0m\n" >&2
		return 2
	fi

	yum_bootstrap
	setup_control

	printf "\033[0;32m[INFO] control/setup.sh done: http://pigsty \033[0m\n" >&2
}

main $@

sleep 15
systemctl restart haproxy
