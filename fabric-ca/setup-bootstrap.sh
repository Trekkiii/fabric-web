#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动setup容器，
#   1) 向中间层fabric-ca-servers注册Orderer和Peer身份
#   2) 构建通道Artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新交易文件）

function printHelp {

cat << EOF
    使用方法:
        setup-bootstrap.sh [-h] [-?] [-d]
            -h|-?       获取此帮助信息
            -d          从网络下载二进制文件

    脚本需要使用fabric的二进制文件，请将这些二进制文件置于PATH路径下。
EOF
echo "    如果脚本找不到，会基于fabric源码编译生成二进制文件，此时需要保证\"$HOME/gopath/src/github.com/hyperledger/fabric\"源码目录存在"
echo
echo"    当然你也可以通过指定-d选项从网络下载该二进制文件"
}

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

# 启动'run'容器，执行创建应用通道、加入应用通道、更新锚节点、安装链码、实例化链码、查询调用链码等操作
startRun() {

    docker-compose up -d --no-deps run

    # 等待'run'容器启动，随后tail -f run.sum
    dowait "the docker 'run' container to start" 60 ${SDIR}/${RUN_LOGFILE} ${SDIR}/${RUN_SUMFILE}

    tail -f ${SDIR}/${RUN_SUMFILE}&
    TAIL_PID=$!
    sleep 5
    # 等待'run'容器执行完成
    while true; do
        if [ -f ${SDIR}/${RUN_SUCCESS_FILE} ]; then
            kill -9 $TAIL_PID
            exit 0
        elif [ -f ${SDIR}/${RUN_FAIL_FILE} ]; then
            kill -9 $TAIL_PID
            exit 1
        else
            sleep 1
        fi
    done
}

# 等待所有orderers和peers节点启动，对于每个orderer&peer节点，默认超时等待30分钟
function waitAllOrderersAndPeers {

    for ORG in $ORDERER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT

            # Usage: waitPort <what> <timeoutInSecs> <errorLogFile|doc> <host> <port>
            waitPort "Orderer orderer${NUM}-${ORG} to start" 1800 $ORDERER_LOGFILE $ORDERER_HOST 7050

            COUNT=$((COUNT+1))
        done
    done

    for ORG in $PEER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT

            # Usage: waitPort <what> <timeoutInSecs> <errorLogFile|doc> <host> <port>
            waitPort "Peer peer${NUM}-${ORG} to start" 1800 $PEER_LOGFILE $PEER_HOST 7051

            COUNT=$((COUNT+1))
        done
    done
}

set -e

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

if [ $(whoami) != "root" ]; then
    log "Please use root to execute this sh"
    exit 1
fi

# 删除'setup'容器
removeFabricContainers "setup"
# 删除'run'容器
removeFabricContainers "run"
# 刷新DATA区域（锚节点配置更新交易文件、创世区块、应用通道配置交易文件等）
refreshData

BINARY_FILE=hyperledger-fabric-${ARCH}-${VERSION}.tar.gz
CA_BINARY_FILE=hyperledger-fabric-ca-${ARCH}-${CA_VERSION}.tar.gz

DOWN_REMOTE_BIN=false

while getopts "h?d" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
        d)
            DOWN_REMOTE_BIN=true
            ;;
    esac
done

if [ "$DOWN_REMOTE_BIN" == "true" ]; then # 下载构建通道Artifacts所需的二进制文件

    echo
    echo "Installing Hyperledger Fabric binaries . And get them from the remote."
    echo

    # 下载bin/下的configtxgen、configtxlator、cryptogen、orderer、peer二进制文件，以及config/下的configtx.yaml、core.yaml、orderer.yaml配置文件
    binariesInstall

    export PATH=${PWD}/bin:$PATH

else # 基于fabric源码生成构建通道Artifacts所需的二进制文件
    echo
    echo "Installing Hyperledger Fabric binaries. And build them based on local source."
    echo

    if [ ! -d $FABRIC_ROOT ]; then
        fatal "$FABRIC_ROOT not exits."
    fi

    # cryptogen 工具
    make -C $FABRIC_ROOT release

    export PATH=$FABRIC_ROOT/release/$ARCH/bin:$PATH
fi

# 获取所有组织的TLS CAChain证书，
# 以便向所有CA服务端登记CA管理员身份、注册所有Orderer相关的用户实体，以及注册所有Peer相关的用户实体时使用
for ORG in $ORGS; do
    initOrgVars $ORG
    # 从远程CA服务端获取CAChain证书
    fetchCAChain $ORG $CA_CHAINFILE
done

# 编译生成fabric-ca-client bin
#set +e
#which fabric-ca-client
#if [ $? -ne 0 ]; then
#    log "Compile to generate fabric-ca-client, This will take a few minutes, please wait patiently ..."
#    go get -u github.com/hyperledger/fabric-ca/cmd/...
#    if [ $? -ne 0 ]; then
#        log "Compile to generate fabric-ca-client failed"
#        exit 1
#    fi
#fi
#set -e

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

docker-compose up -d --no-deps setup

# 等待'setup'容器启动，随后tail -f
dowait "the docker 'setup' container to start" 60 ${SDIR}/${SETUP_LOGFILE} ${SDIR}/${SETUP_LOGFILE}

tail -f ${SDIR}/${SETUP_LOGFILE}&
TAIL_PID=$!
sleep 5
# 等待'setup'容器执行完成
while true; do
    if [ -f ${SDIR}/${SETUP_SUCCESS_FILE} ]; then
        kill -9 $TAIL_PID

        chmod -R 755 $PWD/$DATA/orgs

        # 等待所有orderers和peers节点启动
        waitAllOrderersAndPeers
        sleep 3

        # 启动'run'容器，执行创建应用通道、加入应用通道、更新锚节点、安装链码、实例化链码、查询调用链码等操作
        startRun

    elif [ -f ${SDIR}/${SETUP_FAIL_FILE} ]; then
        kill -9 $TAIL_PID
        exit 1
    else
        sleep 1
    fi
done