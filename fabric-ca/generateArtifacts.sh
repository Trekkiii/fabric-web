#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 此脚本执行以下操作：
#   1) 构建通道artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新文件）

function makeConfigTxYaml {

    {
    echo "################################################################################
#
#   Profile
#
#   - 可以在这里编写不同的Profile，以便将其指定为configtxgen的参数
#
################################################################################
Profiles:

    OrgsOrdererGenesis:
        Orderer:
            # orderer type：\"solo\" 、 \"kafka\"
            OrdererType: solo
            Addresses:" # Orderers服务地址
                for ORG in $ORDERER_ORGS; do
                    local COUNT=1
                    while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
                        initOrdererVars $ORG $COUNT
                        echo "                - $ORDERER_HOST:7050"
                        COUNT=$((COUNT+1))
                    done
                done
                echo "
            # 创建批量交易的最大超时，一批交易可以构建一个区块
            BatchTimeout: 2s
            # 控制写入到区块中交易的个数
            BatchSize:
                # 一批消息的最大个数
                MaxMessageCount: 10
                # batch最大字节数，任何时候不能超过
                AbsoluteMaxBytes: 99 MB
                # 通常情况下，batch建议字节数；极端情况下，如单个消息就超过该值（但未超过最大限制），仍允许构成区块
                PreferredMaxBytes: 512 KB
            Kafka:
                # Brokers: Kafka brokers作为orderer后端
                # NOTE: 使用IP:port表示法
                Brokers:
                    - 127.0.0.1:9092
            Organizations:" # 属于orderer通道的组织
                for ORG in $ORDERER_ORGS; do
                    initOrgVars $ORG
                    echo "                - *${ORG_CONTAINER_NAME}" # 引用
                done
    echo "
        Consortiums: # Orderer所服务的联盟列表。每个联盟中组织彼此使用相同的通道创建策略，可以彼此创建应用通道
            SampleConsortium:
                Organizations:" # SampleConsortium联盟下的组织列表
                    for ORG in $PEER_ORGS; do
                        initOrgVars $ORG
                        echo "                    - *${ORG_CONTAINER_NAME}"
                    done
    echo "
    OrgsChannel:
        Consortium: SampleConsortium # SampleConsortium联盟
        Application:
            <<: *ApplicationDefaults
            Organizations:" # TODO 作用是啥？
                for ORG in $PEER_ORGS; do
                    initOrgVars $ORG
                    echo "                - *${ORG_CONTAINER_NAME}"
                done
    echo "
################################################################################
#
#   Section: Organizations
#
#   - 这部分定义了在配置中引用的不同组织标识
#
################################################################################
Organizations:"

    for ORG in $ORDERER_ORGS; do
        printOrdererOrg $ORG
    done

    for ORG in $PEER_ORGS; do
        printPeerOrg $ORG 1 # 每个组织的第一个节点定义为锚节点
    done

   echo "
################################################################################
#
#   SECTION: Application
#
#   This section defines the values to encode into a config transaction or
#   genesis block for application related parameters
#
################################################################################
Application: &ApplicationDefaults

    # Organizations is the list of orgs which are defined as participants on
    # the application side of the network
    Organizations:
"
    } > $SDIR/configtx.yaml
}

# printOrdererOrg <ORG>
function printOrdererOrg {
   initOrgVars $1
   printOrg
}

# printPeerOrg <ORG> <COUNT>
function printPeerOrg {

    initPeerVars $1 $2
    printOrg

    echo "
        AnchorPeers:
            # 锚节点地址，用于跨组织的Gossip通信
            - Host: $PEER_HOST
              Port: 7051"
}

# printOrg
function printOrg {

    echo "
    - &$ORG_CONTAINER_NAME
        Name: $ORG
        # MSP的ID
        ID: $ORG_MSP_ID
        # MSP相关文件所在路径，/${DATA}/orgs/${ORG}/msp
        MSPDir: $ORG_MSP_DIR
    "
}

function generateChannelArtifacts() {

    which configtxgen

    if [ "$?" -ne 0 ]; then
        fatal "configtxgen tool not found. exiting"
    fi

    log "Generating orderer genesis block at $GENESIS_BLOCK_FILE"
    # Note: 由于某些未知原因（至少现在）创世区块不能命名为orderer.genesis.block，否则orderer将无法启动！
    configtxgen -profile OrgsOrdererGenesis -outputBlock ${SDIR}$GENESIS_BLOCK_FILE
    if [ "$?" -ne 0 ]; then
        fatal "Failed to generate orderer genesis block"
    fi

    log "Generating channel configuration transaction at $CHANNEL_TX_FILE"
    configtxgen -profile OrgsChannel -outputCreateChannelTx ${SDIR}$CHANNEL_TX_FILE -channelID $CHANNEL_NAME
    if [ "$?" -ne 0 ]; then
        fatal "Failed to generate channel configuration transaction"
    fi

    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
        configtxgen -profile OrgsChannel -outputAnchorPeersUpdate ${SDIR}$ANCHOR_TX_FILE \
                 -channelID $CHANNEL_NAME -asOrg $ORG
        if [ "$?" -ne 0 ]; then
            fatal "Failed to generate anchor peer update for $ORG"
        fi
    done

}

function main {

    makeConfigTxYaml

    generateChannelArtifacts

    log "Finished building channel artifacts"
}

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

#################################################
# 删除原有的configtx.yaml
if [ -f ${SDIR}/configtx.yaml ]; then
    rm -rf ${SDIR}/configtx.yaml
fi
# 刷新DATA区域
refreshData
#################################################

main