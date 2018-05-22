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

initOrgVars $ORG

# 删除ca容器
removeFabricContainers "$ROOT_CA_NAME"
# 刷新DATA区域
refreshData

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建rca docker容器
log "Creating docker containers $ROOT_CA_NAME ..."
docker-compose up -d --no-deps $ROOT_CA_NAME


# 等待'rca'容器启动，随后tail -f
dowait "the docker 'rca' container to start" 60 ${SDIR}/${ROOT_CA_LOGFILE} ${SDIR}/${ROOT_CA_LOGFILE}

tail -f ${SDIR}/${ROOT_CA_LOGFILE}&
TAIL_PID=$!
sleep 5
# 等待'rca'容器执行完成
while true; do
    if [ -f ${SDIR}/${ROOT_CA_SUCCESS_FILE} ]; then
        kill -9 $TAIL_PID
        exit 0
    elif [ -f ${SDIR}/${ROOT_CA_FAIL_FILE} ]; then
        kill -9 $TAIL_PID
        exit 1
    else
        sleep 1
    fi
done