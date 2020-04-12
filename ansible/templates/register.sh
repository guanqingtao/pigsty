#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   register.sh
# Mtime     :   2020-04-07
# Desc      :   register service to consul
# Path      :   /pg/bin/register.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Make sure /etc/consul.d is writtable
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

# Example:  register.sh standby testdb will reset monitor identity to standby.testdb

function main() {
	local role=$1
	local cluster=$2
	local patroni_role=$1

	# update consul registered service according to new role

	case ${role} in
	primary|p|master|m|leader|l)
		role="primary"
		patroni_role="master"
		;;
	standby|s|replica|r|slave)
		role="standby"
		patroni_role="replica"
		;;
	offline|o|delayed|d)
		role="offline"
		patroni_role="replica"
		;;
	*)
		echo "monitor.sh <cluster> <role>"
		exit 1
		;;
	esac

	# refresh consul registered service

	# node exporter
	cat >/etc/consul.d/srv-node_exporter.json <<-EOF
		{"service": {
			"name": "node_exporter",
			"port": 9100,
			"meta": {
				"type": "exporter",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["exporter"],
			"check": {"http": "http://{{ inventory_hostname }}:9100/", "interval": "5s"}
		}}
	EOF

	# pg_exporter
	cat >/etc/consul.d/srv-pg_exporter.json <<-EOF
		{"service": {
			"name": "pg_exporter",
			"port": 9630,
			"meta": {
				"type": "exporter",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["exporter"],
			"check": {"http": "http://{{ inventory_hostname }}:9630/", "interval": "5s"}
		}}
	EOF

	# pgbouncer_exporter
	cat >/etc/consul.d/srv-pgbouncer_exporter.json <<-EOF
		{"service": {
			"name": "pgbouncer_exporter",
			"port": 9631,
			"meta": {
				"type": "exporter",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["exporter"],
			"check": {"http": "http://{{ inventory_hostname }}:9631/", "interval": "5s"}
		}}
	EOF

	# postgres
	cat >/etc/consul.d/srv-postgres.json <<-EOF
		{"service": {
			"name": "postgres",
			"port": 5432,
			"meta": {
				"type": "postgres",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["${role}", "{{ cluster }}"],
			"check": {"tcp": "{{ inventory_hostname }}:5432", "interval": "5s"}
		}}
	EOF

	# pgbouncer
	cat >/etc/consul.d/srv-pgbouncer.json <<-EOF
		{"service": {
			"name": "pgbouncer",
			"port": 6432,
			"meta": {
				"type": "postgres",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["${role}", "{{ cluster }}"],
			"check": {"tcp": "{{ inventory_hostname }}:6432", "interval": "5s"}
		}}
	EOF

	# patroni
	cat >/etc/consul.d/srv-patroni.json <<-EOF
		{"service": {
			"name": "patroni",
			"port": 8008,
			"meta": {
				"type": "patroni",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["${role}", "{{ cluster }}"],
			"check": {"tcp": "{{ inventory_hostname }}:8008", "interval": "5s"}
		}}
	EOF

	# database service (export to application)
	cat >/etc/consul.d/srv-{{ cluster }}.json <<-EOF
		{"service": {
			"name": "${cluster}",
			"port": 6432,
			"meta": {
				"type": "db",
				"role": "${role}",
				"cluster": "{{ cluster }}",
				"service": "${role}.{{ cluster }}",
				"instance": "{{seq}}.{{ cluster }}"
			},
			"tags": ["${role}", "{{ seq }}"],
			"check": {
			  "http": "http://{{ inventory_hostname }}:8008/${patroni_role}", "interval": "5s"
			}
		}}
	EOF

	chown postgres:consul /etc/consul.d/srv-*
	consul reload

	printf "[$(date "+%Y-%m-%d %H:%M:%S")][${HOSTNAME}][event=reigster] [cluster=${cluster}] [role=${role}]\n" >>/pg/log/register.log
	exit 0
}

main $@
