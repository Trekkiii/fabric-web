#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 该脚本构造运行fabric所需的docker-compose.yaml文件
function writeHeader {
   echo "version: '2'

services:
"
}

function writeRootCA {

    echo "    $ROOT_CA_NAME: # 根CA服务名称
        container_name: $ROOT_CA_NAME
        image: hyperledger/fabric-ca
        command: /bin/bash -c '/scripts/start-root-ca.sh 2>&1 | tee /$ROOT_CA_LOGFILE' # tee命令用于将数据重定向到文件，另一方面还可以提供一份重定向数据的副本作为后续命令的stdin。简单的说就是把数据重定向到给定文件和屏幕上。
        environment:
            # 主配置目录
            - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
            # 是否启用TLS，默认为false
            - FABRIC_CA_SERVER_TLS_ENABLED=true
            # CA自身证书的申请请求配置
            - FABRIC_CA_SERVER_CSR_CN=$ROOT_CA_NAME
            - FABRIC_CA_SERVER_CSR_HOSTS=$ROOT_CA_HOST
            - FABRIC_CA_SERVER_DEBUG=true
            # ---------------------自定义配置---------------------
            # 根CA服务初始化时指定的用户名和密码，用于<fabric-ca-server init -b>
            - BOOTSTRAP_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
            # 根CA的签名证书($FABRIC_CA_SERVER_HOME/ca-cert.pem)的一份copy(/${DATA}/${ORG}-ca-cert.pem)
            - TARGET_CERTFILE=$ROOT_CA_CERTFILE
            - ROOT_CA_LOGFILE=$ROOT_CA_LOGFILE
            # 'rca'容器容器成功和失败的日志文件
            - ROOT_CA_SUCCESS_FILE=$ROOT_CA_SUCCESS_FILE
            - ROOT_CA_FAIL_FILE=$ROOT_CA_FAIL_FILE
            - ORG=$ORG
            # 用于组织结构配置：affiliation
            - FABRIC_ORGS="$ORGS"
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
        ports:
            - 7054:7054
    "
}

# 为中间层fabric CA服务器编写服务
function writeIntermediateFabricCA {
   for ORG in $ORGS; do
      initOrgVars $ORG
      writeIntermediateCA
   done
}

function writeIntermediateCA {

    echo "    $INT_CA_NAME: # 中间层CA服务名称
        container_name: $INT_CA_NAME
        image: hyperledger/fabric-ca
        command: /bin/bash -c '/scripts/start-intermediate-ca.sh $ORG 2>&1 | tee /$INT_CA_LOGFILE'
        environment:
            # 主配置目录
            - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
            # CA 服务名称
            - FABRIC_CA_SERVER_CA_NAME=$INT_CA_NAME
            # intermediate.tls.certfiles 信任的根CA证书
            - FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$ROOT_CA_CERTFILE
            # CA自身证书的申请请求配置
            # Initialization failure: CN 'ica-org0' cannot be specified for an intermediate CA. Remove CN from CSR section for enrollment of intermediate CA to be successful
            # - FABRIC_CA_SERVER_CSR_CN=$INT_CA_NAME
            - FABRIC_CA_SERVER_CSR_HOSTS=$INT_CA_HOST
            # 是否启用TLS，默认为false
            - FABRIC_CA_SERVER_TLS_ENABLED=true
            - FABRIC_CA_SERVER_DEBUG=true
            # ---------------------自定义配置---------------------
            # 中间层CA服务初始化时指定的用户名和密码，用于<fabric-ca-server init -b -u>
            - BOOTSTRAP_USER_PASS=$INT_CA_ADMIN_USER_PASS
            # 父fabric-ca-server服务地址
            - PARENT_URL=https://$ROOT_CA_ADMIN_USER_PASS@$ROOT_CA_HOST:7054
            # 中间层CA的证书chain($FABRIC_CA_SERVER_HOME/ca-chain.pem)的一份copy(/${DATA}/${ORG}-ca-chain.pem)
            - TARGET_CHAINFILE=$INT_CA_CHAINFILE
            - INT_CA_LOGFILE=$INT_CA_LOGFILE
            - INT_CA_SUCCESS_FILE=$INT_CA_SUCCESS_FILE
            - INT_CA_FAIL_FILE=$INT_CA_FAIL_FILE
            - ORG=$ORG
            - FABRIC_ORGS="$ORGS"
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
        depends_on:
            - $ROOT_CA_NAME
        ports:
            - 7054:7054
        extra_hosts:"
        genCAHosts
        genOrdererHosts
        genPeerHosts
        echo ""
}

