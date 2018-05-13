#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0

set -e

source $(dirname "$0")/env.sh

# 等待所有orderers和peers节点启动
function waitAllOrderersAndPeers {

    for ORG in $ORDERER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            initOrdererVars $ORG $COUNT

            # Usage: waitPort <what> <timeoutInSecs> <errorLogFile|doc> <host> <port>
            waitPort "Orderer orderer${NUM}-${ORG} to start" 60 $ORDERER_LOGFILE $ORDERER_HOST 7050

            COUNT=$((COUNT+1))
        done
    done

    for ORG in $PEER_ORGS; do
        COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT

            # Usage: waitPort <what> <timeoutInSecs> <errorLogFile|doc> <host> <port>
            waitPort "Peer peer${NUM}-${ORG} to start" 60 $PEER_LOGFILE $PEER_HOST 7051

            COUNT=$((COUNT+1))
        done
    done
}

function finish {

    if [ "$done" = true ]; then
        logr "See $RUN_LOGFILE for more details"
        touch /$RUN_SUCCESS_FILE
    else
        logr "Tests did not complete successfully; see $RUN_LOGFILE for more details"
        touch /$RUN_FAIL_FILE
    fi
}

# 切换到第一个peer组织的管理员身份，然后创建应用通道。
function createChannel {

    # 切换到第一个peer组织的管理员身份。如果之前没有登记，则登记。
    # 这里使用initPeerVars方法对ORDERER_CONN_ARGS进行初始化，以指定keyfile私钥、certfile证书文件参数
    initPeerVars ${PORGS[0]} 1
    switchToAdminIdentity

    logr "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ..."

    peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS
}

# 切换到peer组织的管理员身份，然后加入应用通道
function joinChannel {

    switchToAdminIdentity

    set +e

    local COUNT=1
    MAX_RETRY=10

    while true; do
        logr "Peer $PEER_HOST is attempting to join channel '$CHANNEL_NAME' (attempt #${COUNT}) ..."
        peer channel join -b $CHANNEL_NAME.block
        if [ $? -eq 0 ]; then
            set -e
            logr "Peer $PEER_HOST successfully joined channel '$CHANNEL_NAME'"
            return
        fi
        if [ $COUNT -gt $MAX_RETRY ]; then
            fatalr "Peer $PEER_HOST failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
        fi
        COUNT=$((COUNT+1))
        sleep 1
    done
}

# 切换到peer组织的管理员身份，然后安装链码
function installChaincode {

    switchToAdminIdentity
    logr "Installing chaincode on $PEER_HOST ..."
    peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-web/chaincode/go/abac
}

# 链码实例化策略
function makePolicy {

    # NAME=liucl
    # echo "My Name is '${NAME}'" -> My Name is 'liucl'
    # echo My Name is '${NAME}' -> My Name is ${NAME}

    POLICY="OR("
    local COUNT=0

    for ORG in $PEER_ORGS; do
        if [ $COUNT -ne 0 ]; then
            POLICY="${POLICY}," # 拼接逗号
        fi

        initOrgVars $ORG
        POLICY="${POLICY}'${ORG_MSP_ID}.member'"
        COUNT=$((COUNT+1))
    done

    POLICY="${POLICY})"
    log "policy: $POLICY"
}

