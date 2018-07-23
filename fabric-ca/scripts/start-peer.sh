#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

# 获取组织管理员身份证书。如果存在，则不再登记，否则登记组织管理员身份
initPeerVars $ORG $NUM
getAdminCert $ORG_ADMIN_HOME $ORG_MSP_DIR

# Although a peer may use the same TLS key and certificate file for both inbound and outbound TLS,
# we generate a different key and certificate for inbound and outbound TLS simply to show that it is permissible
# 多次登记获取的tls证书是不一样的

# Generate server TLS cert and key pair for the peer
# 登记并获取peer节点的tls证书
# 使用peer节点身份登记，以获取peer的TLS证书(使用 "tls" profile)，并保存在/tmp/tls目录（以便将证书和私钥重命名为server.crt、server.key）下
# 将TLS私钥和证书拷贝到/opt/gopath/src/github.com/hyperledger/fabric/peer/tls目录下，并重命名为server.crt、server.key
getTLSCertKey $PEER_HOST $CORE_PEER_TLS_CERT_FILE $CORE_PEER_TLS_KEY_FILE

# Generate client TLS cert and key pair for the peer
# 登记并获取peer节点的tls证书
# /$DATA/tls/$PEER_NAME-client.crt
# /$DATA/tls/$PEER_NAME-client.key
getTLSCertKey $PEER_NAME $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE

# 使用peer节点身份登记，以再次获取peer的证书(使用默认 profile)，并保存在/opt/gopath/src/github.com/hyperledger/fabric/peer/msp目录（peer节点的身份MSP）下
# CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/msp
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $CORE_PEER_MSPCONFIGPATH
finishMSPSetup $CORE_PEER_MSPCONFIGPATH
copyAdminCert $CORE_PEER_MSPCONFIGPATH

# Start the peer
log "Starting peer '$CORE_PEER_ID' with MSP at '$CORE_PEER_MSPCONFIGPATH'"
env | grep CORE
peer node start