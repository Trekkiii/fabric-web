#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 构建项目，为不同节点打包脚本

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

function printHelp {

    cat << EOF
    使用方法:
        network_builder.sh [-e] <ORG>
            -e          动态增加组织
            <ORG>       新加入的组织
EOF
}

function distriRCA {

    local ORG=$1

    local RCA_PATH=./build/rca

    RCA_USER=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.USER_NAME')
    RCA_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')
    RCA_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.PWD')
    RCA_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.PATH')

    echo "Delete remote ${RCA_IP} file ${RCA_REMOTE_PATH}"
    # 删除远程服务器文件
    ${SDIR}/scripts/file_delete.sh ${RCA_USER} ${RCA_IP} ${RCA_PWD} ${RCA_REMOTE_PATH}
    echo "Copy file ${RCA_PATH} to remote ${RCA_IP}"
    # 拷贝文件到远程服务器
    ${SDIR}/scripts/file_scp.sh ${RCA_USER} ${RCA_IP} ${RCA_PWD} ${RCA_REMOTE_PATH} ${RCA_PATH} "to"

}

function distriICA {

    local ORG=$1

    local ICA_PATH=./build/ica

    ICA_USER=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.USER_NAME')
    ICA_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')
    ICA_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.PWD')
    ICA_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.PATH')

    echo "Delete remote ${ICA_IP} file ${ICA_REMOTE_PATH}"
    # 删除远程服务器文件
    ${SDIR}/scripts/file_delete.sh ${ICA_USER} ${ICA_IP} ${ICA_PWD} ${ICA_REMOTE_PATH}
    echo "Copy file ${ICA_PATH} to remote ${ICA_IP}"
    # 拷贝文件到远程服务器
    ${SDIR}/scripts/file_scp.sh ${ICA_USER} ${ICA_IP} ${ICA_PWD} ${ICA_REMOTE_PATH} ${ICA_PATH} "to"

}

function distriSetup {

    local SETUP_PATH=./build/setup
    local CHAINCODE_PATH=../chaincode

    local SETUP_USER=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.USER_NAME')
    local SETUP_IP=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.IP')
    local SETUP_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PWD')
    local SETUP_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PATH')

    echo "Delete remote ${SETUP_IP} file ${SETUP_REMOTE_PATH}"
    # 删除远程服务器文件
    ${SDIR}/scripts/file_delete.sh ${SETUP_USER} ${SETUP_IP} ${SETUP_PWD} ${SETUP_REMOTE_PATH}
    echo "Copy file ${SETUP_PATH} to remote ${SETUP_IP}"
    # 拷贝文件到远程服务器
    ${SDIR}/scripts/file_scp.sh ${SETUP_USER} ${SETUP_IP} ${SETUP_PWD} ${SETUP_REMOTE_PATH} ${SETUP_PATH} "to"

    # 链码
    local CHAINCODE_REMOTE_PATH=$SETUP_REMOTE_PATH"/../chaincode"
    echo "Delete remote ${SETUP_IP} file ${CHAINCODE_REMOTE_PATH}"
    # 删除远程服务器文件
    ${SDIR}/scripts/file_delete.sh ${SETUP_USER} ${SETUP_IP} ${SETUP_PWD} ${CHAINCODE_REMOTE_PATH}
    echo "Copy file ${CHAINCODE_PATH} to remote ${SETUP_IP}"
    # 拷贝文件到远程服务器
    ${SDIR}/scripts/file_scp.sh ${SETUP_USER} ${SETUP_IP} ${SETUP_PWD} ${CHAINCODE_REMOTE_PATH} ${CHAINCODE_PATH} "to"
}

function distriZK {

    local ZK_PATH=./build/zk

    local COUNT=1
    while [[ "$COUNT" -le $NUM_ZOOKEEPER ]]; do

        ZK_USER=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].USER_NAME')
        ZK_IP=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].IP')
        ZK_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].PWD')
        ZK_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].PATH')

        echo "Delete remote ${ZK_IP} file ${ZK_REMOTE_PATH}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${ZK_USER} ${ZK_IP} ${ZK_PWD} ${ZK_REMOTE_PATH}
        echo "Copy file ${ZK_PATH} to remote ${ZK_IP}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${ZK_USER} ${ZK_IP} ${ZK_PWD} ${ZK_REMOTE_PATH} ${ZK_PATH} "to"

        COUNT=$((COUNT+1))
    done

    COUNT=1
    while [[ "$COUNT" -le $NUM_KAFKA ]]; do
        ZK_USER=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].USER_NAME')
        ZK_IP=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].IP')
        ZK_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].PWD')
        ZK_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].PATH')

        echo "Delete remote ${ZK_IP} file ${ZK_REMOTE_PATH}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${ZK_USER} ${ZK_IP} ${ZK_PWD} ${ZK_REMOTE_PATH}
        echo "Copy file ${ZK_PATH} to remote ${ZK_IP}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${ZK_USER} ${ZK_IP} ${ZK_PWD} ${ZK_REMOTE_PATH} ${ZK_PATH} "to"

        COUNT=$((COUNT+1))
    done
}