function chaincodeQuery {

    if [ $# -ne 1 ]; then
        fatalr "Usage: chaincodeQuery <expected-value>"
    fi

    set +e

    logr "Querying chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' ..."

    local rc=1
    local starttime=$(date +%s)

    # Continue to poll until we get a successful response or reach QUERY_TIMEOUT
    while test "$(($(date +%s)-starttime))" -lt "$QUERY_TIMEOUT"; do
        sleep 1
        peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >& log.txt
        VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
        if [ $? -eq 0 -a "$VALUE" = "$1" ]; then
            logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
            set -e
            return 0
        fi
        echo -n "."
    done

    cat log.txt
    cat log.txt >> $RUN_SUMFILE
    fatalr "Failed to query channel '$CHANNEL_NAME' on peer '$PEER_HOST'; expected value was $1 and found $VALUE"
}

function main {

    done=false # 标记是否执行完成所有以下操作

    # 等待所有orderers和peers节点启动
    waitAllOrderersAndPeers

    # trap 捕获信号
    # 在终端一个shell程序的执行过程中，当你按下 Ctrl + C 键或 Break 键，正常程序将立即终止，并返回命令提示符。这可能并不总是可取的。例如，你可能最终留下了一堆临时文件，将不会清理。
    # 捕获这些信号是很容易的，trap命令的语法如下：trap commands signals
    trap finish EXIT

    mkdir -p $LOGPATH
    logr "The docker 'run' container has started"

    # IFS
    #   在bash中IFS是内部的域分隔符。IFS的默认值为：空白（包括：空格，tab, 和新行)，将其ASSII码用十六进制打印出来就是：20 09 0a
    #
    # read
    #   -a:将内容读入到数组中
    #   -r:在参数输入中，我们可以使用’\’表示没有输入完，换行继续输入，如果我们需要行最后的’\’作为有效的字符，可以通过-r来进行。此外在输入字符中，我们希望\n这类特殊字符生效，也应采用-r选项。
    #   -n:用于限定最多可以有多少字符可以作为有效读入。例如read –n 4 value1 value2，如果我们试图输入12 34，则只有前面有效的12 3，作为输入，实际上在你输入第4个字符'3'后，就自动结束输入。这里结果是value为12，value2为3。
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"

    # 将 ORDERER_PORT_ARGS 设置为与第一个orderer组织的第一个orderer节点进行通信所需的参数
    initOrdererVars ${OORGS[0]} 1
    # 连接Orderer端点的连接属性
    #       -o, --orderer string    Orderer服务地址
    #       --tls    在与Orderer端点通信时使用TLS
    #       --cafile string     Orderer节点的TLS证书，PEM格式编码，启用TLS时有效
    #       --clientauth    是否启用客户端验证
    #       --certfile string    Peer节点的PEM编码的X509公钥文件(代表peer节点身份)，用于客户端验证
    #       --keyfile string    Peer节点的PEM编码的私钥文件(代表peer节点身份)，用于客户端验证
    export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

    # 将PEER_ORGS转换成PORGS数组变量
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"

    # 切换到第一个peer组织的管理员身份，然后创建应用通道。
    createChannel

    # 所有peer节点加入应用通道
    for ORG in $PEER_ORGS; do
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            # 切换到peer组织的管理员身份，然后加入应用通道
            joinChannel
            COUNT=$((COUNT+1))
        done
    done

    # 为每个peer组织更新锚节点
    for ORG in $PEER_ORGS; do
        initPeerVars $ORG 1
        switchToAdminIdentity
        logr "Updating anchor peers for $PEER_HOST ..."
        peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
    done

    # 所有peer节点上安装链码
    for ORG in $PEER_ORGS; do
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            initPeerVars $ORG $COUNT
            # 切换到peer组织的管理员身份，然后安装链码
            installChaincode
            COUNT=$((COUNT+1))
        done
    done

    # 在第二个Peer组织的第一个peer节点上实例化链码
    makePolicy
    initPeerVars ${PORGS[1]} 1
    switchToAdminIdentity
    logr "Instantiating chaincode on $PEER_HOST ..."
    peer chaincode instantiate -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "$POLICY" $ORDERER_CONN_ARGS

    # 在第一个Peer组织的第一个peer节点上查询链码
    initPeerVars ${PORGS[0]} 1
    switchToUserIdentity
    chaincodeQuery 100

    # 在第一个Peer组织的第一个peer节点上调用链码
    initPeerVars ${PORGS[0]} 1
    switchToUserIdentity
    logr "Sending invoke transaction to $PEER_HOST ..."
    peer chaincode invoke -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS

    # 在第二个Peer组织的第二个peer节点上查询链码
    sleep 10
    initPeerVars ${PORGS[1]} 2
    switchToUserIdentity
    chaincodeQuery 90

}

function logr {
   log $*
   log $* >> $RUN_SUMPATH
}

function fatalr {
   logr "FATAL: $*"
   exit 1
}

main