#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动peer

function finish {

    if [ "$done" = false ]; then
        kill -9 $TAIL_PID
    fi
}

trap finish EXIT

function printHelp {

cat << EOF
    使用方法:
        eyfn-bootstrap.sh [-h] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <NEW_ORG> <NUM>
            -h|-?               获取此帮助信息
            -c <NUM_PEERS>      加入的新Peer组织的peer节点数量，默认为fabric.config中配置的NUM_PEERS
            -o <ORDERER_ORG>    Orderer组织名称，默认为第一个Orderer组织
            -n <ORDERER_NUM>    Orderer节点的索引，默认值为1
            <NEW_ORG>           启动的新Peer组织的名称
            <NUM>               启动的新Peer组织的节点索引
EOF

}

set -e

opts=0
while getopts "hc:o:n:" opt; do
    case "$opt" in
        h)
            printHelp
            exit 0
            ;;
        c)
            opts=$((opts+2))
            NUM_PEERS=$OPTARG
            # 对NUM_PEERS类型进行校验
            expr $NUM_PEERS + 0 >& /dev/null
            if [ $? -ne 0 ]; then
                fatal "The -$opt $OPTARG should be integer"
            fi
            ;;
        o)
            opts=$((opts+2))
            ORDERER_ORG=$OPTARG
            ;;
        n)
            opts=$((opts+2))
            ORDERER_NUM=$OPTARG
            ;;
        \?)
            fatal "Invalid option: -$opt $OPTARG"
    esac
done

shift $opts

# 默认第一个Orderer组织的第一个节点
IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
: ${ORDERER_ORG:="${OORGS[0]}"}
: ${ORDERER_NUM:="1"}

if [ $# -ne 2 ]; then
    echo "Usage: ./eyfn-bootstrap.sh [-h] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <NEW_ORG> <NUM>"
    exit 1
fi

NEW_ORG=$1
NUM=$2

# 对NUM类型进行校验
expr $NUM + 0 >& /dev/null
if [ $? -ne 0 ]; then
    echo "Usage: ./eyfn-bootstrap.sh [-h] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <NEW_ORG> <NUM>"
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

initPeerVars $NEW_ORG $NUM

# 删除cli容器
set +e
docker rm -f cli
set -e

# 删除peer容器
removeFabricContainers $PEER_NAME
# 删除链码容器和镜像
removeChaincode

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh -e $NEW_ORG $NUM_PEERS

# 创建peer docker容器
log "Creating docker containers $PEER_NAME ..."
# docker-compose up -d --no-deps $PEER_NAME
docker-compose up -d $PEER_NAME

# 等待'peer'容器启动，随后tail -f
dowait "the docker 'peer' container to start" 60 ${SDIR}/${PEER_LOGFILE} ${SDIR}/${PEER_LOGFILE}

tail -f ${SDIR}/${PEER_LOGFILE}&
TAIL_PID=$!
done=false

# 等待'peer'容器执行完成
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
waitPort "Peer $PEER_HOST to start" 1800 $PEER_LOGFILE $PEER_HOST 7051

kill -9 $TAIL_PID
done=true

docker-compose up -d --no-deps cli
res=$?
if [ $res -ne 0 ]; then
    echo "ERROR !!!! Cli container failed to start"
    docker logs -f cli
    exit 1
fi

docker exec cli /scripts/eyfn/step2.sh -o ${ORDERER_ORG} -n ${ORDERER_NUM} ${CHANNEL_NAME} ${NEW_ORG} ${NUM}
docker logs -f cli