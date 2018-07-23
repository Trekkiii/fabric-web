#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动orderer

function finish {

    kill -9 $TAIL_PID
}

trap finish EXIT

function printHelp {

cat << EOF
    使用方法:
        orderer-bootstrap.sh [-h] <ORG> <NUM>
            -h|-?       获取此帮助信息
            <ORG>       启动的orderer组织的名称
            <NUM>       启动的orderer组织的节点索引
EOF

}

set -e

while getopts "h" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
    esac
done

if [ $# -ne 2 ]; then
    echo "Usage: ./orderer-bootstrap.sh <ORG> <NUM>"
    exit 1
fi

ORG=$1
NUM=$2

# 对NUM类型进行校验
expr $NUM + 0 >& /dev/null
if [ $? -ne 0 ]; then
    echo "Usage: ./orderer-bootstrap.sh <ORG> <NUM>"
    exit 1
fi

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

installJQ
# 校验fabric.config配置是否是合法性JSON
cat fabric.config | jq . >& /dev/null
if [ $? -ne 0 ]; then
	fatal "fabric.config isn't JSON format"
fi
installExpect

initOrdererVars $ORG $NUM

# 删除orderer容器
removeFabricContainers $ORDERER_NAME
# 刷新DATA区域
refreshData

# 从远程CA服务端获取CAChain证书
fetchCAChain $ORG $CA_CHAINFILE
# 从'setup'节点获取创世区块
fetchChannelTx ${GENESIS_BLOCK_FILE}
# 从'setup'节点获取组织的Admin证书
fetchOrgAdmin $ORG

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建orderer docker容器
log "Creating docker containers $ORDERER_NAME ..."
docker-compose up -d --no-deps $ORDERER_NAME

# 等待'orderer'容器启动，随后tail -f
dowait "the docker 'orderer' container to start" 60 ${SDIR}/${ORDERER_LOGFILE} ${SDIR}/${ORDERER_LOGFILE}

tail -f ${SDIR}/${ORDERER_LOGFILE}&
TAIL_PID=$!
# 等待'orderer'容器执行完成
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
waitPort "Orderer $ORDERER_HOST to start" 90 $ORDERER_LOGFILE $ORDERER_HOST 7050
sleep 5
exit 0