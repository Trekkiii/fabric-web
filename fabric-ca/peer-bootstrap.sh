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
            -h|-?  - 获取此帮助信息
            <ORG>   - 启动的peer组织的名称
            <NUM>   - 启动的peer组织的节点索引
EOF

}

set -e

while getopts "h?n" opt; do
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

initOrgVars $ORG
# 从远程CA服务端获取CA_CHAINFILE
# fetchCAChainfile <ORG> <CA_CHAINFILE>
fetchCAChainfile $ORG $CA_CHAINFILE

# 删除所有fabric相关的容器
removeFabricContainers
# 删除链码容器和镜像
removeChaincode

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建peer docker容器
log "Creating docker containers peer${NUM}-${ORG} ..."
docker-compose up -d --no-deps peer${NUM}-${ORG}