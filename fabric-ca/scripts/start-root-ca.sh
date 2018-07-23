#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0

set -e

source $(dirname "$0")/env.sh

# 初始化根CA
# -b 指定root CA服务启动的用户名和密码，这里使用root CA管理员
fabric-ca-server init -b $BOOTSTRAP_USER_PASS

# 将root CA的身份证书复制到DATA目录以供其他节点使用
# FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
# TARGET_CERTFILE=/${DATA}/${ORG}-ca-cert.pem
# /etc/hyperledger/fabric-ca/ca-cert.pem -> /${DATA}/${ORG}-ca-cert.pem
cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $TARGET_CERTFILE

# 添加组织结构配置
# FABRIC_ORGS="$ORDERER_ORGS $PEER_ORGS"
for o in $FABRIC_ORGS; do
   aff=$aff"\n   $o: []"
done
aff="${aff#\\n   }" # 注意对\n转义

# sed
#   -i:直接修改读取的文件内容，而不是输出到终端
#   a:新增，a的后面可以接字串，而这些字串会在新的一行出现
#   \\ 输出其后的空格，否则会被忽略
sed -i "/affiliations:/a \\   $aff" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# Start the root CA
fabric-ca-server start