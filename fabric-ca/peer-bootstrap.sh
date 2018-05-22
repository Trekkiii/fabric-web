#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动peer

function printHelp {

cat << EOF
    使用方法:
        peer-bootstrap.sh [-h] [-?] <ORG> <NUM>
            -h|-?       获取此帮助信息
            <ORG>       启动的peer组织的名称
            <NUM>       启动的peer组织的节点索引
EOF

}

set -e

while getopts "h?" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
    esac
done

if [ $# -ne 2 ]; then
    echo "Usage: ./peer-bootstrap.sh <ORG> <NUM>"
    exit 1
fi

ORG=$1
NUM=$2

# 对NUM类型进行校验
expr $NUM + 0 >& /dev/null
if [ $? -ne 0 ]; then
    echo "Usage: ./peer-bootstrap.sh <ORG> <NUM>"
    exit 1
fi

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

initPeerVars $ORG $NUM

# 删除peer容器
removeFabricContainers $PEER_NAME
# 刷新DATA区域
refreshData
# 删除链码容器和镜像
removeChaincode

# 从远程CA服务端获取CAChain证书
# fetchCAChain <org> <ca_chainfile> [<is_root_ca_certfile>]
fetchCAChain $ORG $CA_CHAINFILE
# 从'setup'节点获取组织的MSP
fetchOrgMSP $ORG

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建peer docker容器
log "Creating docker containers $PEER_NAME ..."
docker-compose up -d --no-deps $PEER_NAME


# 等待'peer'容器启动，随后tail -f
dowait "the docker 'peer' container to start" 60 ${SDIR}/${PEER_LOGFILE} ${SDIR}/${PEER_LOGFILE}

tail -f ${SDIR}/${PEER_LOGFILE}&
TAIL_PID=$!
sleep 5
# 等待'peer'容器执行完成
while true; do
    if [ -f ${SDIR}/${PEER_SUCCESS_FILE} ]; then
        kill -9 $TAIL_PID
        exit 0
    elif [ -f ${SDIR}/${PEER_FAIL_FILE} ]; then
        kill -9 $TAIL_PID
        exit 1
    else
        sleep 1
    fi
done