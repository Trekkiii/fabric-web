#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动intermediate fabric-ca-server

function finish {

    kill -9 $TAIL_PID
}

trap finish EXIT

function printHelp {

    cat << EOF
    使用方法:
        ica-bootstrap.sh [-e] <ORG>
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
    echo "Usage: ./ica-bootstrap.sh [-e] <ORG>"
    exit 1
fi

ORG=$1

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

initOrgVars $ORG

# 删除ca容器
removeFabricContainers $INT_CA_NAME
# 刷新DATA区域
refreshData

# 从远程CA服务端获取CACert证书
fetchCAChain $ORG $ROOT_CA_CERTFILE true

# 创建docker-compose.yml文件
if [ "$IS_EXTEND" == "true" ]; then
    ${SDIR}/makeDocker.sh -e $ORG
else
    ${SDIR}/makeDocker.sh
fi

# 创建ica docker容器
log "Creating docker containers $INT_CA_NAME ..."
docker-compose up -d --no-deps $INT_CA_NAME

# 等待'ica'容器启动，随后tail -f
dowait "the docker 'ica' container to start" 60 ${SDIR}/${INT_CA_LOGFILE} ${SDIR}/${INT_CA_LOGFILE}

tail -f ${SDIR}/${INT_CA_LOGFILE}&
TAIL_PID=$!
# 等待'ica'容器执行完成
waitPort "$INT_CA_NAME to start" 90 $INT_CA_LOGFILE $INT_CA_HOST 7054
sleep 5
exit 0