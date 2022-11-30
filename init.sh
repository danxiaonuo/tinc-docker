#!/bin/bash -e

if [[ $RUNMODE == server ]]; then

	### 检测配置是否存在
	if [ ! -f /etc/tinc/"${NETNAME}"/hosts/"${NODE}" ]; then

# 创建 tinc 目录
mkdir -pv /etc/tinc && mkdir -pv /opt/tinc/run && mkdir -pv /opt/tinc/logs

# 初始化节点
tinc -n ${NETNAME} init ${NODE} >/dev/null 2>&1

# 设置 tinc.conf 文件
cat >/etc/tinc/${NETNAME}/tinc.conf <<_EOF_
# 对应节点主机名字
Name = ${NODE}
# 网卡名称
Interface = ${NETNAME}
# Mode 有三种模式，分别是<router|switch|hub> (router) ,相对应我们平时使用到的路由、交换机、集线器 (默认模式 router)
Mode = router 
# 影响监听和外部 sockets 包, any 会根据操作系统进行创建 ipv4 和 ipv6
# ipv4 | ipv6 | any
AddressFamily = any
# 加密类型
Cipher  = id-aes256-GCM 
# RSA加密协议强度
Digest = whirlpool
# MAC长度
MACLength = 16
# 服务器私钥的位置
PrivateKeyFile = /etc/tinc/${NETNAME}/rsa_key.priv
# 节点初始路径 MTU - Path MTU
PMTU = 8900
# 自动发现到节点的 Path MTU
PMTUDiscovery = no
# 发送发现 MTU 消息的间隔
MTUInfoInterval = 1
# clamp maximum segment size - tcp 包-> pmtu
ClampMSS = no
# 如果设置为 yes 则必须先有直连的 meta 链接
IndirectData = no
# 仅直连不转发 - 适用于 meta node
# 实验阶段
DirectOnly = no
# 转发前减小 ipv4 包 ttl 和 ipv6 包的 Hop Limit
# 实验阶段
DecrementTTL = no
# 设置广播包发到其他节点的方式, 所有节点需要使用相同的方式, 否则可能会产生路由循环
# no 不发送广播包 
# mst 使用 Minimum Spanning Tree, 保证发往每个节点
# direct 只发送给直接访问的节点, 从其他节点接收到的不转发. 如果设置了 IndirectData, 广播包也会发送给有 meta 链接的节点
# 试验阶段
# no | mst | direct
Broadcast = mst
# 转发策略
# 实验阶段
# off 不转发
# internal 内部转发
# kernel 包发往 TUN/TAP 设备, 交由内核转发, 性能更低, 但能使用内核的路由功能
Forwarding = internal
# 是否解析 hostname - dns 阻塞查询对性能有一点影响
Hostnames = no
# tun/tap IFF_ONE_QUEUE
# 实验阶段
IffOneQueue = no
# 邀请时效时间
# 秒
InvitationExpire = 604800
# key 失效时间 - 秒
KeyExpire = 3600
# 尝试发现本机网络中的节点
# 允许与本地节点地址建立直接连接
# 目前, 本地发现机制是通过在 UDP 发现阶段发送本地地址的方式
LocalDiscovery = yes
# mac 地址失效时间 - 秒
# switch 模式有效
MACExpire = 600
# 最大爆发连接数 - 超过的 1/s 一个
MaxConnectionBurst = 1000000
# 最大重连延时
MaxTimeout = 900
# ping 间隔 发现 mtu 检测节点
PingInterval = 3
# 超时后中断 meta 链接
PingTimeout = 6
# UDP 继承 TCP 的 TOS 字段
# 隧道IPv4报文的TOS字段值将被UDP包继承发出的Ets
PriorityInheritance = yes
# 进程优先级
ProcessPriority = high
# 只允许 /etc/tinc/NETNAME/hosts/ 下的 Subnet 信息
# 例如 A -> B -> C - C 不会学习到 A 的子网信息
# 实验阶段
StrictSubnets = no
# 不会转发其他节点间的信息， /etc/tinc/NETNAME/hosts/ , 隐性指定 StrictSubnets
# 实验阶段
TunnelServer = no
# 将尝试使用 TCP 与节点建立 UDP 连接
UDPDiscovery = yes
UDPDiscoveryKeepaliveInterval = 9
UDPDiscoveryInterval = 2
UDPDiscoveryTimeout = 3
UDPInfoInterval = 5
UDPRcvBuf = 104857600
UDPSndBuf = 104857600
# 搜索 UPnP-IGD，管理维护 tinc 的端口映射
# udponly 只维护 udp 端口
# yes | udponly | no
UPnP = no
UPnPDiscoverWait = 3
UPnPRefreshPeriod = 60
# 启用后, 会尝试使用 SPTPS 协议, key 交换会使用 Ephemeral ECDH, 会使用 Ed25519 作为授权, 而不是 RSA, 因此需要先生成 Ed25519
# 如果先启用了且 join 了网络，再改成 no 时需要先准备好 rsa key
ExperimentalProtocol = yes
# 如果启用, 会自动尝试与其他节点建立 meta 链接, 而不需要设置 ConnectTo
# 不能链接 Port=0 的节点 - 系统随机端口
# 试验阶段
# yes | no
# AutoConnect = yes
_EOF_

