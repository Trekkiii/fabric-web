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
            # 根CA服务初始化时指定的用户名和密码，用于fabric-ca-server init -b
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
            # 中间层CA服务初始化时指定的用户名和密码，用于fabric-ca-server init -b -u
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
            - ./fabric.config:/fabric.config
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

    COUNT=1
    while [[ "$COUNT" -le $NUM_ZOOKEEPER ]]; do
        initZKVars $COUNT
        writeZK $COUNT $NUM_ZOOKEEPER
        COUNT=$((COUNT+1))
    done

    COUNT=1
    while [[ "$COUNT" -le $NUM_KAFKA ]]; do
        initKafkaVars $COUNT
        writeKafka $COUNT $NUM_KAFKA $NUM_ZOOKEEPER
        COUNT=$((COUNT+1))
    done

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
            writeCouchdb
            writePeer
            COUNT=$((COUNT+1))
        done
    done
}

# Zookeeper
function writeZK {

    ZK_ID=$1
    ZK_NUM=$2

    echo -n "    $ZK_NAME:
        container_name: $ZK_NAME
        image: hyperledger/fabric-zookeeper
        restart: always
        ports:
            - 2181:2181
            - 2888:2888
            - 3888:3888
        environment:
            - ZOO_MY_ID=$ZK_ID
            - ZOO_SERVERS="
    local COUNT=1
    while [[ "$COUNT" -le $ZK_NUM ]]; do
        initZKVars $COUNT
        if [[ "$COUNT" -eq $ZK_NUM ]]; then
            if [[ "$COUNT" -eq $ZK_ID ]]; then
                echo "server."$COUNT"=0.0.0.0:2888:3888"
            else
                echo "server."$COUNT"=$ZK_HOST:2888:3888"
            fi
        else
            if [[ "$COUNT" -eq $ZK_ID ]]; then
                echo -n "server."$COUNT"=0.0.0.0:2888:3888 "
            else
                echo -n "server."$COUNT"=$ZK_HOST:2888:3888 "
            fi
        fi
        COUNT=$((COUNT+1))
    done
    echo "        extra_hosts:"
    genZKHosts
    echo ""
}

# Kafka
function writeKafka {

    KAFKA_ID=$1
    KAFKA_NUM=$2
    ZK_NUM=$2

    echo -n "    $KAFKA_NAME:
        container_name: $KAFKA_NAME
        image: hyperledger/fabric-kafka
        restart: always
        hostname: $KAFKA_HOST
        ports:
            - 9092:9092
        environment:
            - KAFKA_MESSAGE_MAX_BYTES=103809024 # 99 * 1024 * 1024 B
            - KAFKA_REPLICA_FETCH_MAX_BYTES=103809024 # 99 * 1024 * 1024 B
            - KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE=false
            - KAFKA_BROKER_ID=$KAFKA_ID
            - KAFKA_MIN_INSYNC_REPLICAS=2
            - KAFKA_DEFAULT_REPLICATION_FACTOR=3
            - KAFKA_ZOOKEEPER_CONNECT="
    local COUNT=1
    while [[ "$COUNT" -le $ZK_NUM ]]; do
        initZKVars $COUNT
        if [[ "$COUNT" -eq $ZK_NUM ]]; then
            echo "$ZK_HOST:2181"
        else
            echo -n "$ZK_HOST:2181,"
        fi
        COUNT=$((COUNT+1))
    done
    echo "        depends_on:"
    COUNT=1
    while [[ "$COUNT" -le $ZK_NUM ]]; do
        initZKVars $COUNT
        echo "            - $ZK_NAME"
        COUNT=$((COUNT+1))
    done
    echo "        extra_hosts:"
    genZKHosts
    genKafkaHosts
    echo ""
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
            # 已通过fabric-ca-client register注册了Orderer节点身份
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
            # kafka
            - ORDERER_KAFKA_RETRY_SHORTINTERVAL=1s
            - ORDERER_KAFKA_RETRY_SHORTTOTAL=30s
            - ORDERER_KAFKA_VERBOSE=true
            - ORDERER_HOME=$MYHOME
            - ORDERER_HOST=$ORDERER_HOST
            - ORDERER_LOGFILE=$ORDERER_LOGFILE
            - ORDERER_SUCCESS_FILE=$ORDERER_SUCCESS_FILE
            - ORDERER_FAIL_FILE=$ORDERER_FAIL_FILE
            - ORG=$ORG
            - NUM=$NUM
            - ORG_ADMIN_CERT=$ORG_ADMIN_CERT
        command: /bin/bash -c '/scripts/start-orderer.sh 2>&1 | tee /$ORDERER_LOGFILE'
        volumes:
            - ./scripts:/scripts
            - ./$DATA:/$DATA
        depends_on:"
        COUNT=1
        while [[ "$COUNT" -le $ZK_NUM ]]; do
            initZKVars $COUNT
            echo "            - $ZK_NAME"
            COUNT=$((COUNT+1))
        done
        COUNT=1
        while [[ "$COUNT" -le $KAFKA_NUM ]]; do
            initKafkaVars $COUNT
            echo "            - $KAFKA_NAME"
            COUNT=$((COUNT+1))
        done
        echo "        ports:
            - 7050:7050
        extra_hosts:"
        genKafkaHosts
        genCAHosts
        genOrdererHosts
        genPeerHosts
        echo ""
}

