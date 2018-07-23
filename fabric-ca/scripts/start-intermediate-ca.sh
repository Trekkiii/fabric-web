#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

initOrgVars $ORG

# 等待root CA启动
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
waitPort "root CA to start" 60 $ROOT_CA_LOGFILE $ROOT_CA_HOST 7054

# 初始化中间层CA
# -b 指定intermediate CA服务启动的用户名和密码，这里使用intermediate CA管理员(CA_ADMIN_USER_PASS)
# -u 父fabric-ca-server服务地址
fabric-ca-server init -b $BOOTSTRAP_USER_PASS -u $PARENT_URL

# 将中间层CA的身份证书chain复制到DATA目录以供其他节点使用
# FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
# TARGET_CHAINFILE=/${DATA}/${ORG}-ca-chain.pem
# /etc/hyperledger/fabric-ca/ca-chain.pem -> /${DATA}/${ORG}-ca-chain.pem
cp $FABRIC_CA_SERVER_HOME/ca-chain.pem $TARGET_CHAINFILE

# 添加组织结构配置
# FABRIC_ORGS="$ORDERER_ORGS $PEER_ORGS"
for o in $FABRIC_ORGS; do
   aff=$aff"\n   $o: []"
done
aff="${aff#\\n   }"

sed -i "/affiliations:/a \\   $aff" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# Start the intermediate CA
fabric-ca-server start