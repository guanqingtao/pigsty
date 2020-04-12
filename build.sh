#!/bin/bash

# clean existing cluster
vagrant halt
vagrant destroy -f --parallel

# setup
vagrant up node0 node1 node2 node3
bin/setup-ssh.sh
ssh node0 sudo /vagrant/control/setup.sh &

# copy yum cache to localhost to accelerate next bootsrtrap (if not exists)
if [[ ! -d control/yum ]]; then
	echo "copy yum cache to localhost ${PWD}/control/yum"
	scp -r node0:/www/pigsty control/yum
fi

# init cluster
ssh node0 'cd ansible && ./init-cluster.yml'