function distriOrderer {

    local ORDERER_PATH=./build/orderer

    for ORG in $ORDERER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            ORDERER_USER=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].USER_NAME')
            ORDERER_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].IP')
            ORDERER_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].PWD')
            ORDERER_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].PATH')

            echo "Delete remote ${ORDERER_IP} file ${ORDERER_REMOTE_PATH}"
            # 删除远程服务器文件
            ${SDIR}/scripts/file_delete.sh ${ORDERER_USER} ${ORDERER_IP} ${ORDERER_PWD} ${ORDERER_REMOTE_PATH}
            echo "Copy file ${ORDERER_PATH} to remote ${ORDERER_IP}"
            # 拷贝文件到远程服务器
            ${SDIR}/scripts/file_scp.sh ${ORDERER_USER} ${ORDERER_IP} ${ORDERER_PWD} ${ORDERER_REMOTE_PATH} ${ORDERER_PATH} "to"

            COUNT=$((COUNT+1))
        done
    done
}

function distriPeer {

    local PEER_PATH=./build/peer

    for ORG in $PEER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            PEER_USER=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].USER_NAME')
            PEER_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].IP')
            PEER_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].PWD')
            PEER_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].PATH')

            echo "Delete remote ${PEER_IP} file ${PEER_REMOTE_PATH}"
            # 删除远程服务器文件
            ${SDIR}/scripts/file_delete.sh ${PEER_USER} ${PEER_IP} ${PEER_PWD} ${PEER_REMOTE_PATH}
            echo "Copy file ${PEER_PATH} to remote ${PEER_IP}"
            # 拷贝文件到远程服务器
            ${SDIR}/scripts/file_scp.sh ${PEER_USER} ${PEER_IP} ${PEER_PWD} ${PEER_REMOTE_PATH} ${PEER_PATH} "to"

            COUNT=$((COUNT+1))
        done
    done
}

function distriEYFN {

    local ORG=$1

    local EYFN_PATH=./build/eyfn
    local CHAINCODE_PATH=../chaincode

    set +e  # 不强制要求每个节点都可访问，可以预设，后面需要的时候再修改为对应的ip
    COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        PEER_USER=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].USER_NAME')
        PEER_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].IP')
        PEER_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].PWD')
        PEER_REMOTE_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].PATH')

        echo "Delete remote ${PEER_IP} file ${PEER_REMOTE_PATH}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${PEER_USER} ${PEER_IP} ${PEER_PWD} ${PEER_REMOTE_PATH}
        echo "Copy file ${EYFN_PATH} to remote ${PEER_IP}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${PEER_USER} ${PEER_IP} ${PEER_PWD} ${PEER_REMOTE_PATH} ${EYFN_PATH} "to"

        # 链码
        local CHAINCODE_REMOTE_PATH=$PEER_REMOTE_PATH"/../chaincode"
        echo "Delete remote ${PEER_IP} file ${CHAINCODE_REMOTE_PATH}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${PEER_USER} ${PEER_IP} ${PEER_PWD} ${CHAINCODE_REMOTE_PATH}
        echo "Copy file ${CHAINCODE_PATH} to remote ${PEER_IP}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${PEER_USER} ${PEER_IP} ${PEER_PWD} ${CHAINCODE_REMOTE_PATH} ${CHAINCODE_PATH} "to"

        COUNT=$((COUNT+1))
    done
    set -e
}

function packRCA {
    log "===> Package RCA files"
    mkdir -p ${SDIR}/build/rca/scripts
    cp ${SDIR}/rca-bootstrap.sh ${SDIR}/build/rca/rca-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/rca/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/rca/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/rca/down-images.sh
    cp ${SDIR}/scripts/start-root-ca.sh ${SDIR}/build/rca/scripts/start-root-ca.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/rca/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/rca/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/rca/scripts/file_scp.sh
}

