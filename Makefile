new: clean up

###############################################################
# local environment setup
# you have to setup ssh & dns before connecting to vm nodes
###############################################################
# setup local host DNS, require sudo, one-time setup
dns:
	sudo bin/setup-dns.sh

# setup local ssh connectivity, execute when nodes define changes
ssh:
	bin/setup-ssh.sh

###############################################################
# vm management
###############################################################
status:
	vagrant status

up:
	vagrant up
	bin/setup-ssh.sh

suspend:
	vagrant suspend

halt:
	vagrant halt

resume:
	vagrant resume

clean: halt
	vagrant destroy -f --parallel

control:
	ssh node0 sudo /vagrant/control/setup.sh

# sync node clock via ntp
sync-time:
	echo node0 node1 node2 node3 | xargs -n1 -P4 -I{} ssh {} sudo ntpdate -u time.pool.aliyun.com

# sync playbooks
sync:
	ssh node0 rm -rf ansible/*
	scp -r ansible/* node0:~/ansible/

# copy yum dir to accelerate next vm creation
cache:
	control/cache.sh

###############################################################
# postgres operation
###############################################################
init:
	ssh node0 'cd ansible && ./init-cluster.yml'

deploy:
	node/primary.test.pg/deploy init
	node/monitor/deploy init


test:
	ssh primary sudo -iu postgres pgbench test -T1800 -c5 -n


###############################################################
# monitor management
###############################################################
view:
	open 'http://node3:3000/d/yQg0oM_ik/db-module?orgId=1&from=now-30m&to=now&refresh=1m'

prom:
	open http://monitor:9090

dump-monitor:
	scp node0:/var/lib/grafana/grafana.db control/grafana/grafana.db

dump-pgadmin:
	ssh node0 "sudo cp /var/lib/pgadmin/pgadmin4.db /tmp/pgadmin4.db;sudo chmod a+r /tmp/pgadmin4.db"
	scp node0:/tmp/pgadmin4.db control/pgadmin4.db

.PHONY: new dns ssh status up suspend halt resume clean cache control sync-time sync-playbook yum-cache download download-yum init initdb deploy test view prom dump-monitor
