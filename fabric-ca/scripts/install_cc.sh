#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 更新链码

set -e

source $(dirname "$0")/env.sh

CC_UPGRADE=false # 是否执行更新upgrade链码操作

opts=0
while getopts "o:n:u" opt; do
    case "$opt" in
        o)
            opts=$((opts+2))
            ORDERER_ORG=$OPTARG
            ;;
        n)
            opts=$((opts+2))
            ORDERER_NUM=$OPTARG
            ;;
        u)
            opts=$((opts+1))
            CC_UPGRADE=true
    esac
done

shift $opts

if [ $# -lt 5 ]; then
    echo "Usage: upgrade_cc.sh <-o <ORDERER_ORG>> <-n <ORDERER_NUM>> <ORG> <NUM> <CC_NAME> <CC_VERSION> <CC_PATH> [<CC_CTOR>]"
    echo "Eg, ./install_cc.sh -u -o org0 -n 1 org1 1 mycc 1.1 github.com/hyperledger/fabric-web/chaincode/go/chaincode_example03 '{\"Args\":[\"init\",\"a\",\"90\",\"b\",\"210\"]}'"
    exit 1
fi

PEER_ORG="$1" # Peer组织
PEER_NUM="$2" # Peer节点索引
CC_NAME="$3" # 链码名称
CC_VERSION="$4" # 链码版本
CC_PATH="$5" # 链码路径
CC_CTOR="$6" # 链码的具体执行参数信息，json格式，默认为"{}"

: ${CC_CTOR:="{}"}

initOrdererVars $ORDERER_ORG $ORDERER_NUM
export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

initPeerVars $PEER_ORG $PEER_NUM
# 切换到peer组织的管理员身份，然后安装链码
echo "Installing chaincode $CC_VERSION on ${PEER_HOST}..."
installChaincode $CC_NAME $CC_VERSION $CC_PATH

if $CC_UPGRADE; then
    # IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    # 使用该Peer组织的管理员身份来upgrade链码
    initPeerVars $PEER_ORG $PEER_NUM
    switchToAdminIdentity
    set -x
    set +e
    makePolicy
    peer chaincode upgrade -C $CHANNEL_NAME -n $CC_NAME -v $CC_VERSION -c $CC_CTOR -P "$POLICY" $ORDERER_CONN_ARGS  >&log.txt
    res=$?
    set +x
    set -e

    cat log.txt
    verifyResult $res "Chaincode upgrade has Failed"
    echo "===================== Chaincode is upgraded ===================== "
    echo
fi