function packICA {

    log "===> Package ICA files"
    mkdir -p ${SDIR}/build/ica/scripts
    cp ${SDIR}/ica-bootstrap.sh ${SDIR}/build/ica/ica-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/ica/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/ica/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/ica/down-images.sh
    cp ${SDIR}/scripts/start-intermediate-ca.sh ${SDIR}/build/ica/scripts/start-intermediate-ca.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/ica/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/ica/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/ica/scripts/file_scp.sh
}

function packSetup {

    log "===> Package Setup files"
    mkdir -p ${SDIR}/build/setup/scripts
    cp ${SDIR}/setup-bootstrap.sh ${SDIR}/build/setup/setup-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/setup/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/setup/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/setup/down-images.sh
    cp ${SDIR}/scripts/setup-fabric.sh ${SDIR}/build/setup/scripts/setup-fabric.sh
    cp ${SDIR}/scripts/run-fabric.sh ${SDIR}/build/setup/scripts/run-fabric.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/setup/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/setup/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/setup/scripts/file_scp.sh
}

function packZK {

    log "===> Package Zookeeper & Kafka files"
    mkdir -p ${SDIR}/build/zk/scripts
    cp ${SDIR}/zk-kafka-bootstrap.sh ${SDIR}/build/zk/zk-kafka-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/zk/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/zk/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/zk/down-images.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/zk/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/zk/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/zk/scripts/file_scp.sh
}

function packOrderer {

    log "===> Package Orderer files"
    mkdir -p ${SDIR}/build/orderer/scripts
    cp ${SDIR}/orderer-bootstrap.sh ${SDIR}/build/orderer/orderer-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/orderer/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/orderer/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/orderer/down-images.sh
    cp ${SDIR}/scripts/start-orderer.sh ${SDIR}/build/orderer/scripts/start-orderer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/orderer/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/orderer/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/orderer/scripts/file_scp.sh
}

function packPeer {

    log "===> Package Peer files"
    mkdir -p ${SDIR}/build/peer/scripts
    cp ${SDIR}/peer-bootstrap.sh ${SDIR}/build/peer/peer-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/peer/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/peer/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/peer/down-images.sh
    cp ${SDIR}/scripts/start-peer.sh ${SDIR}/build/peer/scripts/start-peer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/peer/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/peer/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/peer/scripts/file_scp.sh
}

function packEYFN {

    log "===> Package eyfn files"
    mkdir -p ${SDIR}/build/eyfn/scripts/eyfn
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/eyfn/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/eyfn/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/eyfn/down-images.sh
    cp ${SDIR}/scripts/start-peer.sh ${SDIR}/build/eyfn/scripts/start-peer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/eyfn/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/eyfn/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/eyfn/scripts/file_scp.sh
    cp ${SDIR}/scripts/eyfn/step0.sh ${SDIR}/build/eyfn/scripts/eyfn/step0.sh
    cp ${SDIR}/scripts/eyfn/step1.sh ${SDIR}/build/eyfn/scripts/eyfn/step1.sh
    cp ${SDIR}/scripts/eyfn/step2.sh ${SDIR}/build/eyfn/scripts/eyfn/step2.sh
    cp ${SDIR}/eyfn_builder.sh ${SDIR}/build/eyfn/eyfn_builder.sh
    cp ${SDIR}/eyfn-bootstrap.sh ${SDIR}/build/eyfn/eyfn-bootstrap.sh
}

function package {

    if [ "$IS_EXTEND" == "true" ]; then
        ########################## 打包rca ##########################
        packRCA
        distriRCA $ORG

        ########################## 打包ica ##########################
        if $USE_INTERMEDIATE_CA; then
            packICA
            distriICA $ORG
        fi

        ########################## 打包eyfn(extend your fabric network)  ##########################
        packEYFN
        distriEYFN $ORG
    else
        ########################## 打包rca ##########################
        packRCA
        for ORG in $ORGS; do
            distriRCA $ORG
        done

        ########################## 打包ica ##########################
        if $USE_INTERMEDIATE_CA; then
            packICA
            for ORG in $ORGS; do
                distriICA $ORG
            done
        fi

        ########################## 打包setup ##########################
        packSetup
        distriSetup

        ########################## 打包zookeeper & kafka ##########################
        packZK
        distriZK

        ########################## 打包orderer ##########################
        packOrderer
        distriOrderer

        ########################## 打包peer ##########################
        packPeer
        distriPeer
    fi
}

