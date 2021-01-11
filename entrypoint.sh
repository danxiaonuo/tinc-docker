#!/bin/sh -e

/init.sh

if ! [[ -c /dev/net/${NETWORK} ]]
then
    mkdir -p /dev/net
    mknod /dev/net/${NETWORK} c 10 200
fi

if [[ $NODE != server ]]
then
   sed -i -e '/公网IP地址/d' -e '/Address/d' /etc/tinc/${NETWORK}/hosts/${NODE} 
fi

exec tincd --no-detach \
           --net=${NETNAME} \
           --debug=${VERBOSE} \
           "$@"
