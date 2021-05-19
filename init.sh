#!/bin/sh -e

if [[ $RUNMODE == server ]]; then

	### 检测配置是否存在
	if [ ! -f /etc/tinc/"${NETNAME}"/hosts/"${NODE}" ]; then

# 创建 tinc 目录
mkdir -pv /etc/tinc && mkdir -pv /opt/tinc/var/run/

# 初始化服务端节点
tinc -n ${NETNAME} init ${NODE} >/dev/null 2>&1

# 设置 tinc.conf 文件
cat >/etc/tinc/${NETNAME}/tinc.conf <<_EOF_
#对应节点主机名字
Name = ${NODE}
#网卡名称
Interface = ${NETNAME}
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
# 设置广播包发到其他节点的方式, 所有节点需要使用相同的方式, 否则可能会产生路由循环
# no 不发送广播包 
# mst 使用 Minimum Spanning Tree, 保证发往每个节点
# direct 只发送给直接访问的节点, 从其他节点接收到的不转发. 如果设置了 IndirectData, 广播包也会发送给有 meta 链接的节点
# 试验阶段
# no | mst | direct
Broadcast = mst
# 尝试发现本机网络中的节点
# 允许与本地节点地址建立直接连接
# 目前, 本地发现机制是通过在 UDP 发现阶段发送本地地址的方式
LocalDiscovery = yes
# 服务器私钥的位置
PrivateKeyFile = /etc/tinc/${NETNAME}/rsa_key.priv
# 控制SPTPS协议的配置
ExperimentalProtocol = no
_EOF_

# 设置主动连接节点
		peers=$(echo "$PEERS" | tr " " "\n")
		for host in $peers; do
			echo "ConnectTo = ""$host" >>/etc/tinc/"${NETNAME}"/tinc.conf
		done

# 设置hosts文件
cat >>/etc/tinc/${NETNAME}/hosts/${NODE} <<_EOF_
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
_EOF_

# 设置路由
cat >/etc/tinc/${NETNAME}/tinc-up <<_EOF_
#!/bin/sh
ip link set ${INTERFACE} up mtu 1500
ip -6 link set ${INTERFACE} up mtu 1500
ip addr add ${PRIVATE_IPV4}/24 dev ${INTERFACE}
ip -6 addr add ${PRIVATE_IPV6}/64 dev ${INTERFACE}
ip -6 route add default via ${PRIVATE_IPV6}
_EOF_

cat >/etc/tinc/"${NETNAME}"/tinc-down <<_EOF_
#!/bin/sh
ip route del ${PRIVATE_IPV4}/24 dev ${INTERFACE}
ip -6 route del ${PRIVATE_IPV6}/64 dev ${INTERFACE}
ip link set ${INTERFACE} down
ip -6 link set ${INTERFACE} dow
_EOF_

# 设置文件权限
chmod +x /etc/tinc/"${NETNAME}"/tinc-up
chmod +x /etc/tinc/"${NETNAME}"/tinc-down

	fi

elif
	[[ $RUNMODE == client ]]
then

	### 检测配置是否存在
	if [ ! -f /etc/tinc/"${NETNAME}"/hosts/"${NODE}" ]; then

# 创建 tinc 目录
mkdir -pv /etc/tinc/"${NETNAME}"/hosts && mkdir -pv /opt/tinc/var/run

# 生成密钥
yes "" | tinc -n ${NETNAME} generate-keys >/dev/null 2>&1

# 设置 tinc.conf 文件
cat >/etc/tinc/${NETNAME}/tinc.conf <<_EOF_
#对应节点主机名字
Name = ${NODE}
#网卡名称
Interface = ${NETNAME}
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
# 设置广播包发到其他节点的方式, 所有节点需要使用相同的方式, 否则可能会产生路由循环
# no 不发送广播包 
# mst 使用 Minimum Spanning Tree, 保证发往每个节点
# direct 只发送给直接访问的节点, 从其他节点接收到的不转发. 如果设置了 IndirectData, 广播包也会发送给有 meta 链接的节点
# 试验阶段
# no | mst | direct
Broadcast = mst
# 尝试发现本机网络中的节点
# 允许与本地节点地址建立直接连接
# 目前, 本地发现机制是通过在 UDP 发现阶段发送本地地址的方式
LocalDiscovery = yes
# 服务器私钥的位置
PrivateKeyFile = /etc/tinc/${NETNAME}/rsa_key.priv
# 控制SPTPS协议的配置
ExperimentalProtocol = no
_EOF_

# 设置主动连接节点
peers=$(echo "$PEERS" | tr " " "\n")
for host in $peers; do
	echo "ConnectTo = ""$host" >>/etc/tinc/"${NETNAME}"/tinc.conf
done


# 设置hosts文件
cat >>/etc/tinc/${NETNAME}/hosts/${NODE} <<_EOF_
#定义tinc内网网段
Subnet= ${PRIVATE_IPV4}/32
Subnet= ${PRIVATE_IPV6}/128
#路由器内网网段
Subnet= 0.0.0.0/0
Subnet= ::/0
#监听端口
Port= ${TINC_PORT}
_EOF_

# 设置路由
cat >/etc/tinc/${NETNAME}/tinc-up <<_EOF_
#!/bin/sh
ip link set ${INTERFACE} up mtu 1500
ip -6 link set ${INTERFACE} up mtu 1500
ip addr add ${PRIVATE_IPV4}/24 dev ${INTERFACE}
ip -6 addr add ${PRIVATE_IPV6}/64 dev ${INTERFACE}
ip -6 route add default via ${PRIVATE_IPV6}
_EOF_

cat >/etc/tinc/${NETNAME}/tinc-down <<_EOF_
#!/bin/sh
ip route del ${PRIVATE_IPV4}/24 dev ${INTERFACE}
ip -6 route del ${PRIVATE_IPV6}/64 dev ${INTERFACE}
ip link set ${INTERFACE} down
ip -6 link set ${INTERFACE} dow
_EOF_

# 设置文件权限
chmod +x /etc/tinc/"${NETNAME}"/tinc-up
chmod +x /etc/tinc/"${NETNAME}"/tinc-down

	fi

fi