function build {

    # jq --raw-output / -r
    # With  this option, if the filter´s result is a string then it will be written directly to standard output rather than being formatted as a JSON string with
    # quotes. This can be useful for making jq filters talk to non-JSON-based systems.

    # zookeeper集群节点数量
    NUM_ZOOKEEPER=$(cat fabric.config | jq -r '.NUM_ZOOKEEPER')
    # kafka集群节点数量
    NUM_KAFKA=$(cat fabric.config | jq -r '.NUM_KAFKA')
    # orderer组织的名称
    ORDERER_ORGS=$(cat fabric.config | jq -r '.ORDERER_ORGS')
    # peer组织的名称
    PEER_ORGS=$(cat fabric.config | jq -r '.PEER_ORGS')
    # 每一个peer组织的peers数量
    NUM_PEERS=$(cat fabric.config | jq -r '.NUM_PEERS')
    # 每一个orderer组织的orderer节点的数量
    NUM_ORDERERS=$(cat fabric.config | jq -r '.NUM_ORDERERS')
    # 所有组织名称
    ORGS="$ORDERER_ORGS $PEER_ORGS"

    # sed on MacOSX does not support -i flag with a null extension. We will use
    # 't' for our back-up's extension and delete it at the end of the function
    local ARCH=`uname -s | grep Darwin`
    if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
    else
        OPTS="-i"
    fi

    sed $OPTS "s/NUM_ZOOKEEPER_PLACEHOLDER/${NUM_ZOOKEEPER}/g" ${SDIR}/scripts/env.sh
    sed $OPTS "s/NUM_KAFKA_PLACEHOLDER/${NUM_KAFKA}/g" ${SDIR}/scripts/env.sh
    sed $OPTS "s/ORDERER_ORGS_PLACEHOLDER/\"${ORDERER_ORGS}\"/g" ${SDIR}/scripts/env.sh
    sed $OPTS "s/PEER_ORGS_PLACEHOLDER/\"${PEER_ORGS}\"/g" ${SDIR}/scripts/env.sh
    sed $OPTS "s/NUM_PEERS_PLACEHOLDER/${NUM_PEERS}/g" ${SDIR}/scripts/env.sh
    sed $OPTS "s/NUM_ORDERERS_PLACEHOLDER/${NUM_ORDERERS}/g" ${SDIR}/scripts/env.sh

    package

    log "===> Construct a host configuration"
    echo

    # 构造host配置
    {

        COUNT=1
        while [[ "$COUNT" -le $NUM_ZOOKEEPER ]]; do
            initZKVars $((COUNT-1))
            echo $(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].IP') $ZK_HOST
            COUNT=$((COUNT+1))
        done

        COUNT=1
        while [[ "$COUNT" -le $NUM_KAFKA ]]; do
            initKafkaVars $((COUNT-1))
            echo $(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].IP') $KAFKA_HOST
            COUNT=$((COUNT+1))
        done

        for ORG in $ORGS; do
            initOrgVars $ORG
            if $USE_INTERMEDIATE_CA; then
                echo $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')" ${INT_CA_HOST}"
            fi
            echo $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')" ${ROOT_CA_HOST}"
        done

        for ORG in $ORDERER_ORGS; do
            COUNT=1
            while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
                initOrdererVars $ORG $COUNT
                echo $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].IP')" ${ORDERER_HOST}"
                COUNT=$((COUNT+1))
            done
        done

        for ORG in $PEER_ORGS; do
            COUNT=1
            while [[ "$COUNT" -le $NUM_PEERS ]]; do
                initPeerVars $ORG $COUNT
                echo $(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].IP')" ${PEER_HOST}"
                COUNT=$((COUNT+1))
            done
        done
    } > ${SDIR}/build/host.config

    log "Build successfully..."
}

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
            if [ $# -ne 1 ]; then
                echo "Usage: ./network_builder.sh [-e] <ORG>"
                exit 1
            fi
            ORG=$1
            ;;
    esac
done

# 删除原build文件夹
if [ -d ${SDIR}/build ]; then
    echo "Delete the original build folder"
    rm -rf ${SDIR}/build
fi

installJQ
# 校验fabric.config配置是否是合法性JSON
cat fabric.config | jq . >& /dev/null
if [ $? -ne 0 ]; then
	fatal "fabric.config isn't JSON format"
fi

build