#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 查询链码

set -e

source $(dirname "$0")/env.sh

opts=0
while getopts "o:n:" opt; do
    case "$opt" in
        o)
            opts=$((opts+2))
            ORDERER_ORG=$OPTARG
            ;;
        n)
            opts=$((opts+2))
            ORDERER_NUM=$OPTARG
            ;;
    esac
done

shift $opts

if [ $# -lt 5 ]; then
    echo "Usage: invoke_cc.sh <-o <ORDERER_ORG>> <-n <ORDERER_NUM>> <ORG> <NUM> <CC_NAME> <CC_VERSION> <CC_CTOR>"
    echo "Eg, ./invoke_cc.sh -o org0 -n 1 org1 1 mycc 1.4 '{\"Args\":[\"invoke\",\"a\",\"b\",\"10\"]}'"
    exit 1
fi

PEER_ORG="$1" # Peer组织
PEER_NUM="$2" # Peer节点索引
CC_NAME="$3" # 链码名称
CC_VERSION="$4" # 链码版本
CC_CTOR="$5" # 链码的具体执行参数信息，json格式

initOrdererVars $ORDERER_ORG $ORDERER_NUM
export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

initPeerVars $PEER_ORG $PEER_NUM
switchToUserIdentity

log "Sending invoke transaction to $PEER_HOST ..."
peer chaincode invoke -C $CHANNEL_NAME -n $CC_NAME -c $CC_CTOR $ORDERER_CONN_ARGS
