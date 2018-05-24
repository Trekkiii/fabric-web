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

function package {

    # orderer组织的名称
    local ORDERER_ORGS=$(cat fabric.config | jq -r '.ORDERER_ORGS')
    # peer组织的名称
    local PEER_ORGS=$(cat fabric.config | jq -r '.PEER_ORGS')
    # 每一个peer组织的peers数量
    local NUM_PEERS=$(cat fabric.config | jq -r '.NUM_PEERS')
    # 每一个orderer组织的orderer节点的数量
    local NUM_ORDERERS=$(cat fabric.config | jq -r '.NUM_ORDERERS')

    # sed on MacOSX does not support -i flag with a null extension. We will use
    # 't' for our back-up's extension and delete it at the end of the function
    local ARCH=`uname -s | grep Darwin`
    if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
    else
        OPTS="-i"
    fi

    sed $OPTS "s/ORDERER_ORGS_PLACEHOLDER/${ORDERER_ORGS}/g" ${SDIR}/scripts/env.sh
    sed $OPTS "s/PEER_ORGS_PLACEHOLDER/${PEER_ORGS}/g" ${SDIR}/scripts/env.sh
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

    ########################## 打包ica ##########################
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

    ########################## 打包setup ##########################
    log "===> Package SETUP files"
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

    ########################## 打包orderer ##########################
    log "===> Package ORDERER files"
    mkdir -p ${SDIR}/build/orderer/scripts
    cp ${SDIR}/orderer-bootstrap.sh ${SDIR}/build/orderer/orderer-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/orderer/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/orderer/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/orderer/down-images.sh
    cp ${SDIR}/scripts/start-orderer.sh ${SDIR}/build/orderer/scripts/start-orderer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/orderer/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/orderer/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/orderer/scripts/file_scp.sh

    ########################## 打包peer ##########################
    log "===> Package PEER files"
    mkdir -p ${SDIR}/build/peer/scripts
    cp ${SDIR}/peer-bootstrap.sh ${SDIR}/build/peer/peer-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/peer/makeDocker.sh
    cp ${SDIR}/fabric.config ${SDIR}/build/peer/fabric.config
    cp ${SDIR}/down-images.sh ${SDIR}/build/peer/down-images.sh
    cp ${SDIR}/scripts/start-peer.sh ${SDIR}/build/peer/scripts/start-peer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/peer/scripts/env.sh
    cp ${SDIR}/scripts/file_exits.sh ${SDIR}/build/peer/scripts/file_exits.sh
    cp ${SDIR}/scripts/file_scp.sh ${SDIR}/build/peer/scripts/file_scp.sh

    log "===> Construct a host configuration"
    echo

    # 构造host配置
    {

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