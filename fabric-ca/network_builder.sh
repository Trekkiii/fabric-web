#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# v1.1.0
#
# 构建项目，为不同节点打包脚本

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

#################################################
# 删除原build文件夹
if [ -d ${SDIR}/build ]; then
    rm -rf ${SDIR}/build
fi
# 删除原有的configtx.yaml
if [ -f ${SDIR}/configtx.yaml ]; then
    rm -rf ${SDIR}/configtx.yaml
fi
# 刷新DATA区域
refreshData
#################################################

# 构建通道Artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新交易文件）
${SDIR}/generateArtifacts.sh

if [ $? -ne 0 ]; then
    echo "Generate artifacts failed"
    exit 1
fi

# 打包rca
mkdir -p ${SDIR}/build/rca/scripts

cp ${SDIR}/rca-bootstrap.sh ${SDIR}/build/rca/rca-bootstrap.sh
cp ${SDIR}/makeDocker.sh ${SDIR}/build/rca/makeDocker.sh
cp ${SDIR}/scripts/start-root-ca.sh ${SDIR}/build/rca/scripts/start-root-ca.sh
cp ${SDIR}/scripts/env.sh ${SDIR}/build/rca/scripts/env.sh

# 打包ica
mkdir -p ${SDIR}/build/ica/scripts

cp ${SDIR}/ica-bootstrap.sh ${SDIR}/build/ica/ica-bootstrap.sh
cp ${SDIR}/makeDocker.sh ${SDIR}/build/ica/makeDocker.sh
cp ${SDIR}/scripts/start-intermediate-ca.sh ${SDIR}/build/ica/scripts/start-intermediate-ca.sh
cp ${SDIR}/scripts/env.sh ${SDIR}/build/ica/scripts/env.sh

# 打包orderer
mkdir -p ${SDIR}/build/orderer/scripts

cp ${SDIR}/orderer-bootstrap.sh ${SDIR}/build/orderer/orderer-bootstrap.sh
cp ${SDIR}/makeDocker.sh ${SDIR}/build/orderer/makeDocker.sh
cp ${SDIR}/scripts/start-orderer.sh ${SDIR}/build/orderer/scripts/start-orderer.sh
cp ${SDIR}/scripts/env.sh ${SDIR}/build/orderer/scripts/env.sh

mkdir -p ${SDIR}/build/orderer$(dirname $GENESIS_BLOCK_FILE)
cp ${SDIR}$GENESIS_BLOCK_FILE ${SDIR}/build/orderer$GENESIS_BLOCK_FILE # 创世区块

# 打包peer
mkdir -p ${SDIR}/build/peer/scripts
cp ${SDIR}/peer-bootstrap.sh ${SDIR}/build/peer/peer-bootstrap.sh
cp ${SDIR}/makeDocker.sh ${SDIR}/build/peer/makeDocker.sh
cp ${SDIR}/scripts/start-peer.sh ${SDIR}/build/peer/scripts/start-peer.sh
cp ${SDIR}/scripts/env.sh ${SDIR}/build/peer/scripts/env.sh

# 打包run
mkdir -p ${SDIR}/build/run/scripts

cp ${SDIR}/run-bootstrap.sh ${SDIR}/build/run/run-bootstrap.sh
cp ${SDIR}/makeDocker.sh ${SDIR}/build/run/makeDocker.sh
cp ${SDIR}/scripts/run-fabric.sh ${SDIR}/build/run/scripts/run-fabric.sh
cp ${SDIR}/scripts/env.sh ${SDIR}/build/run/scripts/env.sh

mkdir -p ${SDIR}/build/run$(dirname $CHANNEL_TX_FILE)
cp ${SDIR}$CHANNEL_TX_FILE ${SDIR}/build/run$CHANNEL_TX_FILE # channel.tx应用通道配置交易文件

for ORG in $PEER_ORGS; do
    initOrgVars $ORG
    COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        mkdir -p ${SDIR}/build/run$(dirname $ANCHOR_TX_FILE)
        cp ${SDIR}$ANCHOR_TX_FILE ${SDIR}/build/run$ANCHOR_TX_FILE # anchors.tx锚节点配置更新交易文件
    done
done

# 构造host配置
{
    for ORG in $ORDERER_ORGS; do

        initOrgVars $ORG

        if $USE_INTERMEDIATE_CA; then
            echo "${INT_CA_HOST}" $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')
        fi
        echo "${ROOT_CA_HOST}" $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')

        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT
            echo "${ORDERER_HOST}" $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['${COUNT}'].IP')
            COUNT=$((COUNT+1))
        done
    done

    for ORG in $PEER_ORGS; do

        initOrgVars $ORG

        if $USE_INTERMEDIATE_CA; then
            echo "${INT_CA_HOST}" $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')
        fi
        echo "${ROOT_CA_HOST}" $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')

        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            echo "${PEER_HOST}" $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['${COUNT}'].IP')
            COUNT=$((COUNT+1))
        done
    done
} > ${SDIR}/host.config