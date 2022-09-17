#!/bin/bash -e

/init.sh

exec tinc --net=${NETNAME} start \
          --no-detach \
	  --mlock \
          --debug=${VERBOSE} \
	  --pidfile=/opt/tinc/run/tinc.${NETNAME}.pid \
	  --logfile=/opt/tinc/logs/tinc.${NETNAME}.logs \
           "$@"
