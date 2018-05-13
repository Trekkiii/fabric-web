#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动intermediate fabric-ca-server

set -e

if [ $# -ne 1 ]; then
    echo "Usage: ./ica-bootstrap.sh <ORG>"
    exit 1
fi

ORG=$1

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

#################################################
# 删除所有fabric相关的容器和链码镜像
removeContainersAndImages
# 删除原有的docker-compose.yml
if [ -f ${SDIR}/docker-compose.yml ]; then
    rm -rf ${SDIR}/docker-compose.yml
fi
#################################################

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建ica docker容器
log "Creating docker containers ica-${ORG} ..."
initOrgVars $ORG

docker-compose up -d --no-deps ica-${ORG}