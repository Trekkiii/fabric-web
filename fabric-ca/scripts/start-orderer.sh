#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#

function finish {

    if [ "$done" = true ]; then
        log "See $ORDERER_LOGFILE for more details"
        touch /$ORDERER_SUCCESS_FILE
    else
        log "Tests did not complete successfully; see $ORDERER_LOGFILE for more details"
        touch /$ORDERER_FAIL_FILE
    fi
}

set -e

done=false # 标记是否执行完成所有以下操作
trap finish EXIT

source $(dirname "$0")/env.sh

# 登记并获取orderer节点的tls证书
# 使用orderer节点身份登记，以获取orderer的TLS证书(使用 "tls" profile)，并保存在/tmp/tls目录（以便将证书和私钥重命名为server.crt、server.key）下
# ENROLLMENT_URL=https://$ORDERER_NAME_PASS@$CA_HOST:7054
fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $ORDERER_HOST
# 将TLS私钥和证书拷贝到/etc/hyperledger/orderer/tls目录下，并重命名为server.crt、server.key
TLSDIR=$ORDERER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/keystore/* $ORDERER_GENERAL_TLS_PRIVATEKEY # /etc/hyperledger/orderer/tls/server.key
cp /tmp/tls/signcerts/* $ORDERER_GENERAL_TLS_CERTIFICATE # /etc/hyperledger/orderer/tls/server.crt
rm -rf /tmp/tls

# 使用orderer节点身份登记，以再次获取orderer的证书(使用默认 profile)，并保存在/etc/hyperledger/orderer/msp目录（orderer节点的身份MSP）下
# ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR

# Finish setting up the local MSP for the orderer
finishMSPSetup $ORDERER_GENERAL_LOCALMSPDIR
copyAdminCert $ORDERER_GENERAL_LOCALMSPDIR

# 等待创世区块生成
dowait "genesis block to be created" 60 $SETUP_LOGFILE $ORDERER_GENERAL_GENESISFILE

# 启动orderer
env | grep ORDERER
orderer

done=true