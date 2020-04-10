#!/bin/bash

# clean existing cluster
vagrant halt
vagrant destroy -f --parallel

# setup node0 asynchronously
vagrant up node0
bin/setup-ssh.sh
ssh node0 sudo /vagrant/control/setup.sh &

# pull up other 3 db nodes
vagrant up node1 node2 node3
bin/setup-ssh.sh

# cache yum to bootstrap next vagrant up
# control/cache.sh

# init cluster
ssh node0 'cd ansible && ./init-cluster.yml'
