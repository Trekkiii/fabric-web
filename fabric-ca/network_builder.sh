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

function distriRCA {

    local rca_path=./build/rca
    for ORG in $ORGS; do
        rca_user=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.USER_NAME')
        rca_ip=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')
        rca_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.PWD')
        rca_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.PATH')

        echo "Delete remote ${rca_ip} file ${rca_remote_path}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${rca_user} ${rca_ip} ${rca_pwd} ${rca_remote_path}
        echo "Copy file ${rca_path} to remote ${rca_ip}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${rca_user} ${rca_ip} ${rca_pwd} ${rca_remote_path} ${rca_path} "to"
    done
}

function distriICA {

    local ica_path=./build/ica
    for ORG in $ORGS; do
        ica_user=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.USER_NAME')
        ica_ip=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')
        ica_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.PWD')
        ica_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.PATH')

        echo "Delete remote ${ica_ip} file ${ica_remote_path}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${ica_user} ${ica_ip} ${ica_pwd} ${ica_remote_path}
        echo "Copy file ${ica_path} to remote ${ica_ip}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${ica_user} ${ica_ip} ${ica_pwd} ${ica_remote_path} ${ica_path} "to"
    done
}

function distriSetup {

    local setup_path=./build/setup
    local chaincode_path=../chaincode

    local setup_user=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.USER_NAME')
    local setup_ip=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.IP')
    local setup_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PWD')
    local setup_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PATH')

    echo "Delete remote ${setup_ip} file ${setup_remote_path}"
    # 删除远程服务器文件
    ${SDIR}/scripts/file_delete.sh ${setup_user} ${setup_ip} ${setup_pwd} ${setup_remote_path}
    echo "Copy file ${setup_path} to remote ${setup_ip}"
    # 拷贝文件到远程服务器
    ${SDIR}/scripts/file_scp.sh ${setup_user} ${setup_ip} ${setup_pwd} ${setup_remote_path} ${setup_path} "to"

    # 链码
    local chaincode_remote_path=$setup_remote_path"/../chaincode"
    echo "Delete remote ${setup_ip} file ${chaincode_remote_path}"
    # 删除远程服务器文件
    ${SDIR}/scripts/file_delete.sh ${setup_user} ${setup_ip} ${setup_pwd} ${chaincode_remote_path}
    echo "Copy file ${chaincode_path} to remote ${setup_ip}"
    # 拷贝文件到远程服务器
    ${SDIR}/scripts/file_scp.sh ${setup_user} ${setup_ip} ${setup_pwd} ${chaincode_remote_path} ${chaincode_path} "to"
}

function distriZK {

    local zk_path=./build/zk

    local COUNT=1
    while [[ "$COUNT" -le $NUM_ZOOKEEPER ]]; do

        zk_user=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].USER_NAME')
        zk_ip=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].IP')
        zk_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].PWD')
        zk_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].PATH')

        echo "Delete remote ${zk_ip} file ${zk_remote_path}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${zk_user} ${zk_ip} ${zk_pwd} ${zk_remote_path}
        echo "Copy file ${zk_path} to remote ${zk_ip}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${zk_user} ${zk_ip} ${zk_pwd} ${zk_remote_path} ${zk_path} "to"

        COUNT=$((COUNT+1))
    done

    COUNT=1
    while [[ "$COUNT" -le $NUM_KAFKA ]]; do
        zk_user=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].USER_NAME')
        zk_ip=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].IP')
        zk_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].PWD')
        zk_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].PATH')

        echo "Delete remote ${zk_ip} file ${zk_remote_path}"
        # 删除远程服务器文件
        ${SDIR}/scripts/file_delete.sh ${zk_user} ${zk_ip} ${zk_pwd} ${zk_remote_path}
        echo "Copy file ${zk_path} to remote ${zk_ip}"
        # 拷贝文件到远程服务器
        ${SDIR}/scripts/file_scp.sh ${zk_user} ${zk_ip} ${zk_pwd} ${zk_remote_path} ${zk_path} "to"

        COUNT=$((COUNT+1))
    done
}

function distriOrderer {

    local orderer_path=./build/orderer

    for ORG in $ORDERER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            orderer_user=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].USER_NAME')
            orderer_ip=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].IP')
            orderer_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].PWD')
            orderer_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].PATH')

            echo "Delete remote ${orderer_ip} file ${orderer_remote_path}"
            # 删除远程服务器文件
            ${SDIR}/scripts/file_delete.sh ${orderer_user} ${orderer_ip} ${orderer_pwd} ${orderer_remote_path}
            echo "Copy file ${orderer_path} to remote ${orderer_ip}"
            # 拷贝文件到远程服务器
            ${SDIR}/scripts/file_scp.sh ${orderer_user} ${orderer_ip} ${orderer_pwd} ${orderer_remote_path} ${orderer_path} "to"

            COUNT=$((COUNT+1))
        done
    done
}

function distriPeer {

    local peer_path=./build/peer

    for ORG in $PEER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            peer_user=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].USER_NAME')
            peer_ip=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].IP')
            peer_pwd=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].PWD')
            peer_remote_path=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].PATH')

            echo "Delete remote ${peer_ip} file ${peer_remote_path}"
            # 删除远程服务器文件
            ${SDIR}/scripts/file_delete.sh ${peer_user} ${peer_ip} ${peer_pwd} ${peer_remote_path}
            echo "Copy file ${peer_path} to remote ${peer_ip}"
            # 拷贝文件到远程服务器
            ${SDIR}/scripts/file_scp.sh ${peer_user} ${peer_ip} ${peer_pwd} ${peer_remote_path} ${peer_path} "to"

            COUNT=$((COUNT+1))
        done
    done
}

function package {

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

    ########################## 打包rca ##########################
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

    distriRCA

    ########################## 打包ica ##########################
    if $USE_INTERMEDIATE_CA; then
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

        distriICA
    fi

    ########################## 打包setup ##########################
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

    distriSetup

    ########################## 打包zookeeper & kafka ##########################
    log "===> Package Zookeeper & Kafka files"
    mkdir -p ${SDIR}/build/zk/scripts
    cp ${SDIR}/zk-kafka-bootstrap.sh ${SDIR}/build/zk/zk-kafka-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/zk/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/zk/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/zk/down-images.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/zk/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/zk/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/zk/scripts/file_scp.sh

    distriZK

    ########################## 打包orderer ##########################
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

    distriOrderer

    ########################## 打包peer ##########################
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

    distriPeer

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

package