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

export ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

BINARY_FILE=hyperledger-fabric-${ARCH}-${VERSION}.tar.gz
CA_BINARY_FILE=hyperledger-fabric-ca-${ARCH}-${CA_VERSION}.tar.gz

binariesInstall() {

    echo "===> Downloading version ${FABRIC_TAG} platform specific fabric binaries"
    binaryDownload ${BINARY_FILE} https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/${ARCH}-${VERSION}/${BINARY_FILE}

    # 22 对应于 404
    if [ $? -eq 22 ]; then
        echo
        echo "------> ${FABRIC_TAG} platform specific fabric binary is not available to download <----"
        echo
    fi

    echo "===> Downloading version ${CA_TAG} platform specific fabric-ca-client binary"
    binaryDownload ${CA_BINARY_FILE} https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/${ARCH}-${CA_VERSION}/${CA_BINARY_FILE}
    if [ $? -eq 22 ]; then
         echo
         echo "------> ${CA_TAG} fabric-ca-client binary is not available to download  (Available from 1.1.0-rc1) <----"
         echo
    fi
}

# 这会尝试一次下载.tar.gz，但会在失败时调用binaryIncrementalDownload()函数，允许在网络出现故障时恢复。
binaryDownload() {

    local BINARY_FILE=$1 # 保存的文件名
    # e.g
    #   https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/linux-amd64-1.1.0/hyperledger-fabric-linux-amd64-1.1.0.tar.gz
    #   https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/linux-amd64-1.1.0/hyperledger-fabric-ca-linux-amd64-1.1.0.tar.gz
    local URL=$2 # 下载url

    # 检查以前是否发生故障并且文件下载了一部分
    if [ -e ${BINARY_FILE} ]; then
        echo "==> Partial binary file found. Resuming download..."
        binaryIncrementalDownload ${BINARY_FILE} ${URL}
    else
        curl ${URL} | tar xz || rc=$?
        if [ ! -z "$rc" ]; then
            echo "==> There was an error downloading the binary file. Switching to incremental download."
            echo "==> Downloading file..."
            binaryIncrementalDownload ${BINARY_FILE} ${URL}
        else
            echo "==> Done."
        fi
    fi
}

# 首先在本地增量下载.tar.gz文件，下载完成后才解压。这比binaryDownload()慢，但允许恢复下载。
binaryIncrementalDownload() {

    local BINARY_FILE=$1
    local URL=$2

    # Usage: curl [options...] <url>
    #   Options: (H) means HTTP/HTTPS only, (F) means FTP only
    #
    #   -f, --fail      Fail silently (no output at all) on HTTP errors (H) 连接失败时不显示http错误
    #   -s, --silent    Silent mode (don't output anything) 静默模式。不输出任何东西
    #   -C, --continue-at OFFSET  Resumed transfer OFFSET 继续对该文件进行下载，已经下载过的文件不会被重新下载。偏移量是以字节为单位的整数，如果让curl自动推断出正确的续传位置使用 '-C -'。
    curl -f -s -C - ${URL} -o ${BINARY_FILE} || rc=$?

    # 由于目前的Nexus库限制：
    # 当有一个没有更多字节下载的恢复尝试时，curl会返回33
    # 完成恢复下载后，curl返回2
    # 使用-f选项，404时curl返回22
    if [ "$rc" = 22 ]; then
        # looks like the requested file doesn't actually exist so stop here
        return 22
    fi
    # 在本地增量下载.tar.gz文件成功：-z "$rc"
    # 恢复下载完成：$rc -eq 33，$rc -eq 2
    if [ -z "$rc" ] || [ $rc -eq 33 ] || [ $rc -eq 2 ]; then
        # The checksum validates that RC 33 or 2 are not real failures
        echo "==> File downloaded. Verifying the md5sum..."
        localMd5sum=$(md5sum ${BINARY_FILE} | awk '{print $1}')
        remoteMd5sum=$(curl -s ${URL}.md5)
        if [ "$localMd5sum" == "$remoteMd5sum" ]; then
            echo "==> Extracting ${BINARY_FILE}..."
            tar xzf ./${BINARY_FILE} --overwrite
            echo "==> Done."
            rm -f ${BINARY_FILE} ${BINARY_FILE}.md5
        else
            echo "Download failed: the local md5sum is different from the remote md5sum. Please try again."
            rm -f ${BINARY_FILE} ${BINARY_FILE}.md5
            exit 1
        fi
    else
        echo "Failure downloading binaries (curl RC=$rc). Please try again and the download will resume from where it stopped."
        exit 1
    fi
}

