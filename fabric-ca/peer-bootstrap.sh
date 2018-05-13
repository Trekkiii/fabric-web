#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动peer

function printHelp {

cat << EOF
    使用方法:
        peer-bootstrap.sh [-h] [-?] [-n] <ORG> <NUM>
            -h|-?  - 获取此帮助信息
            -n  - 不清理fabric相关的容器和镜像、docker-compose.yml
            <ORG>   - 要启动的peer组织的名称
            <NUM>   - 要启动的peer组织的节点索引
EOF

}

set -e

clear=true

while getopts "h?n" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
        n)
            clear=false
            shift
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

#################################################
if [ $clear = true ]; then
    # 删除所有fabric相关的容器和链码镜像
    removeContainersAndImages
    # 删除原有的docker-compose.yml
    if [ -f ${SDIR}/docker-compose.yml ]; then
    rm -rf ${SDIR}/docker-compose.yml
    fi
fi
#################################################

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

# 创建peer docker容器
log "Creating docker containers peer${NUM}-${ORG} ..."
docker-compose up -d --no-deps peer${NUM}-${ORG}