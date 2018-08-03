#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 查询链码

set -e

source $(dirname "$0")/env.sh

initOrdererVars org0 1
export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

initPeerVars org2 1
switchToUserIdentity

peer chaincode invoke -C mychannel -n mycc -c '{"Args":["select", "a"]}'
