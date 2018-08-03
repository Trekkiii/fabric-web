#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0

FABRIC_ROOT=$GOPATH/src/github.com/hyperledger/fabric

# zookeeper集群节点数量
NUM_ZOOKEEPER=NUM_ZOOKEEPER_PLACEHOLDER

# kafka集群节点数量
NUM_KAFKA=NUM_KAFKA_PLACEHOLDER

# orderer组织的名称
ORDERER_ORGS=ORDERER_ORGS_PLACEHOLDER

# peer组织的名称
PEER_ORGS=PEER_ORGS_PLACEHOLDER

# 每一个peer组织的peers数量
NUM_PEERS=NUM_PEERS_PLACEHOLDER

# 每一个orderer组织的orderer节点的数量
NUM_ORDERERS=NUM_ORDERERS_PLACEHOLDER

# 所有组织名称
ORGS="$ORDERER_ORGS $PEER_ORGS"

# 如果ADMINCERTS为true，我们需要登记组织管理员并将证书保存到msp目录下的admincerts文件夹下
ADMINCERTS=true

# 挂载的DATA目录
DATA=data

# 创世区块的路径
GENESIS_BLOCK_FILE=/$DATA/genesis.block

# 应用通道配置交易文件的路径
CHANNEL_TX_FILE=/$DATA/channel.tx

# 应用通道的名称
CHANNEL_NAME=mychannel

