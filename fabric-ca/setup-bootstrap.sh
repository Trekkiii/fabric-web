#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动setup容器，用于向中间层fabric-ca-servers注册Orderer和Peer身份

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

# 获取所有组织的根TLS证书，以便'setup'向所有CA服务端登记CA管理员身份、注册所有Orderer相关的用户实体，以及注册所有Peer相关的用户实体时使用
for ORG in $ORGS; do
    initOrgVars $ORG
    # 从远程CA服务端获取CA_CHAINFILE
    # fetchCAChainfile <ORG> <CA_CHAINFILE>
    fetchCAChainfile $ORG $CA_CHAINFILE
done

# 删除所有fabric相关的容器
removeFabricContainers

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

docker-compose up -d --no-deps setup