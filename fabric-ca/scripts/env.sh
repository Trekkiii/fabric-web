#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0

# docker-compose网络的名称
NETWORK=fabric-ca

# orderer组织的名称
ORDERER_ORGS="org0"

# peer组织的名称
PEER_ORGS="org1 org2"

# 每一个peer组织的peers数量
NUM_PEERS=2

# 每一个orderer组织的orderer节点的数量
NUM_ORDERERS=1

# 所有组织名称
ORGS="$ORDERER_ORGS $PEER_ORGS"

# 设置为true以填充msp的"admincerts"文件夹
ADMINCERTS=true

# 挂载的DATA目录
DATA=data

# 创世区块的路径
GENESIS_BLOCK_FILE=/$DATA/genesis.block

# 应用通道配置交易文件的路径
CHANNEL_TX_FILE=/$DATA/channel.tx

# 应用通道的名称
CHANNEL_NAME=mychannel

# 查询超时，单位秒
QUERY_TIMEOUT=15

# 'setup'容器的超时，单位秒
SETUP_TIMEOUT=120

# Log日志目录
LOGDIR=$DATA/logs # 默认 data/logs
LOGPATH=/$LOGDIR # 默认 /data/logs

# 标记'setup'容器成功执行完所有操作
SETUP_SUCCESS_FILE=${LOGDIR}/setup.successful
# 'setup'容器的日志文件
SETUP_LOGFILE=${LOGDIR}/setup.log

# 'run'容器的日志文件
RUN_LOGFILE=${LOGDIR}/run.log
# 'run'容器的摘要日志文件
RUN_SUMFILE=${LOGDIR}/run.sum
RUN_SUMPATH=/${RUN_SUMFILE}
# 'run'容器成功和失败的日志文件
RUN_SUCCESS_FILE=${LOGDIR}/run.success
RUN_FAIL_FILE=${LOGDIR}/run.fail

# TODO Affiliation并不用于限制用户，因此只需将所有身份置于相同的affiliation中。
export FABRIC_CA_CLIENT_ID_AFFILIATION=org1

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

