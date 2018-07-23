#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动peer

function finish {

    kill -9 $TAIL_PID
}

trap finish EXIT

function printHelp {

cat << EOF
    使用方法:
        peer-bootstrap.sh [-h] <ORG> <NUM>
            -h|-?       获取此帮助信息
            <ORG>       启动的peer组织的名称
            <NUM>       启动的peer组织的节点索引
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

installJQ
# 校验fabric.config配置是否是合法性JSON
cat fabric.config | jq . >& /dev/null
if [ $? -ne 0 ]; then
	fatal "fabric.config isn't JSON format"
fi
installExpect

initPeerVars $ORG $NUM

# 删除peer容器
removeFabricContainers $PEER_NAME
# 刷新DATA区域
refreshData
# 删除链码容器和镜像
removeChaincode

# 从远程CA服务端获取CAChain证书
fetchCAChain $ORG $CA_CHAINFILE
# 从'setup'节点获取组织的Admin证书

# TODO !!! 注意：这里peer如果重新获取管理员身份证书，则会导致setup节点获取的管理员身份证书无效，从而run节点使用（执行peer channel join）时会报如下错误：
# Error: proposal failed (err: rpc error: code = Unknown desc = chaincode error (status: 500, message: "JoinChain" request failed authorization check for channel [mychannel]:
# [Failed verifying that proposal's creator satisfies local MSP principal during channelless check policy with policy [Admins]: [This identity is not an admin]]))
fetchOrgAdmin $ORG

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建peer docker容器
log "Creating docker containers $PEER_NAME ..."
# docker-compose up -d --no-deps $PEER_NAME
docker-compose up -d $PEER_NAME

# 等待'peer'容器启动，随后tail -f
dowait "the docker 'peer' container to start" 60 ${SDIR}/${PEER_LOGFILE} ${SDIR}/${PEER_LOGFILE}

tail -f ${SDIR}/${PEER_LOGFILE}&
TAIL_PID=$!
# 等待'peer'容器执行完成
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
waitPort "Peer $PEER_HOST to start" 1800 $PEER_LOGFILE $PEER_HOST 7051
sleep 5
exit 0