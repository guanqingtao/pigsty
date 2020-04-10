#!/bin/bash

# generate some load to primary instance

export PGURL='postgres://dbuser_test:dbuser_test@10.10.10.11:6432/testdb'
pgbench -i -s 32 ${PGURL}
pgbench -n -v -T 256 ${PGURL}
