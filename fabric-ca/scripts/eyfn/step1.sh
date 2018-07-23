#!/bin/bash

# Copyright 凡派 All Rights Reserved.
#
# Apache-2.0
#
# 这个脚本在cli容器中运行
# 它创建并提交配置交易文件，以将新组织添加到现有的fabric网络的指定应用通道中。
# 此外，用于加入新组织的配置更新交易文件需要大多数组织的签名

# signConfigtxAsPeerOrg <org> <configtx.pb>
# 使用指定peer组织的管理员身份对配置更新交易文件签名
# 默认使用该组织的第一个peer节点
signConfigtxAsPeerOrg() {

    local ORG=$1 # 组织
    TX=$2 # 配置更新交易文件

    # 指定peer组织的管理员
    initPeerVars ${ORG} 1
    switchToAdminIdentity

    peer channel signconfigtx -f "${TX}"
}

set -e

source $(dirname "$0")/../env.sh

opts=0
while getopts "o:n:" opt; do
    case "$opt" in
        o)
            opts=$((opts+2))
            ORDERER_ORG=$OPTARG
            ;;
        n)
            opts=$((opts+2))
            ORDERER_NUM=$OPTARG
            ;;
    esac
done

shift $opts

if [ $# -ne 2 ]; then
    echo "Usage: ./step1.sh <-o <ORDERER_ORG>> <-n <ORDERER_NUM>> <CHANNEL_NAME> <NEW_ORG>"
    exit 1
fi

CHANNEL_NAME="$1" # 应用通道名称
NEW_ORG="$2" # 新加入的组织

echo
echo "========= Creating config transaction to add ${NEW_ORG} to network =========== "
echo

echo "Installing jq"

# 使用-y选项会在安装过程中使用默认设置，如果默认设置为N，那么就会选择N，而不会选择y。并没有让apt-get一直选择y的选项。
apt-get -y update && apt-get -y install jq

# 获取给定channel的配置区块，解码为json，并使用jq工具提取其中的完整的通道配置信息部分（.data.data[0].payload.data.config）保存到config.json文件中
fetchChannelConfig ${ORDERER_ORG} ${ORDERER_NUM} ${CHANNEL_NAME} config.json

# ##################修改配置添加新的组织##################
# config.json:原有组织配置;channel-artifacts/$NEW_ORG.json:新加入组织配置

# 在genChannelArtifacts一步中，$ORG.json保存在${SDIR}/${DATA}/channel-artifacts目录下
# cli容器通过volumes将${SDIR}/${DATA}/channel-artifacts目录挂载到了/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts目录
# 并通过working_dir设置工作目录为/opt/gopath/src/github.com/hyperledger/fabric/peer目录
# Usage: jq [options] <jq filter> [file...]
# --slurp/-s：读取所有输入到数组中; 并对它应用filter
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' config.json ./channel-artifacts/${NEW_ORG}.json > modified_config.json

# 根据config.json和modified_config.json之间的差异计算配置更新，将其作为交易写入$NEW_ORG_update_in_envelope.pb
createConfigUpdate ${CHANNEL_NAME} config.json modified_config.json ${NEW_ORG}_update_in_envelope.pb

echo
echo "========= Config transaction to add ${NEW_ORG} to network created ===== "
echo

echo "Signing config transaction"
echo

# IFS(Internal Field Seprator)
#   在bash中IFS是内部的域分隔符。IFS的默认值为：空白（包括：空格，tab, 和新行)，将其ASSII码用十六进制打印出来就是：20 09 0a
#
# read
#   -a:将内容读入到数组中
#   -r:在参数输入中，我们可以使用'\'表示没有输入完，换行继续输入，如果我们需要行最后的'\'作为有效的字符，可以通过-r来进行。此外在输入字符中，我们希望'\n'这类特殊字符生效，也应采用-r选项。
#   -n:用于限定最多可以有多少字符可以作为有效读入。例如read -n 4 value1 value2，如果我们试图输入12 34，则只有前面有效的12 3，作为输入，实际上在你输入第4个字符'3'后，就自动结束输入。这里结果是value1为12，value2为3。
# <<< 就是将后面的内容作为前面命令的标准输入
IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
NUM_PORGS=${#PORGS[@]}
NUM_PORGS=$((NUM_PORGS-1)) # 应该把当前要加入的新组织排除在外

# 使用已有组织管理员签名
COUNT=1
initOrdererVars $ORDERER_ORG $ORDERER_NUM
export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"
for ORG in $PEER_ORGS; do
    if [ "$COUNT" -eq $NUM_PORGS ]; then

        echo
        echo "========= Submitting transaction from a different peer $ORG which also signs it ========= "
        echo

        # 使用已有组织管理员签名
        initPeerVars ${ORG} 1
        switchToAdminIdentity

        # 将新组织添加到现有的fabric网络的指定应用通道中
        # 至此，新组织的管理员身份才可用

        peer channel update -f ${NEW_ORG}_update_in_envelope.pb -c ${CHANNEL_NAME} $ORDERER_CONN_ARGS

        break
    else
        echo "========= Sign transaction from a different peer $ORG ========= "
        # 使用已有组织管理员签名
        signConfigtxAsPeerOrg ${ORG} ${NEW_ORG}_update_in_envelope.pb
    fi
    COUNT=$((COUNT+1))
done

echo
echo "========= Config transaction to add ${NEW_ORG} to network submitted! =========== "
echo

exit 0