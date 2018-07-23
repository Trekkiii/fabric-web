#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 启动Zookeeper 和 Kafka

# 遇到错误退出
set -e

START_ZOOKEEPER=false
START_KAFKA=false

function printHelp {

cat << EOF
    使用方法:
        zk-kafka-bootstrap.sh <-z|-k> <ID>
            -h|-?       获取此帮助信息
            -z          启动zookeeper节点
            -k          启动kafka节点
            <ID>        节点的编号
EOF
}

while getopts "hzk" opt; do
    case "$opt" in
        h|\?)
            printHelp
            exit 0
            ;;
        z)
            START_ZOOKEEPER=true
            shift 1
            ;;
        k)
            START_KAFKA=true
            shift 1
            ;;
    esac
done

if [ $# -ne 1 ]; then
    echo "Usage: ./zk-kafka-bootstrap.sh [-z] [-k] <ID>"
    exit 1
fi

ID=$1

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh
cd ${SDIR}

# 创建docker-compose.yml文件
${SDIR}/makeDocker.sh

if ${START_ZOOKEEPER}; then
    initZKVars $ID
    # 启动zookeeper
    log "Creating docker containers $ZK_NAME ..."
    docker-compose up -d --no-deps $ZK_NAME

    docker logs -f $ZK_NAME
elif ${START_KAFKA}; then
    initKafkaVars $ID
    # 启动kafka
    log "Creating docker containers $KAFKA_NAME ..."
    docker-compose up -d --no-deps $KAFKA_NAME

    docker logs -f $KAFKA_NAME
fi