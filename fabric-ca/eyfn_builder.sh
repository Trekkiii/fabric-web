#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 此脚本添加新组织到现有的fabric网络

set -e

# Obtain the OS and Architecture string that will be used to select the correct native binaries for your platform
OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

# 询问用户是否继续
function askProceed () {

    # -p 显示给用户的信息
    # ans 用户输入
    read -p "Continue? [Y/n] " ans
    case "$ans" in
        y|Y|"" )
            echo "proceeding ..."
            ;;
        n|N )
            echo "exiting..."
            exit 1
            ;;
        * )
            echo "invalid response"
            askProceed
            ;;
    esac
}

function printHelp {

    cat << EOF
    使用方法:
        eyfn_builder.sh [-h] [-d] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <NEW_ORG>
            -h|-?               获取此帮助信息
            -d                  从网络下载二进制文件，默认false
            -c <NUM_PEERS>      加入的新Peer组织的peer节点数量，默认为fabric.config中配置的NUM_PEERS
            -o <ORDERER_ORG>    Orderer组织名称，默认为第一个Orderer组织
            -n <ORDERER_NUM>    Orderer节点的索引，默认值为1
            <NEW_ORG>               加入的新Peer组织的名称
EOF
}

# printOrg
function printOrg {

    echo "
    - &$ORG_CONTAINER_NAME
        Name: $NEW_ORG
        # MSP的ID
        ID: $ORG_MSP_ID
        # MSP相关文件所在路径，${SDIR}/${DATA}/orgs/${NEW_ORG}/msp
        MSPDir: ${SDIR}$ORG_MSP_DIR
    "
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

function makeConfigTxYaml {

    log "Generating configtx.yaml at ${SDIR}/${DATA}/channel-artifacts/configtx.yaml"

    {
        echo "################################################################################
#
#   Section: Organizations
#
#   - This section defines the different organizational identities which will
#   be referenced later in the configuration.
#
################################################################################
Organizations:"
        printPeerOrg $NEW_ORG 1 # 将新组织的第一个节点定义为锚节点
    } > ${SDIR}/configtx.yaml
}

function genCerts () {

    log "========= 从远程CA服务端获取所有Peer组织的TLS CAChain证书 ========="
    # 1. 从远程CA服务端获取所有Peer组织的TLS CAChain证书，以执行：
    #       新组织：
    #               向新组织的CA服务端登记CA管理员身份，切换到CA管理员身份，以拥有足够的权限来进行注册新Peer组织相关的用户实体（step0）
    #       原有组织：
    #               用于更新应用通道（step1 - fetchChannelConfig => getTLSCertKey）
    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        # 从远程CA服务端获取CAChain证书
        fetchCAChain $ORG $CA_CHAINFILE
    done

    # 2. 从远程CA服务端获取Orderer组织的TLS CAChain证书
    #       以执行连接orderer节点获取配置区块和创世区块时使用（step1 - peer channel fetch config；step2 - peer channel fetch 0）
    log "========= 从远程CA服务端获取Orderer组织的TLS CAChain证书 ========="
    initOrgVars $ORDERER_ORG
    fetchCAChain $ORDERER_ORG $CA_CHAINFILE

    # 3. 从'setup'节点获取所有原有Peer组织的Admin
    #       以便**获取原有Peer组织的Admin身份证书和密钥**，以执行：
    #               (1)使用第一个Peer组织的**管理员身份**获取配置区块（step1 - peer channel fetch config）；
    #               (2)使用所有原有组织**管理员身份**对配置更新文件进行签名（step1 - peer channel signconfigtx）；
    log "========= 获取所有原有Peer组织的Admin ========="
    # TODO !!! 注意：如果使用fabric-ca-client enroll重新登记原组织的Admin身份，会报以下错误：
    # Error: got unexpected status: BAD_REQUEST -- error authorizing update: error validating DeltaSet: policy for [Group]  /Channel/Application not satisfied: Failed to reach implicit threshold of 1 sub-policies, required 1 remaining
    # Usage:
    #   peer channel update [flags]
    ORIGIN_PEER_ORGS=${PEER_ORGS% *}
    for ORG in $ORIGIN_PEER_ORGS; do
        fetchOrgAdmin $ORG # TODO 从peer节点获取，而不是从setup节点
    done

    # 4. 向新组织的CA服务端登记CA管理员身份，注册新Peer组织相关的用户实体；
    # 5. 获取新Peer组织的MSP根证书，因为configtx.yaml文件中指定了组织的MSPDir；
    docker exec cli /scripts/eyfn/step0.sh ${NEW_ORG}
    res=$?
    if [ $res -ne 0 ]; then
        echo "ERROR !!!! Unable to register the user entity associated with the new Peer organization and obtain the MSP root certificate for the new Peer organization"
        docker logs -f cli
        exit 1
    fi

}

# 生成新组织的配置文件
function genChannelArtifacts() {

    set +e
    which configtxgen
    rs=$?
    set -e
    if [ "$rs" -ne 0 ]; then
        echo "Configtxgen tool not found. exiting"
        exit 1
    fi

    echo "##########################################################"
    echo "                 生成组织${NEW_ORG}配置文件                   "
    echo "##########################################################"

    # 设置FABRIC_CFG_PATH环境变量告诉configtxgen去哪个目录寻找configtx.yaml文件
    export FABRIC_CFG_PATH=${SDIR}

    # -printOrg string：将组织的定义显示为JSON（可用于手动添加组织到通道）
    # 将新组织的配置保存到${NEW_ORG}.json
    initOrgVars $NEW_ORG
    configtxgen -printOrg $NEW_ORG > ${SDIR}/${DATA}/channel-artifacts/$NEW_ORG.json
    res=$?
    if [ $res -ne 0 ]; then
        echo "ERROR !!!! Failed to generate ${NEW_ORG} config material..."
        exit 1
    fi
}

# 使用CLI容器创建配置交易文件，以用来添加Org3到fabric网络中
function createConfigTx () {

    echo
    echo "###############################################################"
    echo "       Generate and submit config tx to add ${NEW_ORG}             "
    echo "###############################################################"

    # 它创建并提交配置交易文件，以将新组织添加到现有的fabric网络的指定应用通道中。
    # 此外，用于加入新组织的配置更新交易文件需要大多数组织的签名
    docker exec cli /scripts/eyfn/step1.sh -o ${ORDERER_ORG} -n ${ORDERER_NUM} ${CHANNEL_NAME} ${NEW_ORG}
    res=$?
    if [ $res -ne 0 ]; then
        echo "ERROR !!!! Unable to Create and submit a configuration transaction file to add the new organization to the specified application channel of the existing fabric network"
        docker logs -f cli
        exit 1
    fi
}

function preJoin () {

    # 从远程CA服务端获取CAChain证书，以及新组织的MSP身份证书
    genCerts

    # 生成新组织的配置文件
    makeConfigTxYaml
    genChannelArtifacts

    # 使用cli容器创建配置交易文件，以用来添加新组织到fabric网络中
    createConfigTx

    log "Successfully build the environment needed to join the new organization"
    log "Now you can run the do-join script to start the new organization node."
}

# getopts option_string variable
#
# 当optstring以”:”开头时，getopts会区分invalid option错误和miss option argument错误。
# invalid option时，varname会被设成?，$OPTARG是出问题的option；
# miss option argument时，varname会被设成:，$OPTARG是出问题的option。
# 如果optstring不以”:”开头，invalid option错误和miss option argument错误都会使varname被设成?，$OPTARG是出问题的option。
opts=0
while getopts "hdc:o:n:" opt; do
    case "$opt" in
        h)
            printHelp
            exit 0
            ;;
        d)
            opts=$((opts+1))
            DOWN_REMOTE_BIN=true
            ;;
        c)
            opts=$((opts+2))
            NUM_PEERS=$OPTARG
            # 对NUM_PEERS类型进行校验
            expr $NUM_PEERS + 0 >& /dev/null
            if [ $? -ne 0 ]; then
                fatal "The -$opt $OPTARG should be integer"
            fi
            ;;
        o)
            opts=$((opts+2))
            ORDERER_ORG=$OPTARG
            ;;
        n)
            opts=$((opts+2))
            ORDERER_NUM=$OPTARG
            ;;
        \?)
            fatal "Invalid option: -$opt $OPTARG"
    esac
done

shift $opts

: ${DOWN_REMOTE_BIN:="false"}
# 默认第一个Orderer组织的第一个节点
IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
: ${ORDERER_ORG:="${OORGS[0]}"}
: ${ORDERER_NUM:="1"}

if [ $# -ne 1 ]; then
    echo "Usage: ./eyfn_builder.sh [-h] [-d] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <NEW_ORG>"
    exit 1
fi

if [ $(whoami) != "root" ]; then
    log "Please use root to execute this sh"
    exit 1
fi

NEW_ORG=$1

# 刷新DATA区域
refreshData

# 删除cli容器
set +e
docker rm -f cli
set -e

# 下载安装二进制工具
set +e
which configtxgen
rs=$?
set -e
if [ "$rs" -ne 0 ]; then
    binariesInstall $DOWN_REMOTE_BIN
fi

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

echo "Prepare for join network with channel '${CHANNEL_NAME}' and using database couchdb"

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh -e $NEW_ORG $NUM_PEERS

docker-compose up -d --no-deps cli
res=$?
if [ $res -ne 0 ]; then
    echo "ERROR !!!! Cli container failed to start"
    docker logs -f cli
    exit 1
fi

preJoin