function writeCouchdb {

    echo "    $PEER_COUCHDB_NAME:
        container_name: $PEER_COUCHDB_NAME
        image: hyperledger/fabric-couchdb
        # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
        # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
        environment:
            - COUCHDB_USER=
            - COUCHDB_PASSWORD=
        # Comment/Uncomment the port mapping if you want to hide/expose the CouchDB service,
        # for example map it to utilize Fauxton User Interface in dev environments.
        ports:
            - 5984:5984"
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
            # 已通过fabric-ca-client register注册了Peer节点身份
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
            # couchdb
            - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
            - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$PEER_COUCHDB_HOST:5984
            # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
            # provide the credentials for ledger to connect to CouchDB.  The username and password must
            # match the username and password set for the associated CouchDB.
            - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=
            - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=
            - PEER_NAME=$PEER_NAME
            - PEER_HOME=$MYHOME
            - PEER_HOST=$PEER_HOST
            - PEER_NAME_PASS=$PEER_NAME_PASS
            - PEER_LOGFILE=$PEER_LOGFILE
            - PEER_SUCCESS_FILE=$PEER_SUCCESS_FILE
            - PEER_FAIL_FILE=$PEER_FAIL_FILE
            - ORG=$ORG
            - NUM=$NUM
            - ORG_ADMIN_CERT=$ORG_ADMIN_CERT"
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
            - $PEER_COUCHDB_NAME
        ports:
            - 7051:7051
            - 7052:7052
            - 7053:7053
        extra_hosts:"
        genCouchdbHosts
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

# 编写一个cli，用于新加入组织
function writeCliFabric {

    MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer

    # 进入fabric-ca目录，并设置fabric-web目录路径
    WEB_DIR=$(dirname $(cd ${SDIR} && pwd))

    echo "    cli:
        container_name: cli
        image: hyperledger/fabric-ca-tools
        tty: true
        stdin_open: true
        environment:
            - GOPATH=/opt/gopath
        command: /bin/bash
        working_dir: $MYHOME
        volumes:
            - ./fabric.config:$MYHOME/fabric.config
            - ./scripts:/scripts
            - ./$DATA:/$DATA
            - ./$DATA/channel-artifacts:/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts
            - ${WEB_DIR}:/opt/gopath/src/github.com/hyperledger/fabric-web"
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

function genZKHosts {
    COUNT=1
    while [[ "$COUNT" -le $NUM_ZOOKEEPER ]]; do
        initZKVars $COUNT
        echo "            - \"${ZK_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.ZOOKEEPER_CLUSTER['$((COUNT-1))'].IP')"\""
        COUNT=$((COUNT+1))
    done
}

function genKafkaHosts {
    COUNT=1
    while [[ "$COUNT" -le $NUM_KAFKA ]]; do
        initKafkaVars $COUNT
        echo "            - \"${KAFKA_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].IP')"\""
        COUNT=$((COUNT+1))
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

function genCouchdbHosts {

    echo "            - \"${PEER_COUCHDB_HOST}:"$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.PEERS['$((COUNT-1))'].COUCHDB_IP')"\""
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

function extend {

    {
    # 编写header
    writeHeader

    # 为新组织对应的根Fabric CA服务器编写服务
    # 每一个组织一个根CA服务器
    initOrgVars $NEW_ORG
    writeRootCA

    # 使用中间层CA
    if $USE_INTERMEDIATE_CA; then
        # 为新组织对应的中间层Fabric CA服务器编写服务
        # 每一个组织一个中间层CA服务器
        initOrgVars $NEW_ORG
        writeIntermediateCA
    fi

    # 编写peer容器服务
    COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        initPeerVars $NEW_ORG $COUNT
        writeCouchdb
        writePeer
        COUNT=$((COUNT+1))
    done

    # 编写一个cli，用于新加入组织
    writeCliFabric
    } > $SDIR/docker-compose.yml
   log "Created docker-compose.yml"
}

IS_EXTEND=false

while getopts "e" opt; do
    case "$opt" in
        e)
            IS_EXTEND=true
            shift

            NEW_ORG=$1
            if [ ! -z "$2" ]; then
                NUM_PEERS=$2
                # 对NUM_PEERS类型进行校验
                expr $NUM_PEERS + 0 >& /dev/null
                if [ $? -ne 0 ]; then
                    fatal "NUM_PEERS is not integer."
                fi
            fi
            ;;
    esac
done

SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

installJQ
# 校验fabric.config配置是否是合法性JSON
cat fabric.config | jq . >& /dev/null
if [ $? -ne 0 ]; then
	fatal "fabric.config isn't JSON format"
fi

if [ "$IS_EXTEND" == "true" ]; then
    if [ -z "$NEW_ORG" ]; then
        fatal "Usage: ./makeDocker.sh [-e] <NEW_ORG> [NUM_PEERS]"
    fi
    extend
else
    main
fi