# 删除所有fabric相关的容器
function removeFabricContainers {

    # 删除fabric容器（其镜像名称包含hyperledger的）
    dockerContainers=$(docker ps -a | awk '$2~/hyperledger/ {print $1}')
    if [ "$dockerContainers" != "" ]; then
        log "Deleting existing docker containers ..."
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

    ORG=$1

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
    ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/cert.pem # /${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
    ORG_ADMIN_HOME=/${DATA}/orgs/${ORG}/admin # /${DATA}/orgs/${ORG}/admin

    # 根CA
    ROOT_CA_HOST=rca-${ORG}
    ROOT_CA_NAME=rca-${ORG}
    ROOT_CA_LOGFILE=$LOGDIR/${ROOT_CA_NAME}.log
    # 根CA管理员
    ROOT_CA_ADMIN_USER=rca-${ORG}-admin
    ROOT_CA_ADMIN_PASS=${ROOT_CA_ADMIN_USER}pw
    # 根CA服务初始化时指定的用户名和密码，用于<fabric-ca-server init -b>
    ROOT_CA_ADMIN_USER_PASS=${ROOT_CA_ADMIN_USER}:${ROOT_CA_ADMIN_PASS}

    # 中间层CA
    INT_CA_HOST=ica-${ORG}
    INT_CA_NAME=ica-${ORG}
    INT_CA_LOGFILE=$LOGDIR/${INT_CA_NAME}.log
    # 中间层CA管理员
    INT_CA_ADMIN_USER=ica-${ORG}-admin
    INT_CA_ADMIN_PASS=${INT_CA_ADMIN_USER}pw
    # 中间层CA服务初始化时指定的用户名和密码，用于<fabric-ca-server init -b -u>
    INT_CA_ADMIN_USER_PASS=${INT_CA_ADMIN_USER}:${INT_CA_ADMIN_PASS}

    # CA根证书
    ROOT_CA_CERTFILE=/${DATA}/${ORG}-ca-cert.pem
    INT_CA_CHAINFILE=/${DATA}/${ORG}-ca-chain.pem

    # 锚节点配置更新交易文件
    ANCHOR_TX_FILE=/${DATA}/orgs/${ORG}/anchors.tx

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

# initOrdererVars <NUM>
function initOrdererVars {

    if [ $# -ne 2 ]; then
        echo "Usage: initOrdererVars <ORG> <NUM>"
        exit 1
    fi

    initOrgVars $1
    NUM=$2

    ORDERER_HOST=orderer${NUM}-${ORG}
    ORDERER_NAME=orderer${NUM}-${ORG}
    ORDERER_PASS=${ORDERER_NAME}pw
    ORDERER_NAME_PASS=${ORDERER_NAME}:${ORDERER_PASS}
    ORDERER_LOGFILE=$LOGDIR/${ORDERER_NAME}.log

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
    NUM=$2

    PEER_HOST=peer${NUM}-${ORG}
    PEER_NAME=peer${NUM}-${ORG}
    PEER_PASS=${PEER_NAME}pw
    PEER_NAME_PASS=${PEER_NAME}:${PEER_PASS}
    PEER_LOGFILE=$LOGDIR/${PEER_NAME}.log

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
    export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_${NETWORK}
    # export CORE_LOGGING_LEVEL=ERROR
    export CORE_LOGGING_LEVEL=DEBUG

    # enabled TLS
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE # TLS开启时指定信任的根CA证书位置
    export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true # 是否启用客户端验证
    export CORE_PEER_TLS_CLIENTCERT_FILE=/$DATA/tls/$PEER_NAME-cli-client.crt # Peer节点的PEM编码的X509公钥文件(代表peer用户身份)，用于客户端验证
    export CORE_PEER_TLS_CLIENTKEY_FILE=/$DATA/tls/$PEER_NAME-cli-client.key # Peer节点的PEM编码的私钥文件(代表peer用户身份)，用于客户端验证
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
        fatal "Usage: finishMSPSetup <targetMSPDIR>"
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

# 当启用ADMINCERTS时
#
# 将组织的管理员证书拷贝到目标msp目录
function copyAdminCert {

    if [ $# -ne 1 ]; then
        fatal "Usage: copyAdminCert <targetMSPDIR>"
    fi

    if $ADMINCERTS; then

        # 登记组织管理员并获取组织管理员身份证书
        switchToAdminIdentity

        dowait "$ORG administator to enroll" 60 $SETUP_LOGFILE $ORG_ADMIN_CERT

        dstDir=$1/admincerts
        mkdir -p $dstDir
        # ORG_ADMIN_CERT=/${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
        # 对于orderer节点：dstDir=/etc/hyperledger/orderer/msp/admincerts
        # 对于peer节点：dstDir=/opt/gopath/src/github.com/hyperledger/fabric/peer/msp
        cp $ORG_ADMIN_CERT $dstDir
    fi
}

# 1. 切换到当前组织的管理员身份；
# 2. 如果之前没有登记，则登记，
#   2.1 保存登记时生成的身份证书至/${DATA}/orgs/${ORG}/admin目录下；
#       会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
#   2.2 将/${DATA}/orgs/${ORG}/admin/msp/signcerts/下的证书拷贝为/${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
#   2.3 将/${DATA}/orgs/${ORG}/admin/msp/signcerts/下的证书拷贝为/${DATA}/orgs/${ORG}/admin/msp/admincerts/cert.pem
function switchToAdminIdentity {

    # 2. 如果之前没有登记，则登记
    if [ ! -d $ORG_ADMIN_HOME ]; then # /${DATA}/orgs/${ORG}/admin
        # 等待CA服务端将初始化生成的根证书拷贝为CA_CHAINFILE文件
        dowait "$CA_NAME to start" 60 $CA_LOGFILE $CA_CHAINFILE

        log "Enrolling admin '$ADMIN_NAME' with $CA_HOST ..."

        # fabric-ca-client主配置目录
        # fabric-ca-client会在该目录下搜索配置文件，
        # 同样，也会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
        export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME

        # 向CA服务端登记组织管理员身份时使用
        # 该环境变量配置主要针对'setup'等节点，
        # 而对于orderer、peer节点，在其docker-compose.yaml中的service.xxx.environment中已经定义FABRIC_CA_CLIENT_TLS_CERTFILES环境变量
        export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

        # 登记组织管理员身份
        fabric-ca-client enroll -d -u https://$ADMIN_NAME:$ADMIN_PASS@$CA_HOST:7054

        # 将 /${DATA}/orgs/$ORG/admin/msp/signcerts/ 下的证书拷贝为:
        #       /${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
        #       /${DATA}/orgs/$ORG/admin/msp/admincerts/cert.pem
        if [ $ADMINCERTS ]; then
            mkdir -p $(dirname "${ORG_ADMIN_CERT}")
            # 2.2 将/${DATA}/orgs/${ORG}/admin/msp/signcerts/下的证书拷贝为/${DATA}/orgs/${ORG}/msp/admincerts/cert.pem
            cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_CERT
            # 2.3 将/${DATA}/orgs/${ORG}/admin/msp/signcerts/下的证书拷贝为/${DATA}/orgs/${ORG}/admin/msp/admincerts/cert.pem
            mkdir $ORG_ADMIN_HOME/msp/admincerts
            cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_HOME/msp/admincerts
        fi
    fi

    # 1. 切换到当前组织的管理员身份
    export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp # /${DATA}/orgs/${ORG}/admin/msp
}

# 切换到peer组织的普通用户身份，如果之前没有登记，则登记。
function switchToUserIdentity {

    # fabric-ca-client主配置目录
    # fabric-ca-client会在该目录下搜索配置文件，
    # 同样，也会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
    export FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric/orgs/$ORG/user
    # 1. 切换到peer组织的管理员身份
    export CORE_PEER_MSPCONFIGPATH=$FABRIC_CA_CLIENT_HOME/msp

    if [ ! -d $FABRIC_CA_CLIENT_HOME ]; then

        # 等待CA服务端将初始化生成的根证书拷贝为CA_CHAINFILE文件
        dowait "$CA_NAME to start" 60 $CA_LOGFILE $CA_CHAINFILE

        log "Enrolling user for organization $ORG with home directory $FABRIC_CA_CLIENT_HOME ..."

        # 向CA服务端登记组织普通用户身份时使用
        # 该环境变量配置主要针对'run'等节点，
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

function genClientTLSCert {

    if [ $# -ne 3 ]; then
        echo "Usage: genClientTLSCert <host name> <cert file> <key file>: $*"
        exit 1
    fi

    HOST_NAME=$1
    CERT_FILE=$2
    KEY_FILE=$3

    fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $HOST_NAME

    mkdir /$DATA/tls || true
    cp /tmp/tls/signcerts/* $CERT_FILE
    cp /tmp/tls/keystore/* $KEY_FILE
    rm -rf /tmp/tls
}

# 从远程CA服务端获取CA_CHAINFILE
# fetchCAChainfile <ORG> <CA_CHAINFILE>
function fetchCAChainfile {

    if [ $# -ne 2 ]; then
        echo "Usage: fetchCAChainfile <ORG> <CA_CHAINFILE>"
        exit 1
    fi

    ORG=$1
    CA_CHAINFILE=$2

    echo "Installing jq"
    # 使用-y选项会在安装过程中使用默认设置，如果默认设置为N，那么就会选择N，而不会选择y。并没有让apt-get一直选择y的选项。
    apt-get -y update && apt-get -y install jq
    # 校验fabric.config配置是否是合法性JSON
    cat fabric.config | jq . >& /dev/null
    if [ $? -ne 0 ]; then
        fatal "fabric.config isn't JSON format"
    fi

    # 获取指定CA连接属性
    # 使用中间层CA
    if $USE_INTERMEDIATE_CA; then
        CA_UNAME=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.UNAME')
        CA_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.IP')
        CAPATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.ICA.CAPATH')
    else
        CA_UNAME=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.UNAME')
        CA_IP=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.IP')
        CAPATH=$(cat fabric.config | jq -r '.NET_CONFIG.'"${ORG}"'.RCA.CAPATH')
    fi

    # 判断是否可访问CA服务
    waitPort "CA server[ip: $CA_IP] to access through port 22" 90 "https://github.com/fnpac/fabric-web/tree/master/fabric-ca#启动CA服务" $CA_IP 22

    cat << EOF
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
    　 请输入CA服务器 [IP: ${CA_IP}, UNAME: ${CA_UNAME}] 的密码 -> 检查CA根证书是否可用...
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF
    local remotePath="${CAPATH}${CA_CHAINFILE}"
    ssh ${CA_UNAME}@${CA_IP} "[ -f ${remotePath} ]"
    if [ $? -ne 0 ]; then
        fatal "Remote CA certificate of ${remotePath} not found"
    fi

    mkdir -p ${DATA}

    cat << EOF
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
    　 请再次输入CA服务器的密码 -> 拉取CA根证书...　　　
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
EOF

    scp ${CA_UNAME}@${CA_IP}:${remotePath} "$PWD${CA_CHAINFILE}"
    if [ $? -ne 0 ]; then
        fatal "Failed to copy certificate [ ${remotePath} ] from remote CA"
    fi
    log "Copy the certificate from the remote CA successfully and store it as ${CA_CHAINFILE}"
}

# 等待进程开始监听特定的主机和端口
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile|doc> <host> <port>
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
        local starttime=$(date +%s)
        while true; do
            sleep 1
            nc -z $host $port > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                break
            fi
            if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
                echo ""
                fatal "Failed waiting for $what; see $logFile"
            fi
            echo -n "."
        done
        echo ""
    fi
    set -e
}

# @Deprecated
# 等待'setup'容器完成注册身份
function awaitSetup {
   dowait "the 'setup' container to finish registering identities" $SETUP_TIMEOUT $SETUP_LOGFILE /$SETUP_SUCCESS_FILE
}

# 等待多个文件生成
# Usage: dowait <what> <timeoutInSecs> <errorLogFile> <file> [<file> ...]
function dowait {

    if [ $# -lt 4 ]; then
        fatal "Usage: dowait: $*"
    fi

    local what=$1
    local secs=$2
    local logFile=$3
    shift 3

    local logit=true
    local starttime=$(date +%s)

    for file in $*; do
        # 除非$file是一个文件，否则一直循环至超时退出
        until [ -f $file ]; do
            if [ "$logit" = true ]; then
                log -n "Waiting for $what ..."
                logit=false
            fi
            sleep 1
            if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
                echo ""
                fatal "Failed waiting for $what ($file not found); see $logFile"
            fi
            echo -n "."
        done
    done

    echo ""
}

# 为指定节点向CA服务端申请根证书，并保存到/${DATA}/orgs/${ORG}/msp
# 如果ADMINCERTS为true，我们需要登记组织管理员并将证书保存到/${DATA}/orgs/${ORG}/msp/admincerts
function getCACerts {

    log "Getting CA certificates ..."

    if [ $# -ne 1 ]; then
        echo "Usage: getCACerts <ORG>"
        exit 1
    fi

    ORG=$1
    initOrgVars $ORG

    log "Getting CA certs for organization $ORG and storing in $ORG_MSP_DIR"

    # 对于orderer、peer节点，在其docker-compose.yaml中的service.xxx.environment中已经定义FABRIC_CA_CLIENT_TLS_CERTFILES环境变量
    # export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

    # TODO 申请根证书需要提供身份信息么？
    # 向CA服务端申请根证书，并保存到/${DATA}/orgs/${ORG}/msp目录下的/cacerts 与 /intermediatecerts文件夹下
    # ORG_MSP_DIR=/${DATA}/orgs/${ORG}/msp
    fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $ORG_MSP_DIR

    # 如果msp目录下的tls相关证书目录不存在的话，则创建它们。
    #   1. 创建msp/tlscacerts目录并将msp/cacerts目录下的证书拷贝到其下
    #   2. 创建msp/tlsintermediatecerts目录并将msp/intermediatecerts目录下的证书拷贝到其下
    finishMSPSetup $ORG_MSP_DIR

    # 如果ADMINCERTS为true，我们需要登记组织管理员并将证书保存到msp目录下的admincerts文件夹下
    if [ $ADMINCERTS ]; then
        switchToAdminIdentity
    fi
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