# 编写服务，用于生成fabric artifacts（如，创世区块）
function writeSetupFabric {

    echo "    setup:
        container_name: setup
        image: hyperledger/fabric-ca-tools
        command: /bin/bash -c '/scripts/setup-fabric.sh 2>&1 | tee /$SETUP_LOGFILE; sleep 99999'
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
        depends_on:"
        for ORG in $ORGS; do
            initOrgVars $ORG
            echo "            - $CA_NAME"
        done
        echo "        extra_hosts:"
        genCAHosts
        genOrdererHosts
        genPeerHosts
        echo ""
}

# 为根fabric CA服务器编写服务
function writeRootFabricCA {

    for ORG in $ORGS; do
        initOrgVars $ORG
        writeRootCA
    done
}

# 为每一个orderer和peer容器编写服务
function writeStartFabric {

    for ORG in $ORDERER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT
            writeOrderer
            COUNT=$((COUNT+1))
        done
    done

    for ORG in $PEER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            writePeer
            COUNT=$((COUNT+1))
        done
    done
}

# Orderer容器服务
function writeOrderer {

    MYHOME=/etc/hyperledger/orderer

    echo "    $ORDERER_NAME:
        container_name: $ORDERER_NAME
        image: hyperledger/fabric-ca-orderer
        environment:
            - FABRIC_CA_CLIENT_HOME=$MYHOME
            - FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
            # 已通过<fabric-ca-client register>注册了Orderer节点身份
            - ENROLLMENT_URL=https://$ORDERER_NAME_PASS@$CA_HOST:7054
            - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
            - ORDERER_GENERAL_GENESISMETHOD=file
            - ORDERER_GENERAL_GENESISFILE=$GENESIS_BLOCK_FILE
            - ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
            - ORDERER_GENERAL_LOCALMSPDIR=$MYHOME/msp # 指定orderer节点身份MSP
            # 开启TLS时的相关配置
            - ORDERER_GENERAL_TLS_ENABLED=true
            - ORDERER_GENERAL_TLS_PRIVATEKEY=$MYHOME/tls/server.key # Orderer tls签名私钥
            - ORDERER_GENERAL_TLS_CERTIFICATE=$MYHOME/tls/server.crt # Orderer tls身份证书
            - ORDERER_GENERAL_TLS_ROOTCAS=[$CA_CHAINFILE] # 信任的根证书
            - ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true # 是否对客户端也进行认证
            - ORDERER_GENERAL_TLS_CLIENTROOTCAS=[$CA_CHAINFILE]
            - ORDERER_GENERAL_LOGLEVEL=debug
            - ORDERER_DEBUG_BROADCASTTRACEDIR=$LOGDIR
            - ORDERER_HOME=$MYHOME
            - ORDERER_HOST=$ORDERER_HOST
            - ORDERER_LOGFILE=$ORDERER_LOGFILE
            - ORDERER_SUCCESS_FILE=$ORDERER_SUCCESS_FILE
            - ORDERER_FAIL_FILE=$ORDERER_FAIL_FILE
            - ORG=$ORG
            - ORG_ADMIN_CERT=$ORG_ADMIN_CERT # 组织管理员身份证书 /${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
        command: /bin/bash -c '/scripts/start-orderer.sh 2>&1 | tee /$ORDERER_LOGFILE'
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
        depends_on:
            - setup
        ports:
            - 7050:7050
        extra_hosts:"
        genCAHosts
        genOrdererHosts
        genPeerHosts
        echo ""
}

