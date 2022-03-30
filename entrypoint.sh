#!/bin/bash -e

/init.sh

exec tinc --net=${NETNAME} start \
          --no-detach \
          --debug=${VERBOSE} \
	  --logfile=/opt/tinc/var/log/tinc.${NETNAME}.log \
           "$@"
