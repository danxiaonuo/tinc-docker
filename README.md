# tinc-docker
# server服务器上生成邀请连接 tinc -n 网络名称 invite 客户端名称
tinc -n danxiaonuo invite client01

# 客户端加入server
tinc join

# win10
## 进入目录
cd C:\tinc
## 初始化节点
tinc -c C:\tinc\danxiaonuo -n danxiaonuo init office
## 编辑配置文件
## debug模式启动
tincd -c C:\tinc\danxiaonuo -n danxiaonuo -D -d3
# 安装服务
tincd -c C:\tinc\danxiaonuo -n danxiaonuo