function package {

    # 打包rca
    mkdir -p ${SDIR}/build/rca/scripts

    cp ${SDIR}/rca-bootstrap.sh ${SDIR}/build/rca/rca-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/rca/makeDocker.sh
    cp ${SDIR}/down-images.sh ${SDIR}/build/rca/down-images.sh
    cp ${SDIR}/scripts/start-root-ca.sh ${SDIR}/build/rca/scripts/start-root-ca.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/rca/scripts/env.sh

    # 打包ica
    mkdir -p ${SDIR}/build/ica/scripts

    cp ${SDIR}/ica-bootstrap.sh ${SDIR}/build/ica/ica-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/ica/makeDocker.sh
    cp ${SDIR}/down-images.sh ${SDIR}/build/ica/down-images.sh
    cp ${SDIR}/scripts/start-intermediate-ca.sh ${SDIR}/build/ica/scripts/start-intermediate-ca.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/ica/scripts/env.sh

    # 打包orderer
    mkdir -p ${SDIR}/build/orderer/scripts

    cp ${SDIR}/orderer-bootstrap.sh ${SDIR}/build/orderer/orderer-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/orderer/makeDocker.sh
    cp ${SDIR}/down-images.sh ${SDIR}/build/orderer/down-images.sh
    cp ${SDIR}/scripts/start-orderer.sh ${SDIR}/build/orderer/scripts/start-orderer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/orderer/scripts/env.sh

    mkdir -p ${SDIR}/build/orderer$(dirname $GENESIS_BLOCK_FILE)
    mv ${SDIR}$GENESIS_BLOCK_FILE ${SDIR}/build/orderer$GENESIS_BLOCK_FILE # 创世区块

    # 打包peer
    mkdir -p ${SDIR}/build/peer/scripts
    cp ${SDIR}/peer-bootstrap.sh ${SDIR}/build/peer/peer-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/peer/makeDocker.sh
    cp ${SDIR}/down-images.sh ${SDIR}/build/peer/down-images.sh
    cp ${SDIR}/scripts/start-peer.sh ${SDIR}/build/peer/scripts/start-peer.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/peer/scripts/env.sh

    # 打包setup
    mkdir -p ${SDIR}/build/setup/scripts
    cp ${SDIR}/setup-bootstrap.sh ${SDIR}/build/setup/setup-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/setup/makeDocker.sh
    cp ${SDIR}/down-images.sh ${SDIR}/build/setup/down-images.sh
    cp ${SDIR}/scripts/setup-fabric.sh ${SDIR}/build/setup/scripts/setup-fabric.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/setup/scripts/env.sh

    # 打包run
    mkdir -p ${SDIR}/build/run/scripts

    cp ${SDIR}/run-bootstrap.sh ${SDIR}/build/run/run-bootstrap.sh
    cp ${SDIR}/makeDocker.sh ${SDIR}/build/run/makeDocker.sh
    cp ${SDIR}/down-images.sh ${SDIR}/build/run/down-images.sh
    cp ${SDIR}/scripts/run-fabric.sh ${SDIR}/build/run/scripts/run-fabric.sh
    cp ${SDIR}/scripts/env.sh ${SDIR}/build/run/scripts/env.sh

    mkdir -p ${SDIR}/build/run$(dirname $CHANNEL_TX_FILE)
    mv ${SDIR}$CHANNEL_TX_FILE ${SDIR}/build/run$CHANNEL_TX_FILE # channel.tx应用通道配置交易文件

    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            mkdir -p ${SDIR}/build/run$(dirname $ANCHOR_TX_FILE)
            mv ${SDIR}$ANCHOR_TX_FILE ${SDIR}/build/run$ANCHOR_TX_FILE # anchors.tx锚节点配置更新交易文件
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
    } > ${SDIR}/build/host.config
}

# 删除原build文件夹
if [ -d ${SDIR}/build ]; then
    rm -rf ${SDIR}/build
fi

# 下载所需的二进制文件
if [ "$BINARIES" == "true" ]; then
  echo
  echo "Installing Hyperledger Fabric binaries"
  echo
  # 下载configtxgen、configtxlator、cryptogen、orderer、peer等二进制文件，以及get-docker-images.sh
  binariesInstall
fi
# 设置PATH
export PATH=${PWD}/bin:$PATH

# 构建通道Artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新交易文件）
${SDIR}/generateArtifacts.sh
if [ $? -ne 0 ]; then
    echo "Generate artifacts failed"
    exit 1
fi

package