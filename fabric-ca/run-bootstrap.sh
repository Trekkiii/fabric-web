#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动run容器，执行创建应用通道、加入应用通道、更新锚节点、安装链码、实例化链码、查询调用链码等操作

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

# 获取第一个orderer组织的根TLS证书，用于与orderer节点通讯时使用
# IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
# initOrgVars ${OORGS[0]}
# 从远程CA服务端获取CA_CHAINFILE
# fetchCAChainfile <ORG> <CA_CHAINFILE>
# fetchCAChainfile $ORG $CA_CHAINFILE

# 获取所有组织的根TLS证书，以便'run'容器执行创建应用通道、加入应用通道、更新锚节点、安装链码、实例化链码、查询调用链码等操作
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

docker-compose up -d --no-deps run

# 等待'run'容器启动，随后tail -f run.sum
dowait "the docker 'run' container to start" 60 ${SDIR}/${SETUP_LOGFILE} ${SDIR}/${RUN_SUMFILE}

tail -f ${SDIR}/${RUN_SUMFILE}&
TAIL_PID=$!

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