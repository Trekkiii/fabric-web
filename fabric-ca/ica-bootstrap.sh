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

installExpect

initOrgVars $ORG

# 删除ca容器
removeFabricContainers $INT_CA_NAME
# 刷新DATA区域
refreshData

# 从远程CA服务端获取CACert证书
fetchCAChain $ORG $ROOT_CA_CERTFILE true

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建ica docker容器
log "Creating docker containers $INT_CA_NAME ..."
docker-compose up -d --no-deps $INT_CA_NAME

# 等待'ica'容器启动，随后tail -f
dowait "the docker 'ica' container to start" 60 ${SDIR}/${INT_CA_LOGFILE} ${SDIR}/${INT_CA_LOGFILE}

tail -f ${SDIR}/${INT_CA_LOGFILE}&
TAIL_PID=$!
sleep 5
# 等待'ica'容器执行完成
while true; do
    if [ -f ${SDIR}/${INT_CA_SUCCESS_FILE} ]; then
        kill -9 $TAIL_PID
        exit 0
    elif [ -f ${SDIR}/${INT_CA_FAIL_FILE} ]; then
        kill -9 $TAIL_PID
        exit 1
    else
        sleep 1
    fi
done