# 设置hosts文件
cat >>/etc/tinc/${NETNAME}/hosts/${NODE} <<_EOF_
# 公网IP地址
Address = ${PUBLIC_IP}
# 定义tinc内网网段
Subnet= ${PRIVATE_IPV4}/32
Subnet= ${PRIVATE_IPV6}/128
# 路由器内网网段
Subnet= 0.0.0.0/0
Subnet= ::/0
# 监听端口
Port= ${TINC_PORT}
_EOF_

# 设置路由
cat >/etc/tinc/${NETNAME}/tinc-up <<_EOF_
#!/bin/sh
# 启动参数
# 本机隧道IPV4地址
IPV4_ADDR="${PRIVATE_IPV4}"
# 本机隧道IPV6地址
IPV6_ADDR="${PRIVATE_IPV6}"

# 接口
ip -4 link set \${INTERFACE} up mtu 8900 txqlen 1500
ip -6 link set \${INTERFACE} up mtu 8900 txqlen 1500

# 本机地址
ip -4 addr add \${IPV4_ADDR}/${PRIVATE_IPV4_MASK} dev \${INTERFACE}
ip -6 addr add \${IPV6_ADDR}/${PRIVATE_IPV6_MASK} dev \${INTERFACE}

# 路由地址
ip -6 route add ${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK} dev \${INTERFACE} metric 1

