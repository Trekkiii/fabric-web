#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动root fabric-ca-server

set -e

if [ $# -ne 1 ]; then
    echo "Usage: ./rca-bootstrap.sh <ORG>"
    exit 1
fi

ORG=$1

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

# 删除所有fabric相关的容器
removeFabricContainers

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建rca docker容器
log "Creating docker containers rca-${ORG} ..."
docker-compose up -d --no-deps rca-${ORG}