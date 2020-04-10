#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   cache-yum.sh
# Mtime     :   2020-03-22
# Desc      :   copy yum cache from bootstrapped control node
# Path      :   control/cache.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   run @ your local host machine
# Note		:	copy node0:/www/pigsty -> pigsty/control/yum
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

# assume node0 access via ssh, and /www/pigsty is already bootstrapped
rm -rf ${PROG_DIR}/yum && scp -r node0:/www/pigsty ${PROG_DIR}/yum