# 防火墙配置
# ipv4配置
iptables -A FORWARD -o \${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i \${NETNAME} -j ACCEPT
iptables -t nat -A POSTROUTING -s "${PRIVATE_IPV4_GW}/${PRIVATE_IPV4_MASK}" ! -o \${INTERFACE} -j MASQUERADE
# ipv6配置
ip6tables -A FORWARD -o \${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A FORWARD -i \${NETNAME} -j ACCEPT
ip6tables -t nat -A POSTROUTING -s "${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK}" ! -o \${INTERFACE} -j MASQUERADE
_EOF_

cat >/etc/tinc/"${NETNAME}"/tinc-down <<_EOF_
#!/bin/sh
# 启动参数
# 本机隧道IPV4地址
IPV4_ADDR="${PRIVATE_IPV4}"
# 本机隧道IPV6地址
IPV6_ADDR="${PRIVATE_IPV6}"

# 路由地址
ip -4 route del ${PRIVATE_IPV4_GW}/${PRIVATE_IPV4_MASK} dev \${INTERFACE}
ip -6 route del ${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK} dev \${INTERFACE}

# 防火墙配置
# ipv4配置
iptables -D FORWARD -o \${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -D FORWARD -i \${NETNAME} -j ACCEPT
iptables -t nat -D POSTROUTING -s "${PRIVATE_IPV4_GW}/${PRIVATE_IPV4_MASK}" ! -o \${INTERFACE} -j MASQUERADE
# ipv6配置
ip6tables -D FORWARD -o ${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -D FORWARD -i ${NETNAME} -j ACCEPT
ip6tables -t nat -D POSTROUTING -s "${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK}" ! -o \${INTERFACE} -j MASQUERADE

# 本机地址
ip -4 addr del \${IPV4_ADDR}/${PRIVATE_IPV4_MASK} dev \${INTERFACE}
ip -6 addr del \${IPV6_ADDR}/${PRIVATE_IPV6_MASK} dev \${INTERFACE}

# 接口
ip -4 link set \${INTERFACE} down
ip -6 link set \${INTERFACE} down
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
mkdir -pv /etc/tinc && mkdir -pv /opt/tinc/run && mkdir -pv /opt/tinc/logs

# 初始化节点
tinc -n ${NETNAME} init ${NODE} >/dev/null 2>&1

# 设置 tinc.conf 文件
cat >/etc/tinc/${NETNAME}/tinc.conf <<_EOF_
# 对应节点主机名字
Name = ${NODE}
# 网卡名称
Interface = ${NETNAME}
# Mode 有三种模式，分别是<router|switch|hub> (router) ,相对应我们平时使用到的路由、交换机、集线器 (默认模式 router)
Mode = router 
# 影响监听和外部 sockets 包, any 会根据操作系统进行创建 ipv4 和 ipv6
# ipv4 | ipv6 | any
AddressFamily = any
# 加密类型
Cipher  = id-aes256-GCM 
# RSA加密协议强度
Digest = whirlpool
# MAC长度
MACLength = 16
# 服务器私钥的位置
PrivateKeyFile = /etc/tinc/${NETNAME}/rsa_key.priv
# 节点初始路径 MTU - Path MTU
PMTU = 8900
# 自动发现到节点的 Path MTU
PMTUDiscovery = no
# 发送发现 MTU 消息的间隔
MTUInfoInterval = 1
# clamp maximum segment size - tcp 包-> pmtu
ClampMSS = no
# 如果设置为 yes 则必须先有直连的 meta 链接
IndirectData = no
# 仅直连不转发 - 适用于 meta node
# 实验阶段
DirectOnly = no
# 转发前减小 ipv4 包 ttl 和 ipv6 包的 Hop Limit
# 实验阶段
DecrementTTL = no
# 设置广播包发到其他节点的方式, 所有节点需要使用相同的方式, 否则可能会产生路由循环
# no 不发送广播包 
# mst 使用 Minimum Spanning Tree, 保证发往每个节点
# direct 只发送给直接访问的节点, 从其他节点接收到的不转发. 如果设置了 IndirectData, 广播包也会发送给有 meta 链接的节点
# 试验阶段
# no | mst | direct
Broadcast = mst
# 转发策略
# 实验阶段
# off 不转发
# internal 内部转发
# kernel 包发往 TUN/TAP 设备, 交由内核转发, 性能更低, 但能使用内核的路由功能
Forwarding = internal
# 是否解析 hostname - dns 阻塞查询对性能有一点影响
Hostnames = no
# tun/tap IFF_ONE_QUEUE
# 实验阶段
IffOneQueue = no
# 邀请时效时间
# 秒
InvitationExpire = 604800
# key 失效时间 - 秒
KeyExpire = 3600
# 尝试发现本机网络中的节点
# 允许与本地节点地址建立直接连接
# 目前, 本地发现机制是通过在 UDP 发现阶段发送本地地址的方式
LocalDiscovery = yes
# mac 地址失效时间 - 秒
# switch 模式有效
MACExpire = 600
# 最大爆发连接数 - 超过的 1/s 一个
MaxConnectionBurst = 1000000
# 最大重连延时
MaxTimeout = 900
# ping 间隔 发现 mtu 检测节点
PingInterval = 3
# 超时后中断 meta 链接
PingTimeout = 6
# UDP 继承 TCP 的 TOS 字段
# 隧道IPv4报文的TOS字段值将被UDP包继承发出的Ets
PriorityInheritance = yes
# 进程优先级
ProcessPriority = high
# 只允许 /etc/tinc/NETNAME/hosts/ 下的 Subnet 信息
# 例如 A -> B -> C - C 不会学习到 A 的子网信息
# 实验阶段
StrictSubnets = no
# 不会转发其他节点间的信息， /etc/tinc/NETNAME/hosts/ , 隐性指定 StrictSubnets
# 实验阶段
TunnelServer = no
# 将尝试使用 TCP 与节点建立 UDP 连接
UDPDiscovery = yes
UDPDiscoveryKeepaliveInterval = 9
UDPDiscoveryInterval = 2
UDPDiscoveryTimeout = 3
UDPInfoInterval = 5
UDPRcvBuf = 104857600
UDPSndBuf = 104857600
# 搜索 UPnP-IGD，管理维护 tinc 的端口映射
# udponly 只维护 udp 端口
# yes | udponly | no
UPnP = no
UPnPDiscoverWait = 3
UPnPRefreshPeriod = 60
# 启用后, 会尝试使用 SPTPS 协议, key 交换会使用 Ephemeral ECDH, 会使用 Ed25519 作为授权, 而不是 RSA, 因此需要先生成 Ed25519
# 如果先启用了且 join 了网络，再改成 no 时需要先准备好 rsa key
ExperimentalProtocol = yes
# 如果启用, 会自动尝试与其他节点建立 meta 链接, 而不需要设置 ConnectTo
# 不能链接 Port=0 的节点 - 系统随机端口
# 试验阶段
# yes | no
AutoConnect = yes
_EOF_

# 设置hosts文件
cat >>/etc/tinc/${NETNAME}/hosts/${NODE} <<_EOF_
# 定义tinc内网网段
Subnet= ${PRIVATE_IPV4}/32
Subnet= ${PRIVATE_IPV6}/128
# 路由器内网网段
Subnet= 0.0.0.0/0
Subnet= ::/0
# 监听端口
Port= 0
_EOF_

# 设置路由
cat >/etc/tinc/${NETNAME}/tinc-up <<_EOF_
#!/bin/sh
# 启动参数
# 本机隧道IPV4地址
IPV4_ADDR="${PRIVATE_IPV4}"
# 本机隧道IPV6地址
IPV6_ADDR="${PRIVATE_IPV6}"

# 接口
ip -4 link set \${INTERFACE} up mtu 8900 txqlen 1500
ip -6 link set \${INTERFACE} up mtu 8900 txqlen 1500

# 本机地址
ip -4 addr add \${IPV4_ADDR}/${PRIVATE_IPV4_MASK} dev \${INTERFACE}
ip -6 addr add \${IPV6_ADDR}/${PRIVATE_IPV6_MASK} dev \${INTERFACE}

# 路由地址
ip -6 route add ${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK} dev \${INTERFACE} metric 1

# 防火墙配置
# ipv4配置
iptables -A FORWARD -o \${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i \${NETNAME} -j ACCEPT
iptables -t nat -A POSTROUTING -s "${PRIVATE_IPV4_GW}/${PRIVATE_IPV4_MASK}" ! -o \${INTERFACE} -j MASQUERADE
# ipv6配置
ip6tables -A FORWARD -o \${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A FORWARD -i \${NETNAME} -j ACCEPT
ip6tables -t nat -A POSTROUTING -s "${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK}" ! -o \${INTERFACE} -j MASQUERADE
_EOF_

cat >/etc/tinc/"${NETNAME}"/tinc-down <<_EOF_
#!/bin/sh
# 启动参数
# 本机隧道IPV4地址
IPV4_ADDR="${PRIVATE_IPV4}"
# 本机隧道IPV6地址
IPV6_ADDR="${PRIVATE_IPV6}"

# 路由地址
ip -4 route del ${PRIVATE_IPV4_GW}/${PRIVATE_IPV4_MASK} dev \${INTERFACE}
ip -6 route del ${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK} dev \${INTERFACE}

# 防火墙配置
# ipv4配置
iptables -D FORWARD -o \${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -D FORWARD -i \${NETNAME} -j ACCEPT
iptables -t nat -D POSTROUTING -s "${PRIVATE_IPV4_GW}/${PRIVATE_IPV4_MASK}" ! -o \${INTERFACE} -j MASQUERADE
# ipv6配置
ip6tables -D FORWARD -o ${NETNAME} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -D FORWARD -i ${NETNAME} -j ACCEPT
ip6tables -t nat -D POSTROUTING -s "${PRIVATE_IPV6_GW}/${PRIVATE_IPV6_MASK}" ! -o \${INTERFACE} -j MASQUERADE

# 本机地址
ip -4 addr del \${IPV4_ADDR}/${PRIVATE_IPV4_MASK} dev \${INTERFACE}
ip -6 addr del \${IPV6_ADDR}/${PRIVATE_IPV6_MASK} dev \${INTERFACE}

# 接口
ip -4 link set \${INTERFACE} down
ip -6 link set \${INTERFACE} down
_EOF_

# 设置文件权限
chmod +x /etc/tinc/"${NETNAME}"/tinc-up
chmod +x /etc/tinc/"${NETNAME}"/tinc-down

	fi

fi
