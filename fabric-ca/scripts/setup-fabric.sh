#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 此脚本执行以下操作：
#   1) 向中间层fabric-ca-servers注册Orderer和Peer身份

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

        local COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT
            log "Registering $ORDERER_NAME with $CA_NAME"
            # 注册当前orderer节点用户
            fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
            COUNT=$((COUNT+1))
        done

        log "Registering admin identity with $CA_NAME"
        # The admin identity has the "admin" attribute which is added to ECert by default
        # 注册orderer组织的管理员用户
        fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
    done
}

# 注册与Peer相关的所有用户实体（所有peer节点用户、peer组织的管理员用户、peer组织的普通用户）
function registerPeerIdentities {

    for ORG in $PEER_ORGS; do

        initOrgVars $ORG

        # !!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!
        # 登记CA管理员，'FABRIC_CA_CLIENT_HOME'指向CA管理员msp
        enrollCAAdmin

        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            log "Registering $PEER_NAME with $CA_NAME"
            # 注册当前peer节点用户
            fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer
            COUNT=$((COUNT+1))
        done

        log "Registering admin identity with $CA_NAME"
        # The admin identity has the "admin" attribute which is added to ECert by default
        # 注册peer组织的管理员用户
        fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
        log "Registering user identity with $CA_NAME"
        # 注册peer组织的普通用户
        fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS
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

    # 使用初始化中间层CA指定的用户名和密码来登记CA管理员身份
    fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
}

function main {

    log "Beginning building channel artifacts ..."
    # 注册与Orderer和Peer相关的所有用户身份
    # !!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!
    registerIdentities

    # !!! 至此，我们注册了所有所需的用户身份，如果需要使用相应的用户身份操作fabric网络（e.g 加入创建应用通道、执行链码等）
    # 只需要通过enroll向ca服务端获取该用户身份的msp证书，然后使用该msp身份去执行操作。

    touch /$SETUP_SUCCESS_FILE # 生成setup.successful文件，标记'setup'容器成功执行完所有操作
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main