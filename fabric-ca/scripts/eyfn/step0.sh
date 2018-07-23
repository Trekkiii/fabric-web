#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 这个脚本在cli容器中运行
# 1. 向CA服务端登记CA管理员身份，注册新Peer组织相关的用户实体
# 2. 获取新Peer组织的MSP根证书
# 3. 登记并获取peer节点的tls证书

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

# 登记CA管理员，FABRIC_CA_CLIENT_HOME指向CA管理员msp
# 以便后面使用CA管理员身份去注册peer相关用户实体
function enrollCAAdmin {

    # 等待，直至CA服务可用
    waitPort "$CA_NAME to start" 90 $CA_LOGFILE $CA_HOST 7054
    log "Enrolling with $CA_NAME as bootstrap identity ..."

    # fabric-ca-client主配置目录
    # fabric-ca-client会在该目录下搜索配置文件，
    # 同样，也会在该目录下生成fabric-ca-client-config.yaml文件以及创建msp目录存放身份证书文件
    export FABRIC_CA_CLIENT_HOME=/$DATA/cas/$CA_NAME

    # 向CA服务端登记CA管理员身份、注册Peer相关的用户实体时使用
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

    # 使用初始化CA时指定的用户名和密码来登记CA管理员身份
    fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
}

# 注册与Peer相关的用户实体（peer组织的管理员用户、peer组织的普通用户）
function registerPeerIdentities {

    initOrgVars $NEW_ORG

    # !!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!
    # 登记CA管理员，'FABRIC_CA_CLIENT_HOME'指向CA管理员msp
    enrollCAAdmin

    set +e
    local COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        initPeerVars $NEW_ORG $COUNT
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
}

set -e

source $(dirname "$0")/../env.sh

if [ $# -ne 1 ]; then
    echo "Usage: ./step0.sh <NEW_ORG>"
    exit 1
fi

NEW_ORG="$1" # 新加入的组织

log "========= 向CA服务端登记CA管理员身份，注册新Peer组织相关的用户实体 ========="
registerPeerIdentities

log "========= 获取新Peer组织的MSP根证书 ========="
# !!! 构建通道Artifacts需要获取组织的根证书，因为configtx.yaml文件中指定了组织的MSPDir !!!
getCACerts $NEW_ORG