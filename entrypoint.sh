#!/bin/sh -e

/init.sh

exec tinc --net=${NETNAME} start \
          --no-detach \
          --debug=${VERBOSE} \
	  --logfile=/var/log/tinc.${NETNAME}.log \
           "$@"
