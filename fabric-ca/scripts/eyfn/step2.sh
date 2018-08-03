#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 这个脚本在cli容器中运行
# 它将新组织的指定peer加入先前创建的应用通道。

set -e

source $(dirname "$0")/../env.sh

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

if [ $# -lt 3 ]; then
    echo "Usage: ./step2.sh <-o <ORDERER_ORG>> <-n <ORDERER_NUM>> <CHANNEL_NAME> <NEW_ORG> <PEER_NUM>"
    exit 1
fi

CHANNEL_NAME="$1" # 应用通道名称
NEW_ORG="$2" # 新加入的组织
PEER_NUM="$3" # 启动的节点

echo "Fetching channel config block from orderer..."

# 将 ORDERER_PORT_ARGS 设置为与$ORDERER_ORG的第$ORDERER_NUM个orderer节点进行通信所需的参数
initOrdererVars $ORDERER_ORG $ORDERER_NUM
# Orderer端点的连接属性
#       -o, --orderer string    Orderer服务地址
#       --tls    在与Orderer端点通信时使用TLS
#       --cafile string     Orderer节点的TLS证书，PEM格式编码，启用TLS时有效
#       --clientauth    是否启用客户端验证
#       --certfile string    Peer节点的PEM编码的X509公钥文件(代表peer节点身份)，用于客户端验证
#       --keyfile string    Peer节点的PEM编码的私钥文件(代表peer节点身份)，用于客户端验证
export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

# 使用新组织的管理员身份获取创世区块
initPeerVars ${NEW_ORG} ${PEER_NUM}
switchToAdminIdentity
set -x
set +e
peer channel fetch 0 $CHANNEL_NAME.block -c $CHANNEL_NAME $ORDERER_CONN_ARGS  >&log.txt
res=$?
cat log.txt
set +x
set -e
verifyResult $res "Fetching config block from orderer has Failed"

echo "===================== Having $PEER_NAME join the channel ===================== "
# 切换到peer组织的管理员身份，然后加入应用通道
joinChannelWithRetry ${NEW_ORG} ${PEER_NUM}
echo "===================== $PEER_NAME joined the channel \"$CHANNEL_NAME\" ===================== "

# TODO 为新Peer组织更新锚节点？如何更新？

initPeerVars ${NEW_ORG} ${PEER_NUM}
echo "Installing chaincode 2.0 on ${PEER_HOST}..."
installChaincode mycc 2.0 github.com/hyperledger/fabric-web/chaincode/go/chaincode_example02

IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
NUM_PORGS=${#PORGS[@]}
NUM_PORGS=$((NUM_PORGS-1)) # 应该把当前要加入的新组织排除在外
COUNT=1
for ORG in $PEER_ORGS; do
    if [ "$COUNT" -le $NUM_PORGS ]; then
        initPeerVars $ORG $COUNT
        # 切换到peer组织的管理员身份，然后安装链码
        echo "Installing chaincode 2.0 on ${PEER_HOST}..."
        installChaincode mycc 2.0 github.com/hyperledger/fabric-web/chaincode/go/chaincode_example02

    fi
    COUNT=$((COUNT+1))
done

# 新加入组织需要upgrade链码，重新指定链码背书策略，否则新组织没有写权限，
# 因为起初链码背书策略中指定了原有组织的成员才有写权限
# 使用第一个Peer组织的管理员身份来upgrade链码
initPeerVars ${PORGS[0]} 1
switchToAdminIdentity
set -x
set +e
makePolicy
peer chaincode upgrade -C $CHANNEL_NAME -n mycc -v 2.0 -c '{"Args":["init","a","90","b","210"]}' -P "$POLICY" $ORDERER_CONN_ARGS  >&log.txt
res=$?
set +x
set -e

cat log.txt
verifyResult $res "Chaincode upgrade has Failed"
echo "===================== Chaincode is upgraded ===================== "
echo

# 在新加入Peer组织的第一个peer节点上查询链码
initPeerVars ${NEW_ORG} 1
switchToUserIdentity
chaincodeQuery 90

# 在新加入Peer组织的第一个peer节点上调用链码
initPeerVars ${NEW_ORG} 1
switchToUserIdentity
log "Sending invoke transaction to $PEER_HOST ..."
peer chaincode invoke -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS

# 在新加入Peer组织的第一个peer节点上查询链码
sleep 20
initPeerVars ${NEW_ORG} 1
switchToUserIdentity
chaincodeQuery 80

echo
echo "========= Got ${NEW_ORG} halfway onto your first network ========= "
echo