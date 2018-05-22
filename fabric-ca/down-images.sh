#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 下载fabric镜像

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

dockerCaPull() {

    local CA_TAG=$1
    echo "==> FABRIC CA IMAGE"
    echo
    for image in "" "-tools" "-orderer" "-peer"; do
        docker pull hyperledger/fabric-ca${image}:$CA_TAG
        docker tag hyperledger/fabric-ca${image}:$CA_TAG hyperledger/fabric-ca${image}
    done
}

dockerThirdPartyImagesPull() {
  local THIRDPARTY_TAG=$1
  for IMAGES in couchdb kafka zookeeper; do
      echo "==> THIRDPARTY DOCKER IMAGE: $IMAGES"
      echo
      docker pull hyperledger/fabric-$IMAGES:$THIRDPARTY_TAG
      docker tag hyperledger/fabric-$IMAGES:$THIRDPARTY_TAG hyperledger/fabric-$IMAGES
  done
}

echo "===> Pulling fabric ca Image"
dockerCaPull ${CA_TAG}

echo "===> Pulling thirdparty docker images"
dockerThirdPartyImagesPull ${THIRDPARTY_TAG}

echo "===> List out hyperledger docker images"
docker images | grep hyperledger*