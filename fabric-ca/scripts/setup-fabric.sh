#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 此脚本执行以下操作：
#   1) 向中间层fabric-ca-servers注册Orderer和Peer身份
#   2) 构建通道Artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新交易文件）

# registerResultCheck <LOGFILE> <IDENTITY>
function registerResultCheck {

    if [ $# -ne 2 ]; then
        echo "Usage: registerResultCheck <LOGFILE> <IDENTITY>"
        exit 1
    fi

    local LOGFILE=$1
    local IDENTITY=$2

    VALUE=$(cat ${LOGFILE} | awk '/Response from server/ {print $(NF-1)$NF}')
    if [ $? -eq 0 -a "$VALUE" == "alreadyregistered" ]; then
        log "Identity '${IDENTITY}' is already registered"
    else
        fatal "Registration of '${IDENTITY}' failed"
    fi
}

# 注册与Orderer和Peer相关的所有用户身份
function registerIdentities {

    log "Registering identities ..."
    # 注册与Orderer相关的所有用户实体（所有orderer节点用户、所有orderer组织的管理员用户）
    registerOrdererIdentities

    # 注册与Peer相关的所有用户实体（所有peer节点用户、peer组织的管理员用户、peer组织的普通用户）
    registerPeerIdentities
}

# 注册与Orderer相关的所有用户实体（所有orderer节点用户、所有orderer组织的管理员用户）
function registerOrdererIdentities {

    for ORG in $ORDERER_ORGS; do

        initOrgVars $ORG

        # !!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!
        # 登记CA管理员，'FABRIC_CA_CLIENT_HOME'指向CA管理员msp
        enrollCAAdmin

        set +e
        local COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT
            log "Registering $ORDERER_NAME with $CA_NAME"
            # 注册当前orderer节点用户
            fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer >& log.txt
            if [ $? -ne 0 ]; then
                registerResultCheck log.txt $ORDERER_NAME
            fi

            COUNT=$((COUNT+1))
        done

        log "Registering admin identity with $CA_NAME"
        # The admin identity has the "admin" attribute which is added to ECert by default
        # 注册orderer组织的管理员用户
        fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert" >& log.txt
        if [ $? -ne 0 ]; then
            registerResultCheck log.txt $ADMIN_NAME
        fi
        set -e
    done
}

# 注册与Peer相关的所有用户实体（所有peer节点用户、peer组织的管理员用户、peer组织的普通用户）
function registerPeerIdentities {

    for ORG in $PEER_ORGS; do

        initOrgVars $ORG

        # !!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!
        # 登记CA管理员，'FABRIC_CA_CLIENT_HOME'指向CA管理员msp
        enrollCAAdmin

        set +e
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            log "Registering $PEER_NAME with $CA_NAME"
            # 注册当前peer节点用户
            fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer >& log.txt
            if [ $? -ne 0 ]; then
                registerResultCheck log.txt $PEER_NAME
            fi

            COUNT=$((COUNT+1))
        done

        log "Registering admin identity with $CA_NAME"
        # The admin identity has the "admin" attribute which is added to ECert by default
        # 注册peer组织的管理员用户
        fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" >& log.txt
        if [ $? -ne 0 ]; then
            registerResultCheck log.txt $ADMIN_NAME
        fi

        log "Registering user identity with $CA_NAME"
        # 注册peer组织的普通用户
        fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS >& log.txt
        if [ $? -ne 0 ]; then
            registerResultCheck log.txt $USER_NAME
        fi
        set -e
    done
}

# 登记CA管理员，FABRIC_CA_CLIENT_HOME指向CA管理员msp
# 以便后面使用CA管理员身份去注册orderer和peer相关用户实体
function enrollCAAdmin {

    # 等待，直至CA服务可用
    waitPort "$CA_NAME to start" 90 $CA_LOGFILE $CA_HOST 7054
    log "Enrolling with $CA_NAME as bootstrap identity ..."

    # fabric-ca-client主配置目录
    # fabric-ca-client会在该目录下搜索配置文件，
    # 同样，也会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
    export FABRIC_CA_CLIENT_HOME=$HOME/cas/$CA_NAME

    # 向所有CA服务端登记CA管理员身份、注册所有Orderer相关的用户实体，以及注册所有Peer相关的用户实体时使用
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

    # 使用初始化CA时指定的用户名和密码来登记CA管理员身份
    fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
}

function makeConfigTxYaml {

    log "Generating configtx.yaml at $SDIR/configtx.yaml"

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
            OrdererType: kafka
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
                # Note: 使用IP:port表示法
                Brokers:"
            installJQAuto
            COUNT=1
            while [[ "$COUNT" -le $NUM_KAFKA ]]; do
                initKafkaVars $COUNT
                echo "                    - "$(cat /fabric.config | jq -r '.NET_CONFIG.KAFKA_CLUSTER['$((COUNT-1))'].IP')":9092"
                COUNT=$((COUNT+1))
            done
            echo "            Organizations:" # 属于orderer通道的组织
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
            Organizations:"
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
    } > /etc/hyperledger/fabric/configtx.yaml
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
    configtxgen -profile OrgsOrdererGenesis -outputBlock $GENESIS_BLOCK_FILE
    if [ "$?" -ne 0 ]; then
        fatal "Failed to generate orderer genesis block"
    fi

    log "Generating channel configuration transaction at $CHANNEL_TX_FILE"
    configtxgen -profile OrgsChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
    if [ "$?" -ne 0 ]; then
        fatal "Failed to generate channel configuration transaction"
    fi

    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
        configtxgen -profile OrgsChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
                 -channelID $CHANNEL_NAME -asOrg $ORG
        if [ "$?" -ne 0 ]; then
            fatal "Failed to generate anchor peer update for $ORG"
        fi
    done
}

function finish {

    if [ "$done" = true ]; then
        log "See $SETUP_LOGFILE for more details"
        touch /$SETUP_SUCCESS_FILE
    else
        log "Tests did not complete successfully; see $SETUP_LOGFILE for more details"
        touch /$SETUP_FAIL_FILE
    fi
}

function main {

    done=false # 标记是否执行完成所有以下操作
    trap finish EXIT

    log "Beginning building channel artifacts ..."
    # 注册与Orderer和Peer相关的所有用户身份
    # !!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!
    registerIdentities

    # !!! 至此，我们注册了所有所需的用户身份，如果需要使用相应的用户身份操作fabric网络（e.g 加入创建应用通道、执行链码等）
    # 只需要通过enroll向ca服务端获取该用户身份的msp证书，然后使用该msp身份去执行操作。

    # 为每一个组织向CA服务端申请根证书，并保存到/${DATA}/orgs/${ORG}/msp
    # 如果ADMINCERTS为true，我们需要登记上述注册的身份（组织管理员）并将证书保存到/${DATA}/orgs/${ORG}/msp/admincerts
    # !!! 构建通道Artifacts需要获取组织的根证书，因为configtx.yaml文件中指定了组织的MSPDir !!!
    for ORG in $ORGS; do
        getCACerts $ORG
    done

    # 构建通道Artifacts（包括：创世区块、应用通道配置交易文件、锚节点配置更新交易文件）
    makeConfigTxYaml
    generateChannelArtifacts
    log "Finished building channel artifacts"
    log "Setup completed successfully"
    if [ $? -ne 0 ]; then
        fatal "Generate channel artifacts failed"
    fi

    done=true
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main