# Peer容器服务
function writePeer {

    MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer

    echo "    $PEER_NAME:
        container_name: $PEER_NAME
        image: hyperledger/fabric-ca-peer
        environment:
            - FABRIC_CA_CLIENT_HOME=$MYHOME
            - FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
            # 已通过<fabric-ca-client register>注册了Peer节点身份
            - ENROLLMENT_URL=https://$PEER_NAME_PASS@$CA_HOST:7054
            - CORE_PEER_ID=$PEER_HOST
            - CORE_PEER_ADDRESS=$PEER_HOST:7051
            - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
            - CORE_PEER_LOCALMSPID=$ORG_MSP_ID
            - CORE_PEER_MSPCONFIGPATH=$MYHOME/msp
            - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
            - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=host
            - CORE_LOGGING_LEVEL=DEBUG
            - CORE_CHAINCODE_DEPLOYTIMEOUT=300s
            - CORE_CHAINCODE_STARTUPTIMEOUT=300s
            # 开启TLS时的相关配置
            - CORE_PEER_TLS_ENABLED=true
            - CORE_PEER_TLS_KEY_FILE=$MYHOME/tls/server.key # peer签名私钥
            - CORE_PEER_TLS_CERT_FILE=$MYHOME/tls/server.crt # peer身份验证证书
            - CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE # 信任的根证书
            - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
            - CORE_PEER_TLS_CLIENTROOTCAS_FILES=$CA_CHAINFILE
            - CORE_PEER_TLS_CLIENTCERT_FILE=/$DATA/tls/$PEER_NAME-client.crt
            - CORE_PEER_TLS_CLIENTKEY_FILE=/$DATA/tls/$PEER_NAME-client.key
            - CORE_PEER_GOSSIP_USELEADERELECTION=true
            - CORE_PEER_GOSSIP_ORGLEADER=false
            - CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051 # 节点被组织外节点感知时的地址
            - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
            - PEER_NAME=$PEER_NAME
            - PEER_HOME=$MYHOME
            - PEER_HOST=$PEER_HOST
            - PEER_NAME_PASS=$PEER_NAME_PASS
            - PEER_LOGFILE=$PEER_LOGFILE
            - PEER_SUCCESS_FILE=$PEER_SUCCESS_FILE
            - PEER_FAIL_FILE=$PEER_FAIL_FILE
            - ORG=$ORG
            - ORG_ADMIN_CERT=$ORG_ADMIN_CERT" # 组织管理员身份证书 /${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
    if [ $NUM -gt 1 ]; then
        # 启动节点后向哪些节点发起gossip连接，以加入网络。这些节点与本地节点需要属于同一组织
        echo "            - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051"
    fi
    echo "        working_dir: $MYHOME
        command: /bin/bash -c '/scripts/start-peer.sh 2>&1 | tee /$PEER_LOGFILE'
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
            - /var/run:/host/var/run
        depends_on:
            - setup
        ports:
            - 7051:7051
            - 7052:7052
            - 7053:7053
        extra_hosts:"
        genCAHosts
        genOrdererHosts
        genPeerHosts
        echo ""
}

# 编写一个服务来运行fabric测试，包括创建一个通道，安装、调用和查询链码
function writeRunFabric {

    # 进入fabric-ca目录，并设置fabric-web目录路径
    WEB_DIR=$(dirname $(cd ${SDIR} && pwd))

    # 设置fabric目录
    FABRIC_DIR=${GOPATH}/src/github.com/hyperledger/fabric

    echo "    run:
        container_name: run
        image: hyperledger/fabric-ca-tools
        environment:
            - GOPATH=/opt/gopath
        command: /bin/bash -c 'sleep 3;/scripts/run-fabric.sh 2>&1 | tee /$RUN_LOGFILE; sleep 99999'
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
            - ${WEB_DIR}:/opt/gopath/src/github.com/hyperledger/fabric-web
            - ${FABRIC_DIR}:/opt/gopath/src/github.com/hyperledger/fabric
        depends_on:"
        for ORG in $ORDERER_ORGS; do
            COUNT=1
            while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
                initOrdererVars $ORG $COUNT
                echo "            - $ORDERER_NAME"
                COUNT=$((COUNT+1))
            done
        done
        for ORG in $PEER_ORGS; do
            COUNT=1
            while [[ "$COUNT" -le $NUM_PEERS ]]; do
                initPeerVars $ORG $COUNT
                echo "            - $PEER_NAME"
                COUNT=$((COUNT+1))
            done
        done
        echo "        extra_hosts:"
        genCAHosts
        genOrdererHosts
        genPeerHosts
        echo ""
}

function genCAHosts {
    local ORG
    for ORG in $ORGS; do
        initOrgVars $ORG
        if $USE_INTERMEDIATE_CA; then
            echo "            - \"${INT_CA_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')"\""
        fi
        echo "            - \"${ROOT_CA_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')"\""
    done
}

function genOrdererHosts {
    local ORG
    for ORG in $ORDERER_ORGS; do
        local COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT
            echo "            - \"${ORDERER_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ORDERERS['$((COUNT-1))'].IP')"\""
            COUNT=$((COUNT+1))
        done
    done
}

function genPeerHosts {
    local ORG
    for ORG in $PEER_ORGS; do
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            echo "            - \"${PEER_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].IP')"\""
            COUNT=$((COUNT+1))
        done
    done
}

function main {

    installJQ

    {
    # 编写header
    writeHeader

    # 为根Fabric CA服务器编写服务
    # 每一个组织一个根CA服务器
    writeRootFabricCA

    # 使用中间层CA
    if $USE_INTERMEDIATE_CA; then
        # 为中间层Fabric CA服务器编写服务
        # 每一个组织一个中间层CA服务器
        writeIntermediateFabricCA
    fi

    # 编写一个服务来设置fabric artifacts（例如，创世区块等）
    writeSetupFabric

    # 编写orderer 和 peer容器服务
    writeStartFabric

    # 编写一个服务来运行fabric测试，包括创建一个通道，安装、调用和查询链码
    writeRunFabric
    } > $SDIR/docker-compose.yml
   log "Created docker-compose.yml"
}

SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

main