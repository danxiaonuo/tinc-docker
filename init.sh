#!/bin/sh -e
#
# initialize server profile
#

# 定义网络名称
tee /etc/tinc/nets.boot<<-'EOF'
${NETWORK}
EOF

设置 tinc.conf 文件
cat > /etc/tinc/${NETWORK}/tinc.conf<<-'EOF'
#对应节点主机名字
Name = ${NODE}
#网卡名称
Interface = danxiaonuo 
#Mode 有三种模式，分别是<router|switch|hub> (router) ,相对应我们平时使用到的路由、交换机、集线器 (默认模式 router)
Mode = switch 
#数据包压缩级别
Compression = 11 
#加密类型
Cipher  = id-aes256-GCM 
#rsa加密协议强度
Digest = whirlpool
# MAC长度
MACLength = 16
#MTU值
PMTU = 1500
#服务器私钥的位置
PrivateKeyFile = /etc/tinc/${NODE}/rsa_key.priv
EOF

# 设置主动连接节点
peers=$(echo "$PEERS" | tr " " "\n")
for host in $peers
do
    echo "ConnectTo = ""$host" >> /etc/tinc/${NETWORK}/tinc.conf
done

# 设置hosts文件
cat > /etc/tinc/${NETWORK}/hosts/${NODE}<<-'EOF'
#公网IP地址
Address = ${PUBLIC_IP}
#定义tinc内网网段
Subnet= ${PRIVATE_IPV4}/32
Subnet= ${PRIVATE_IPV6}/128
#路由器内网网段
Subnet= 0.0.0.0/0
Subnet= ::/0
#监听端口
Port= ${TINC_PORT}
EOF

cat > /etc/tinc/${NETWORK}/tinc-up<<-'EOF'
#!/bin/sh
ip link set \$INTERFACE up mtu 1500
ip -6 link set \$INTERFACE up mtu 1500
ip addr add ${PRIVATE_IPV4}/24 dev \$INTERFACE
ip -6 addr add ${PRIVATE_IPV6}/64 dev \$INTERFACE
ip -6 route add default via ${PRIVATE_IPV6}
EOF

cat > /etc/tinc/${NETWORK}/tinc-down<<-'EOF'
#!/bin/sh
ip route del ${PRIVATE_IPV4}/24 dev $INTERFACE
ip -6 route del ${PRIVATE_IPV6}/64 dev $INTERFACE
ip -6 route del default via ${PRIVATE_IPV6}
ip link set $INTERFACE down
ip -6 link set $INTERFACE dow
EOF

# 生成 RSA 公钥和私钥
tincd -n ${NETWORK} -K${KEYSIZE}
# 设置文件权限
chmod -R 775 /etc/tinc/${NETWORK}/tinc-*
