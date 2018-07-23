#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动root fabric-ca-server

function finish {

    kill -9 $TAIL_PID
}

trap finish EXIT

function printHelp {

    cat << EOF
    使用方法:
        rca-bootstrap.sh [-e] <ORG>
            -e          新加入组织
EOF
}

set -e

IS_EXTEND=false

while getopts "he" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
        e)
            IS_EXTEND=true
            shift
            ;;
    esac
done

if [ $# -ne 1 ]; then
    echo "Usage: ./rca-bootstrap.sh [-e] <ORG>"
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
if [ "$IS_EXTEND" == "true" ]; then
    ${SDIR}/makeDocker.sh -e $ORG
else
    ${SDIR}/makeDocker.sh
fi

# 创建rca docker容器
log "Creating docker containers $ROOT_CA_NAME ..."
docker-compose up -d --no-deps $ROOT_CA_NAME

# 等待'rca'容器启动，随后tail -f
dowait "the docker 'rca' container to start" 60 ${SDIR}/${ROOT_CA_LOGFILE} ${SDIR}/${ROOT_CA_LOGFILE}

tail -f ${SDIR}/${ROOT_CA_LOGFILE}&
TAIL_PID=$!
# 等待'rca'容器执行完成
waitPort "$ROOT_CA_NAME to start" 90 $ROOT_CA_LOGFILE $ROOT_CA_HOST 7054
sleep 5
exit 0