# 使用golang作为链码的开发语言
LANGUAGE=golang
# tr [OPTION]... SET1 [SET2]，将SET1中字符用SET2对应位置的字符进行替换
# tr [:upper:] [:lower:]，将大写转为小写
# -t, –truncate-set1 先删除第一字符集较第二字符集多出的字符
# echo "a1213fdasf" | tr -t "afd123" "AFO"    ->  A1213FOAsF
# echo "a1213fdasf" | tr "afd123" "AFO"     ->    AOOOOFOAsF
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`

# 查询超时，单位秒
QUERY_TIMEOUT=15

# 'setup'容器的超时，单位秒
SETUP_TIMEOUT=120

# Log日志目录
LOGDIR=$DATA/logs # 默认 data/logs
LOGPATH=/$LOGDIR # 默认 /data/logs

# 'setup'容器的日志文件
SETUP_LOGFILE=${LOGDIR}/setup.log
# 'run'容器成功和失败的日志文件
SETUP_SUCCESS_FILE=${LOGDIR}/setup.success
SETUP_FAIL_FILE=${LOGDIR}/setup.fail

# 'run'容器的日志文件
RUN_LOGFILE=${LOGDIR}/run.log
# 'run'容器的摘要日志文件
RUN_SUMFILE=${LOGDIR}/run.sum
RUN_SUMPATH=/${RUN_SUMFILE}
# 'run'容器成功和失败的日志文件
RUN_SUCCESS_FILE=${LOGDIR}/run.success
RUN_FAIL_FILE=${LOGDIR}/run.fail

# 启用中间层CA证书
USE_INTERMEDIATE_CA=true

# 配置区块文件
CONFIG_BLOCK_FILE=/tmp/config_block.pb

# 配置更新交易文件
CONFIG_UPDATE_ENVELOPE_FILE=/tmp/config_update_as_envelope.pb

# current version of fabric images released
export VERSION=1.1.0
# current version of fabric-ca images released
export CA_VERSION=$VERSION
# current version of thirdparty images (couchdb, kafka and zookeeper) released
export THIRDPARTY_IMAGE_VERSION=0.4.6

export ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
MARCH=`uname -m` # Set MARCH variable i.e ppc64le,s390x,x86_64,i386

: ${CA_TAG:="$MARCH-$CA_VERSION"}
: ${FABRIC_TAG:="$MARCH-$VERSION"}
: ${THIRDPARTY_TAG:="$MARCH-$THIRDPARTY_IMAGE_VERSION"}

BINARY_FILE=hyperledger-fabric-${ARCH}-${VERSION}.tar.gz
CA_BINARY_FILE=hyperledger-fabric-ca-${ARCH}-${CA_VERSION}.tar.gz

# 删除所有fabric相关的容器
function removeFabricContainers {

    if [ $# -ne 1 ]; then
        echo "Usage: removeFabricContainersh <container>"
        exit 1
    fi

    container=$1

    dockerContainers=$(docker ps -a | awk '$NF~/'${container}'/ {print $1}')
    if [ "$dockerContainers" != "" ]; then
        log "Deleting existing docker containers with images ${container} ..."
        docker rm -f $dockerContainers > /dev/null
    fi
}

# 删除链码容器和镜像
function removeChaincode {

    # 删除链码容器
    chaincodeContainers=$(docker ps -a | awk '$2~/dev-peer/ {print $1}')
    if [ "$chaincodeContainers" != "" ]; then
        log "Deleting existing chaincode containers ..."
        docker rm -f $chaincodeContainers > /dev/null
    fi

    # 删除链码镜像
    chaincodeImages=`docker images | grep "^dev-peer" | awk '{print $3}'`
    if [ "$chaincodeImages" != "" ]; then
       log "Removing chaincode docker images ..."
       docker rmi -f $chaincodeImages > /dev/null
    fi
}

# 刷新DATA区域
function refreshData {

    # 删除data目录
    DDIR=${SDIR}/${DATA}
    if [ -d ${DDIR} ]; then
       log "Cleaning up the data directory from previous run at $DDIR"
       rm -rf ${DDIR}
    fi
    # 创建.../data/logs
    mkdir -p ${DDIR}/logs
}

# initOrgVars <ORG>
function initOrgVars {

    if [ $# -ne 1 ]; then
        echo "Usage: initOrgVars <ORG>"
        exit 1
    fi

    local ORG=$1

    export FABRIC_CA_CLIENT_ID_AFFILIATION=$ORG

    ORG_CONTAINER_NAME=${ORG//./-}
    # 组织管理员，通过CA注册
    ADMIN_NAME=admin-${ORG}
    ADMIN_PASS=${ADMIN_NAME}pw
    # 组织的普通用户，用于peer组织向CA注册普通用户身份
    USER_NAME=user-${ORG}
    USER_PASS=${USER_NAME}pw
    # MSP
    ORG_MSP_ID=${ORG}MSP
    ORG_MSP_DIR=/${DATA}/orgs/${ORG}/msp
#    ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/cert.pem # /${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
    ORG_ADMIN_HOME=/${DATA}/orgs/${ORG}/admin
    ORG_ADMIN_CERT=${ORG_ADMIN_HOME}/msp/signcerts/cert.pem

    # 根CA
    ROOT_CA_HOST=rca-${ORG}
    ROOT_CA_NAME=rca-${ORG}
    ROOT_CA_LOGFILE=$LOGDIR/${ROOT_CA_NAME}.log
    # 'rca'容器容器成功和失败的日志文件
    ROOT_CA_SUCCESS_FILE=$LOGDIR/${ROOT_CA_NAME}.success
    ROOT_CA_FAIL_FILE=$LOGDIR/${ROOT_CA_NAME}.fail
    # 根CA管理员
    ROOT_CA_ADMIN_USER=rca-${ORG}-admin
    ROOT_CA_ADMIN_PASS=${ROOT_CA_ADMIN_USER}pw
    # 根CA服务初始化时指定的用户名和密码，用于<fabric-ca-server init -b>
    ROOT_CA_ADMIN_USER_PASS=${ROOT_CA_ADMIN_USER}:${ROOT_CA_ADMIN_PASS}

    # 中间层CA
    INT_CA_HOST=ica-${ORG}
    INT_CA_NAME=ica-${ORG}
    INT_CA_LOGFILE=$LOGDIR/${INT_CA_NAME}.log
    INT_CA_SUCCESS_FILE=$LOGDIR/${INT_CA_NAME}.success
    INT_CA_FAIL_FILE=$LOGDIR/${INT_CA_NAME}.fail
    # 中间层CA管理员
    INT_CA_ADMIN_USER=ica-${ORG}-admin
    INT_CA_ADMIN_PASS=${INT_CA_ADMIN_USER}pw
    # 中间层CA服务初始化时指定的用户名和密码，用于<fabric-ca-server init -b -u>
    INT_CA_ADMIN_USER_PASS=${INT_CA_ADMIN_USER}:${INT_CA_ADMIN_PASS}

    # CA根证书
    ROOT_CA_CERTFILE=/${DATA}/${ORG}-ca-cert.pem
    INT_CA_CHAINFILE=/${DATA}/${ORG}-ca-chain.pem

    # 锚节点配置更新交易文件
    ANCHOR_TX_FILE=/${DATA}/${ORG}-anchors.tx

    if test "$USE_INTERMEDIATE_CA" = "true"; then
        CA_NAME=$INT_CA_NAME
        CA_HOST=$INT_CA_HOST
        CA_CHAINFILE=$INT_CA_CHAINFILE
        CA_ADMIN_USER_PASS=$INT_CA_ADMIN_USER_PASS
        CA_LOGFILE=$INT_CA_LOGFILE
    else
        CA_NAME=$ROOT_CA_NAME
        CA_HOST=$ROOT_CA_HOST
        CA_CHAINFILE=$ROOT_CA_CERTFILE
        CA_ADMIN_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
        CA_LOGFILE=$ROOT_CA_LOGFILE
    fi
}

function initZKVars {

    if [ $# -ne 1 ]; then
        echo "Usage: initZKVars <ID>"
        exit 1
    fi

    ZK_HOST=zookeeper$1
    ZK_NAME=zookeeper$1
}

function initKafkaVars {

    if [ $# -ne 1 ]; then
        echo "Usage: initKafkaVars <ID>"
        exit 1
    fi

    KAFKA_ID=$1

    KAFKA_HOST=kafka${KAFKA_ID}
    KAFKA_NAME=kafka${KAFKA_ID}
}

# initOrdererVars <ORG> <NUM>
function initOrdererVars {

    if [ $# -ne 2 ]; then
        echo "Usage: initOrdererVars <ORG> <NUM>"
        exit 1
    fi

    initOrgVars $1
    ORG=$1
    NUM=$2

    ORDERER_HOST=orderer${NUM}-${ORG}
    ORDERER_NAME=orderer${NUM}-${ORG}
    ORDERER_PASS=${ORDERER_NAME}pw
    ORDERER_NAME_PASS=${ORDERER_NAME}:${ORDERER_PASS}
    ORDERER_LOGFILE=$LOGDIR/${ORDERER_NAME}.log
    ORDERER_SUCCESS_FILE=$LOGDIR/${ORDERER_NAME}.success
    ORDERER_FAIL_FILE=$LOGDIR/${ORDERER_NAME}.fail

    MYHOME=/etc/hyperledger/orderer
    TLSDIR=$MYHOME/tls

    export FABRIC_CA_CLIENT=$MYHOME

    export ORDERER_GENERAL_LOGLEVEL=debug
    export ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
    export ORDERER_GENERAL_GENESISMETHOD=file
    export ORDERER_GENERAL_GENESISFILE=$GENESIS_BLOCK_FILE
    export ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
    export ORDERER_GENERAL_LOCALMSPDIR=$MYHOME/msp

    # enabled TLS
    export ORDERER_GENERAL_TLS_ENABLED=true
    # TLS开启时指定orderer签名私钥位置
    # /etc/hyperledger/orderer/tls/server.key
    export ORDERER_GENERAL_TLS_PRIVATEKEY=$TLSDIR/server.key
    # TLS开启时指定orderer身份证书位置
    # /etc/hyperledger/orderer/tls/server.crt
    export ORDERER_GENERAL_TLS_CERTIFICATE=$TLSDIR/server.crt
    export ORDERER_GENERAL_TLS_ROOTCAS=[$CA_CHAINFILE] # TLS开启时指定信任的根CA证书位置
}

# initPeerVars <ORG> <NUM>
function initPeerVars {

    if [ $# -ne 2 ]; then
        echo "Usage: initPeerVars <ORG> <NUM>: $*"
        exit 1
    fi

    initOrgVars $1
    ORG=$1
    NUM=$2

    PEER_HOST=peer${NUM}-${ORG}
    PEER_NAME=peer${NUM}-${ORG}
    PEER_PASS=${PEER_NAME}pw
    PEER_NAME_PASS=${PEER_NAME}:${PEER_PASS}
    PEER_LOGFILE=$LOGDIR/${PEER_NAME}.log
    PEER_SUCCESS_FILE=$LOGDIR/${PEER_NAME}.success
    PEER_FAIL_FILE=$LOGDIR/${PEER_NAME}.fail

    PEER_COUCHDB_NAME=couchdb${NUM}-${ORG}
    PEER_COUCHDB_HOST=couchdb${NUM}-${ORG}

    MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer
    TLSDIR=$MYHOME/tls

    export FABRIC_CA_CLIENT=$MYHOME

    export CORE_PEER_ID=$PEER_HOST
    export CORE_PEER_ADDRESS=$PEER_HOST:7051
    export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
    export CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
    # the following setting starts chaincode containers on the same
    # bridge network as the peers
    # https://docs.docker.com/compose/networking/
    # export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_${NETWORK}
    export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=host
    # export CORE_LOGGING_LEVEL=ERROR
    export CORE_LOGGING_LEVEL=DEBUG

    # enabled TLS
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE # TLS开启时指定信任的根CA证书位置
    export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true # 是否启用客户端验证
    export CORE_PEER_TLS_CLIENTCERT_FILE=/$DATA/tls/$PEER_NAME-client.crt # Peer节点的PEM编码的X509公钥文件(代表peer用户身份)，用于客户端验证
    export CORE_PEER_TLS_CLIENTKEY_FILE=/$DATA/tls/$PEER_NAME-client.key # Peer节点的PEM编码的私钥文件(代表peer用户身份)，用于客户端验证
    export CORE_PEER_PROFILE_ENABLED=true
    # gossip variables
    export CORE_PEER_GOSSIP_USELEADERELECTION=true
    export CORE_PEER_GOSSIP_ORGLEADER=false
    export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051 # 节点被组织外节点感知时的地址
    if [ $NUM -gt 1 ]; then
        # 启动节点后向哪些节点发起gossip连接，以加入网络。这些节点与本地节点需要属于同一组织。
        export CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051
    fi

    # 连接Orderer端点的连接属性
    #       -o, --orderer string    Orderer服务地址
    #       --tls    在与Orderer端点通信时使用TLS
    #       --cafile string     Orderer节点的TLS证书，PEM格式编码，启用TLS时有效
    #       --clientauth    是否启用客户端验证
    #       --certfile string    Peer节点的PEM编码的X509公钥文件(代表peer用户身份)，用于客户端验证
    #       --keyfile string    Peer节点的PEM编码的私钥文件(代表peer用户身份)，用于客户端验证
    export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

# 如果传入的msp目录下的tls相关证书目录不存在的话，则创建它们
function finishMSPSetup {

    if [ $# -ne 1 ]; then
        fatal "Usage: finishMSPSetup <target_msp_dir>"
    fi

    # $1 传入的msp目录
    if [ ! -d $1/tlscacerts ]; then
        mkdir $1/tlscacerts
        cp $1/cacerts/* $1/tlscacerts
        if [ -d $1/intermediatecerts ]; then
            mkdir $1/tlsintermediatecerts
            cp $1/intermediatecerts/* $1/tlsintermediatecerts
        fi
    fi
}

# 用于peer节点!!!(CORE_PEER_MSPCONFIGPATH is just for Peer)
# 1. 切换到peer组织的管理员身份；
# 2. 如果之前没有登记，则登记，
#   2.1 保存登记时生成的身份证书至/${DATA}/orgs/${ORG}/admin目录下；
#       会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
#   2.2 将/${DATA}/orgs/${ORG}/admin/msp/signcerts/下的证书拷贝为/${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
#   2.3 将/${DATA}/orgs/${ORG}/admin/msp/signcerts/下的证书拷贝为/${DATA}/orgs/${ORG}/admin/msp/admincerts/cert.pem
function switchToAdminIdentity {

    # 1. 切换到peer组织的管理员身份
    export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp # /${DATA}/orgs/${ORG}/admin/msp

    # 2. 登记管理员身份获取证书
    getAdminCert $ORG_ADMIN_HOME $ORG_MSP_DIR
}

# 切换到peer组织的普通用户身份，如果之前没有登记，则登记。
function switchToUserIdentity {

    # fabric-ca-client主配置目录
    # fabric-ca-client会在该目录下搜索配置文件，
    # 同样，也会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
    export FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric/orgs/$ORG/user
    # 切换到peer组织的普通用户身份
    export CORE_PEER_MSPCONFIGPATH=$FABRIC_CA_CLIENT_HOME/msp

    # 登记普通用户身份获取证书
    getUserCert
}

# 当启用ADMINCERTS时，将组织的管理员证书拷贝到targetAdminDir目录
# targetAdminDir：
#       对于orderer节点：/etc/hyperledger/orderer/msp/admincerts
#       对于peer节点：/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/admincerts
function copyAdminCert {

    if [ $# -ne 1 ]; then
        fatal "Usage: copyAdminCert <TARGET_MSP_DIR>"
    fi

    if $ADMINCERTS; then
        targetAdminDir=$1/admincerts
        mkdir -p $targetAdminDir
        # ORG_ADMIN_CERT=/${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
        # targetAdminDir：
        #       对于orderer节点：/etc/hyperledger/orderer/msp/admincerts
        #       对于peer节点：/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/admincerts
        dowait "$ORG administator to enroll" 60 $SETUP_LOGFILE $ORG_ADMIN_CERT
        cp $ORG_ADMIN_CERT $targetAdminDir
    fi
}

# 获取组织管理员身份证书。如果存在，则不再登记，否则登记组织管理员身份
#   1. 保存登记时生成的身份证书至<LOCAL_ADMIN_DIR>目录下；
#       会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
#   2. 将<LOCAL_ADMIN_DIR>/msp/signcerts/cert.pem证书拷贝为<LOCAL_MSP_DIR>/admincerts/cert.pem
#   3. 将<LOCAL_ADMIN_DIR>/msp/signcerts/cert.pem证书拷贝为<LOCAL_ADMIN_DIR>/msp/admincerts/cert.pem
function getAdminCert {

    if [ $# -ne 2 ]; then
        echo "Usage: getAdminCert <LOCAL_ADMIN_DIR> <LOCAL_MSP_DIR>: $*"
        exit 1
    fi

    LOCAL_ADMIN_DIR=$1
    LOCAL_MSP_DIR=$2

    # 如果之前没有登记，则登记
    if [ ! -d $LOCAL_ADMIN_DIR ]; then

        # 等待将CA服务端初始化生成的根证书拷贝为CA_CHAINFILE文件
        # 即校验本地CA_CHAINFILE证书文件是否存在
        dowait "$CA_NAME to start" 60 $CA_LOGFILE $CA_CHAINFILE

        log "Enrolling admin '$ADMIN_NAME' with $CA_HOST ..."

        # fabric-ca-client主配置目录
        # fabric-ca-client会在该目录下搜索配置文件，
        # 同样，也会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
        export FABRIC_CA_CLIENT_HOME=$LOCAL_ADMIN_DIR

        # 而对于orderer、peer节点，在其docker-compose.yaml中的service.xxx.environment中已经定义FABRIC_CA_CLIENT_TLS_CERTFILES环境变量
        export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

        # 登记组织管理员身份
        fabric-ca-client enroll -d -u https://$ADMIN_NAME:$ADMIN_PASS@$CA_HOST:7054

        # 将 <LOCAL_ADMIN_DIR>/msp/signcerts/ 下的证书拷贝为:
        #       <LOCAL_MSP_DIR>/admincerts/cert.pem
        #       <LOCAL_ADMIN_DIR>/msp/admincerts/cert.pem
        if [ $ADMINCERTS ]; then

            mkdir -p $LOCAL_MSP_DIR/admincerts # <LOCAL_MSP_DIR>/admincerts

            # 2.2 将<LOCAL_ADMIN_DIR>/msp/signcerts/下的证书拷贝为<LOCAL_MSP_DIR>/admincerts/cert.pem
            cp $LOCAL_ADMIN_DIR/msp/signcerts/* $LOCAL_MSP_DIR/admincerts/cert.pem
            # 2.3 将<LOCAL_ADMIN_DIR>/msp/signcerts/下的证书拷贝为<LOCAL_ADMIN_DIR>/msp/admincerts/cert.pem
            mkdir $LOCAL_ADMIN_DIR/msp/admincerts
            cp $LOCAL_ADMIN_DIR/msp/signcerts/* $LOCAL_ADMIN_DIR/msp/admincerts
        fi
    fi
}

# 登记普通用户身份获取证书
function getUserCert {

    if [ ! -d $FABRIC_CA_CLIENT_HOME ]; then

        # 等待将CA服务端初始化生成的根证书拷贝为CA_CHAINFILE文件
        # 即校验本地CA_CHAINFILE证书文件是否存在
        dowait "$CA_NAME to start" 60 $CA_LOGFILE $CA_CHAINFILE

        log "Enrolling user for organization $ORG with home directory $FABRIC_CA_CLIENT_HOME ..."

        # 而对于orderer、peer节点，在其docker-compose.yaml中的service.xxx.environment中已经定义FABRIC_CA_CLIENT_TLS_CERTFILES环境变量
        export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

        fabric-ca-client enroll -d -u https://$USER_NAME:$USER_PASS@$CA_HOST:7054

        # 将 /${DATA}/orgs/$ORG/admin/msp/signcerts/ 下的证书拷贝为:
        # /etc/hyperledger/fabric/orgs/$ORG/user/msp/admincerts
        if [ $ADMINCERTS ]; then
            ACDIR=$CORE_PEER_MSPCONFIGPATH/admincerts
            mkdir -p $ACDIR
            cp $ORG_ADMIN_HOME/msp/signcerts/* $ACDIR
        fi
    fi
}

# 为指定组织向CA服务端申请根证书，并保存到/${DATA}/orgs/${ORG}/msp
# 如果ADMINCERTS为true，我们需要登记组织管理员并将证书保存到/${DATA}/orgs/${ORG}/msp/admincerts
function getCACerts {

    log "Getting CA certificates ..."

    ORG=$1

    initOrgVars $ORG

    log "Getting CA certs for organization $ORG and storing in $ORG_MSP_DIR"

    # 对于orderer、peer节点，在其docker-compose.yaml中的service.xxx.environment中已经定义FABRIC_CA_CLIENT_TLS_CERTFILES环境变量
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

    # 向CA服务端申请根证书，并保存到/${DATA}/orgs/${ORG}/msp目录下的/cacerts 与 /intermediatecerts文件夹下
    # ORG_MSP_DIR=/${DATA}/orgs/${ORG}/msp
    fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $ORG_MSP_DIR

    # 如果msp目录下的tls相关证书目录不存在的话，则创建它们。
    #   1. 创建msp/tlscacerts目录并将msp/cacerts目录下的证书拷贝到其下
    #   2. 创建msp/tlsintermediatecerts目录并将msp/intermediatecerts目录下的证书拷贝到其下
    finishMSPSetup $ORG_MSP_DIR

    # 如果ADMINCERTS为true，我们需要登记组织管理员并将证书保存到msp目录下的admincerts文件夹下
    if [ $ADMINCERTS ]; then
        getAdminCert $ORG_ADMIN_HOME $ORG_MSP_DIR
    fi
}

# 调用之前，请务必确保设置了FABRIC_CA_CLIENT_TLS_CERTFILES、FABRIC_CA_CLIENT_HOME
function getTLSCertKey {

    if [ $# -ne 3 ]; then
        echo "Usage: getClientTLSCert <host_name> <cert_file> <key_file>: $*"
        exit 1
    fi

    HOST_NAME=$1
    CERT_FILE=$2
    KEY_FILE=$3

    fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $HOST_NAME

    TLS_CERT_DIR=$(dirname "$CERT_FILE")
    TLS_KEY_DIR=$(dirname "$KEY_FILE")
    mkdir -p $TLS_CERT_DIR || true
    mkdir -p $TLS_KEY_DIR || true

    cp /tmp/tls/signcerts/* $CERT_FILE
    cp /tmp/tls/keystore/* $KEY_FILE
    rm -rf /tmp/tls
}

# 从远程CA服务端获取CA_CHAINFILE
# Usage: fetchCAChain <ORG> <CA_CHAINFILE> [IS_ROOT_CA_CERTFILE]
# 注意：传入的<CA_CHAINFILE>以'/'开头
function fetchCAChain {

    if [ $# -lt 2 ]; then
        echo "Usage: fetchCAChain <ORG> <CA_CHAINFILE> [IS_ROOT_CA_CERTFILE]: $*"
        exit 1
    fi

    local ORG=$1
    local CA_CHAINFILE=$2
    local IS_ROOT_CA_CERTFILE=$3 # 获取的是否是根CA证书
    : ${IS_ROOT_CA_CERTFILE:=false}

    # 获取指定CA的连接属性
    if $USE_INTERMEDIATE_CA && ! $IS_ROOT_CA_CERTFILE; then
        CA_USER_NAME=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.USER_NAME')
        CA_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')
        CA_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.PATH')
        CA_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.PWD')
    else
        CA_USER_NAME=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.USER_NAME')
        CA_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')
        CA_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.PATH')
        CA_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.PWD')
    fi

    # 判断是否可访问CA服务
    waitPort "access CA < ip: $CA_IP > via port 22" 90 "" $CA_IP 22

    set +e

    local remoteCAChain="${CA_PATH}${CA_CHAINFILE}" # 远程CA服务端的CA_CHAINFILE文件路径

    echo "    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑"
    echo "    　 To: CA服务器 < ip: ${CA_IP}, username: ${CA_USER_NAME} >"
    echo
    echo "    　 -> 检查CA根证书 < ${remoteCAChain} > 是否可用..."
    echo
    echo "    　 * 温馨提示：你可以配置ssh免登陆哦！~"
    echo "    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

    ${SDIR}/scripts/file_exits.sh ${CA_USER_NAME} ${CA_IP} ${CA_PWD} ${remoteCAChain} >& ssh.log
    local rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Remote CA certificate not found"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    local localCAChainPath=$(dirname "${SDIR}${CA_CHAINFILE}") # CA_CHAINFILE文件保存本地的路径
    if [ ! -d ${localCAChainPath} ]; then
        mkdir -p ${localCAChainPath}
    fi

    cat << EOF
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
    　 -> 拉取CA根证书...
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF

    ${SDIR}/scripts/file_scp.sh ${CA_USER_NAME} ${CA_IP} ${CA_PWD} ${remoteCAChain} "${SDIR}${CA_CHAINFILE}" "from" >& ssh.log
    rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Failed to copy certificate from remote CA. exits?"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    log "Copy the certificate from the remote CA successfully and store it as ${CA_CHAINFILE}"

    set -e
}

# 从'setup'节点获取指定组织的Admin
function fetchOrgAdmin {

    if [ $# -ne 1 ]; then
        echo "Usage: fetchOrgAdmin <ORG>"
        exit 1
    fi

    local ORG=$1

    initOrgVars $ORG

    # 获取'setup'节点的连接属性
    SETUP_USER_NAME=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.USER_NAME')
    SETUP_IP=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.IP')
    SETUP_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PATH')
    SETUP_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PWD')

    # 判断是否可访问'setup'节点
    waitPort "access 'setup' < ip: $SETUP_IP > via port 22" 90 "" $SETUP_IP 22

    set +e
    local remoteOrgMsp="${SETUP_PATH}"$(dirname "$ORG_ADMIN_HOME")
    echo "    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑"
    echo "    　 To: \'setup\'服务器 < ip: ${SETUP_IP}, username: ${SETUP_USER_NAME} >"
    echo
    echo "    　 -> 检查组织MSP < ${remoteOrgMsp} > 是否可用..."
    echo
    echo "    　 * 温馨提示：你可以配置ssh免登陆哦！~"
    echo "    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

    ${SDIR}/scripts/file_exits.sh ${SETUP_USER_NAME} ${SETUP_IP} ${SETUP_PWD} ${remoteOrgMsp} >& ssh.log
    local rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Remote ${ORG} MSP not found"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    local localOrgMsp=${SDIR}$(dirname "$ORG_ADMIN_HOME")
    local localOrgMspPath=$(dirname $localOrgMsp)
    if [ ! -d ${localOrgMspPath} ]; then
        mkdir -p ${localOrgMspPath}
    fi

    cat << EOF
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
    　 -> 拉取组织MSP...
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF

    ${SDIR}/scripts/file_scp.sh ${SETUP_USER_NAME} ${SETUP_IP} ${SETUP_PWD} ${remoteOrgMsp} $localOrgMsp "from" >& ssh.log
    rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Failed to copy MSP from remote 'setup'. exits?"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    log "Copy the MSP from the remote 'setup' successfully and store it as "$localOrgMsp
    set -e
}

# 从'setup'节点获取指定组织的MSP
function fetchOrgMSP {

    if [ $# -ne 1 ]; then
        echo "Usage: fetchOrgMSP <ORG>"
        exit 1
    fi

    local ORG=$1

    initOrgVars $ORG

    # 获取'setup'节点的连接属性
    SETUP_USER_NAME=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.USER_NAME')
    SETUP_IP=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.IP')
    SETUP_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PATH')
    SETUP_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PWD')

    # 判断是否可访问'setup'节点
    waitPort "access 'setup' < ip: $SETUP_IP > via port 22" 90 "" $SETUP_IP 22

    set +e
    local remoteOrgMsp="${SETUP_PATH}"$(dirname "$ORG_MSP_DIR")
    echo "    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑"
    echo "    　 To: \'setup\'服务器 < ip: ${SETUP_IP}, username: ${SETUP_USER_NAME} >"
    echo
    echo "    　 -> 检查组织MSP < ${remoteOrgMsp} > 是否可用..."
    echo
    echo "    　 * 温馨提示：你可以配置ssh免登陆哦！~"
    echo "    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

    ${SDIR}/scripts/file_exits.sh ${SETUP_USER_NAME} ${SETUP_IP} ${SETUP_PWD} ${remoteOrgMsp} >& ssh.log
    local rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Remote ${ORG} MSP not found"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    local localOrgMspPath=$(dirname ${SDIR}$(dirname "$ORG_MSP_DIR"))
    if [ ! -d ${localOrgMspPath} ]; then
        mkdir -p ${localOrgMspPath}
    fi

    cat << EOF
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
    　 -> 拉取组织MSP...
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF

    ${SDIR}/scripts/file_scp.sh ${SETUP_USER_NAME} ${SETUP_IP} ${SETUP_PWD} ${remoteOrgMsp} ${SDIR}$(dirname "$ORG_MSP_DIR") "from" >& ssh.log
    rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Failed to copy MSP from remote 'setup'. exits?"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    log "Copy the MSP from the remote 'setup' successfully and store it as "${SDIR}$(dirname "$ORG_MSP_DIR")
    set -e
}

# 从'setup'节点获取配置交易文件
function fetchChannelTx {

    if [ $# -ne 1 ]; then
        echo "Usage: fetchChannelTx <channel_tx_file>"
        exit 1
    fi

    CHANNEL_TX_FILE=$1

    # 获取'setup'节点的连接属性
    SETUP_USER_NAME=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.USER_NAME')
    SETUP_IP=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.IP')
    SETUP_PATH=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PATH')
    SETUP_PWD=$(cat fabric.config | jq -r '.NET_CONFIG.SETUP.PWD')

    # 判断是否可访问'setup'节点
    waitPort "access 'setup' < ip: $SETUP_IP > via port 22" 90 "" $SETUP_IP 22

    set +e
    local remoteChannelTxFile="${SETUP_PATH}${CHANNEL_TX_FILE}"
    echo "    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑"
    echo "    　 To: \'setup\'服务器 < ip: ${SETUP_IP}, username: ${SETUP_USER_NAME} >"
    echo
    echo "    　 -> 检查配置交易文件 < ${remoteChannelTxFile} > 是否可用..."
    echo
    echo "    　 * 温馨提示：你可以配置ssh免登陆哦！~"
    echo "    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

    ${SDIR}/scripts/file_exits.sh ${SETUP_USER_NAME} ${SETUP_IP} ${SETUP_PWD} ${remoteChannelTxFile} >& ssh.log
    local rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Remote channel configuration transaction not found"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    local localChannelTxPath=$(dirname "$PWD${CHANNEL_TX_FILE}")
    if [ ! -d ${localChannelTxPath} ]; then
        mkdir -p ${localChannelTxPath}
    fi

    cat << EOF
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
    　 -> 拉取配置交易文件...
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF

    ${SDIR}/scripts/file_scp.sh ${SETUP_USER_NAME} ${SETUP_IP} ${SETUP_PWD} ${remoteChannelTxFile} "$PWD${CHANNEL_TX_FILE}" "from" >& ssh.log
    rs=$?
    if [ $rs -eq 1 ]; then
        fatal "Failed to copy channel configuration transaction from remote 'setup'. eixts?"
    elif [ $rs -eq 2 ]; then
        fatal "Password is wrong!~"
    elif [ $rs -ne 0 ]; then
        fatal "Unknow error!~"
    fi

    log "Copy the channel configuration transaction from the remote 'setup' successfully and store it as ${CHANNEL_TX_FILE}"
    set -e
}

# fetchChannelConfig <ORDERER_ORG> <ORDERER_NUM> <CHANNEL_NAME> <OUTPUT_JSON>
# 新组织未加入fabric应用通道，所以无权获取配置区块，这里使用的是第一个Peer组织的管理员身份来获取配置区块
# 获取给定channel的配置区块，解码为json，并使用jq工具提取其中的完整的通道配置信息部分（.data.data[0].payload.data.config）保存到config.json文件中
fetchChannelConfig() {

    ORDERER_ORG=$1
    ORDERER_NUM=$2
    CHANNEL_NAME=$3
    OUTPUT_JSON=$4

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

    # 使用第一个Peer组织的管理员身份来获取配置区块
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS" # 将PEER_ORGS转换成PORGS数组变量
    initPeerVars ${PORGS[0]} 1

    # 获取第一个Peer组织的客户端认证tls证书和密钥，用于--clientauth
    ENROLLMENT_URL=https://$PEER_NAME_PASS@$CA_HOST:7054
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
    getTLSCertKey $PEER_NAME $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE

    switchToAdminIdentity

    # 获取指定channel的配置区块
    echo "Fetching the most recent configuration block for the channel"

    peer channel fetch config config_block.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS

    echo "Decoding config block to JSON and isolating config to ${OUTPUT_JSON}"
    configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > "${OUTPUT_JSON}"
}

# createConfigUpdate <channel_name> <original_config.json> <modified_config.json> <output.pb>
# 使用原始的和修改的配置，来生成配置更新交易文件
createConfigUpdate() {
    CHANNEL_NAME=$1 # 应用通道名称
    ORIGINAL_JSON=$2 # 原通道配置json文件
    MODIFIED_JSON=$3 # 修改的通道配置json文件
    OUTPUT_ENVELOPE=$4 # 最终输出的配置更新交易文件

    # 将通道配置json文件编码生成类型为common.Config的配置文件
    configtxlator proto_encode --input "${ORIGINAL_JSON}" --type common.Config > original_config.pb
    configtxlator proto_encode --input "${MODIFIED_JSON}" --type common.Config > modified_config.pb

    # 计算配置更新量，输出类型为common.ConfigUpdate的配置更新文件
    configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original original_config.pb --updated modified_config.pb > config_update.pb
    # 将类型为common.ConfigUpdate的配置更新文件解码为json文件
    configtxlator proto_decode --input config_update.pb  --type common.ConfigUpdate > config_update.json

    # 将上述common.ConfigUpdate结构数据补全，编码生成类型为common.Envelope的配置更新交易文件
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
    configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope > "${OUTPUT_ENVELOPE}"
}

# 等待进程开始监听特定的主机和端口
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
function waitPort {

    set +e

    local what=$1
    local secs=$2
    local logFile=$3
    local host=$4
    local port=$5

    # 端口扫描
    # -z:告诉netcat使用0 IO，连接成功后立即关闭连接，不进行数据交换
    nc -z $host $port > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        log -n "Waiting for $what ..."
        local startTime=$(date +%s)
        while true; do
            sleep 1
            nc -z $host $port > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                break
            fi
            if [ "$(($(date +%s)-startTime))" -gt "$secs" ]; then
                echo ""
                fatal "Failed waiting for $what; see $logFile"
            fi
            echo -n "."
        done
        echo ""
    fi
    set -e
}

# 等待多个文件生成
# Usage: dowait <WHAT> <TIMEOUTINSECS> <ERRORLOGFILE> <FILE>...
function dowait {

    if [ $# -lt 4 ]; then
        fatal "Usage: dowait <WHAT> <TIMEOUTINSECS> <ERRORLOGFILE> <FILE>...: $*"
    fi

    local what=$1
    local secs=$2
    local logFile=$3
    shift 3

    local logit=true
    local startTime=$(date +%s)

    for file in $*; do
        # 除非$file是一个文件，否则一直循环至超时退出
        until [ -f $file ]; do
            if [ "$logit" = true ]; then
                log -n "Waiting for $what ..."
                logit=false
            fi
            sleep 1
            if [ "$(($(date +%s)-startTime))" -gt "$secs" ]; then
                echo ""
                fatal "Failed waiting for $what ($file not found); see $logFile"
            fi
            echo -n "."
        done
    done

    echo ""
}

# log a message
function log {
   if [ "$1" = "-n" ]; then
      shift
      echo -n "##### `date '+%Y-%m-%d %H:%M:%S'` $*"
   else
      echo "##### `date '+%Y-%m-%d %H:%M:%S'` $*"
   fi
}

# fatal a message
function fatal {
   log "FATAL: $*"
   exit 1 # 错误退出
}

function verifyResult {

    if [ $1 -ne 0 ] ; then
        echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
        echo "========= ERROR !!! FAILED  ==========="
        echo
        exit 1
    fi
}

function installJQAuto {

    which jq >& /dev/null
    if [ $? -ne 0 ]; then
        log "Not installed jq"
        echo "Installing jq"
        # 使用-y选项会在安装过程中使用默认设置，如果默认设置为N，那么就会选择N，而不会选择y。并没有让apt-get一直选择y的选项。
        apt-get -y update && apt-get -y install jq
    fi
}

function installJQ {

    set +e

    which jq >& /dev/null
    if [ $? -ne 0 ]; then
#        log "Not installed jq"
#        echo "Installing jq"
#        # 使用-y选项会在安装过程中使用默认设置，如果默认设置为N，那么就会选择N，而不会选择y。并没有让apt-get一直选择y的选项。
#        apt-get -y update && apt-get -y install jq
        log "Not installed jq, Please install jq and try again!!!"
        log ""
        log "       sudo apt-get -y update && sudo apt-get -y install jq"
        log ""
        log "Good luck!~"
        exit 1
    fi

    set -e
}

function installExpect {

    set +e

    which expect >& /dev/null
    if [ $? -ne 0 ]; then
        log "Not installed expect, Please install expect and try again!!!"
        log ""
        log "       sudo apt-get -y update && sudo apt-get -y install expect"
        log ""
        log "Good luck!~"
        exit 1
    fi

    set -e
}

binariesDownload() {

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

function binariesInstall {

    local DOWN_REMOTE_BIN=$1
    : ${DOWN_REMOTE_BIN:="false"}

    if [ "$DOWN_REMOTE_BIN" == "true" ]; then # 下载构建通道Artifacts所需的二进制文件

        echo
        echo "Installing Hyperledger Fabric binaries . And get them from the remote."
        echo

        # 下载bin/下的configtxgen、configtxlator、cryptogen、orderer、peer二进制文件，以及config/下的configtx.yaml、core.yaml、orderer.yaml配置文件
        binariesDownload

        export PATH=${SDIR}/bin:$PATH

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
}

# joinChannelWithRetry <ORG> <NUM>
# 切换到peer组织的管理员身份，然后加入应用通道
# 有时加入应用通道需要时间，因此至少重试5次
function joinChannelWithRetry {

    COUNTER=1
    MAX_RETRY=5
    DELAY=3

	ORG=$1
    PEER=$2

    initPeerVars $ORG $PEER
    switchToAdminIdentity

    # step2.sh之前通过peer channel fetch会在cli当前工作目录下生成一个$CHANNEL_NAME.block区块，用于后续加入通道；
    set +e
    peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
    set -e
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
        COUNTER=`expr $COUNTER + 1`
        echo "${PEER_NAME} failed to join the channel, Retry after $DELAY seconds"
        sleep $DELAY
		joinChannelWithRetry $ORG $PEER
    fi

    verifyResult $res "After $MAX_RETRY attempts, ${PEER_NAME} has failed to Join the Channel"
}

# 切换到peer组织的管理员身份，然后安装链码
function installChaincode {

    CC_NAME=$1 # 链码名称
    CC_VERSION=$2 # 链码版本
    CC_PATH=$3 # 链码路径
    IS_VALID=$4
    : ${IS_VALID:="false"}

    switchToAdminIdentity
    log "Installing chaincode on $PEER_HOST ..."
    peer chaincode install -n $CC_NAME -v $CC_VERSION -p $CC_PATH 2>&1 | tee log.txt
    res=$?
    if [ $res -ne 0 ]; then
        VALUE=$(cat log.txt | awk '/chaincode error/ {print $(NF-1)$NF}')
        if [ $? -eq 0 -a "$VALUE" == "${CC_NAME}.${CC_VERSION}exists" ]; then
            log "chaincode '${CC_NAME}.${CC_VERSION}' is already install"
        else
            fatal "install of chaincode '${CC_NAME}.${CC_VERSION}' failed"
        fi
    fi
}

function chaincodeQuery {

    if [ $# -ne 1 ]; then
        fatal "Usage: chaincodeQuery <EXPECTED_VALUE>"
    fi

    set +e

    log "Querying chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' ..."

    local rc=1
    local startTime=$(date +%s)

    # Continue to poll until we get a successful response or reach QUERY_TIMEOUT
    while test "$(($(date +%s)-startTime))" -lt "$QUERY_TIMEOUT"; do
        sleep 1
        peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >& log.txt
        VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
        if [ $? -eq 0 -a "$VALUE" = "$1" ]; then
            log "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
            set -e
            return 0
        fi
        echo -n "."
    done

    cat log.txt
    fatal "Failed to query channel '$CHANNEL_NAME' on peer '$PEER_HOST'; expected value was $1 and found $VALUE"
}

# 链码实例化策略/链码背书策略，新加入组织需要重新安装更新链码，否则新组织没有写权限
function makePolicy {

    # NAME=liucl
    # echo "My Name is '${NAME}'" -> My Name is 'liucl'
    # echo My Name is '${NAME}' -> My Name is ${NAME}

    POLICY="OR("
    local COUNT=0

    for ORG in $PEER_ORGS; do
        if [ $COUNT -ne 0 ]; then
            POLICY="${POLICY}," # 拼接逗号
        fi

        initOrgVars $ORG
        POLICY="${POLICY}'${ORG_MSP_ID}.member'"
        COUNT=$((COUNT+1))
    done

    POLICY="${POLICY})"
    log "policy: $POLICY"
}