#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动setup容器，
#   1) 向中间层fabric-ca-servers注册Orderer和Peer身份
#   2) 构建通道Artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新交易文件）

function printHelp {

cat << EOF
    使用方法:
        setup-bootstrap.sh [-h] [-d]
            -h|-?       获取此帮助信息
            -d          从网络下载二进制文件

    脚本需要使用fabric的二进制文件，请将这些二进制文件置于PATH路径下。
EOF
echo "    如果脚本找不到，会基于fabric源码编译生成二进制文件，此时需要保证\"$HOME/gopath/src/github.com/hyperledger/fabric\"源码目录存在"
echo
echo "    当然你也可以通过指定-d选项从网络下载该二进制文件"
}

# 启动'run'容器，执行创建应用通道、加入应用通道、更新锚节点、安装链码、实例化链码、查询调用链码等操作
startRun() {

    docker-compose up -d --no-deps run

    tail -f ${SDIR}/${RUN_SUMFILE}&
    TAIL_PID=$!

    # 等待'run'容器启动，随后tail -f run.sum
    dowait "the docker 'run' container to start" 60 ${SDIR}/${RUN_LOGFILE} ${SDIR}/${RUN_SUMFILE}

    # 等待'run'容器执行完成
    while true; do
        if [ -f ${SDIR}/${RUN_SUCCESS_FILE} ]; then
            kill -9 $TAIL_PID
            exit 0
        elif [ -f ${SDIR}/${RUN_FAIL_FILE} ]; then
            kill -9 $TAIL_PID
            exit 1
        else
            sleep 1
        fi
    done
}

# 等待所有orderers和peers节点启动，对于每个orderer&peer节点，默认超时等待30分钟
function waitAllOrderersAndPeers {

    for ORG in $ORDERER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT

            # Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
            waitPort "Orderer $ORDERER_HOST to start" 1800 $ORDERER_LOGFILE $ORDERER_HOST 7050

            COUNT=$((COUNT+1))
        done
    done

    for ORG in $PEER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT

            # Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
            waitPort "Peer $PEER_HOST to start" 1800 $PEER_LOGFILE $PEER_HOST 7051

            COUNT=$((COUNT+1))
        done
    done
}

set -e

while getopts "hd" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
        d)
            DOWN_REMOTE_BIN=true
            ;;
    esac
done

: ${DOWN_REMOTE_BIN:="false"}

if [ $(whoami) != "root" ]; then
    log "Please use root to execute this sh"
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

# 删除'setup'容器
removeFabricContainers "setup"
# 删除'run'容器
removeFabricContainers "run"
# 刷新DATA区域（锚节点配置更新交易文件、创世区块、应用通道配置交易文件等）
refreshData

# 下载安装二进制工具
set +e
which configtxgen
rs=$?
set -e
if [ "$rs" -ne 0 ]; then
    binariesInstall $DOWN_REMOTE_BIN
fi

# 获取所有组织的TLS CAChain证书，
# 以便向所有CA服务端登记CA管理员身份，以拥有足够的权限来进行注册所有Orderer相关的用户实体和所有Peer相关的用户实体
for ORG in $ORGS; do
    initOrgVars $ORG
    # 从远程CA服务端获取CAChain证书
    fetchCAChain $ORG $CA_CHAINFILE
done

# 编译生成fabric-ca-client bin
#set +e
#which fabric-ca-client
#if [ $? -ne 0 ]; then
#    log "Compile to generate fabric-ca-client, This will take a few minutes, please wait patiently ..."
#    go get -u github.com/hyperledger/fabric-ca/cmd/...
#    if [ $? -ne 0 ]; then
#        log "Compile to generate fabric-ca-client failed"
#        exit 1
#    fi
#fi
#set -e

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

docker-compose up -d --no-deps setup

# 等待'setup'容器启动，随后tail -f
dowait "the docker 'setup' container to start" 60 ${SDIR}/${SETUP_LOGFILE} ${SDIR}/${SETUP_LOGFILE}

tail -f ${SDIR}/${SETUP_LOGFILE}&
TAIL_PID=$!
sleep 5
# 等待'setup'容器执行完成
while true; do
    if [ -f ${SDIR}/${SETUP_SUCCESS_FILE} ]; then
        kill -9 $TAIL_PID

        chmod -R 755 ${SDIR}/$DATA/orgs

        # 等待所有orderers和peers节点启动
        waitAllOrderersAndPeers
        sleep 3

        # 启动'run'容器，执行创建应用通道、加入应用通道、更新锚节点、安装链码、实例化链码、查询调用链码等操作
        startRun

    elif [ -f ${SDIR}/${SETUP_FAIL_FILE} ]; then
        kill -9 $TAIL_PID
        exit 1
    else
        sleep 1
    fi
done