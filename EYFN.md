### 一、网络拓扑

通过`fabric.config`定义网络拓扑结构。

> 这里以新增org2为例

在构建fabric网络时所编写的`fabric.config`配置文件的基础上进行修改，增加新组织的配置：

`examples`示例中，`fabric_v2.config`在`fabric_v1.config`的基础上增加`org2`新组织。

### 二、构建项目，打包分发脚本

```bash
network_builder.sh [-e] <ORG>
            -e          动态增加组织
            <ORG>       新加入的组织
```

通过如下命令打包分发所需脚本：

```bash
./network_builder.sh -e org2
```

### 三、配置hosts

为了避免网络访问不同的情况，请确保及时更新每台服务器的`/etc/host`，内容参见`build/host.config`。

### 三、启动CA服务

##### (1). rca(root ca)

```bash
rca-bootstrap.sh [-e] <ORG>
            -e          新加入组织
```

```bash
./rca-bootstrap.sh -e org2
```

##### (2). ica(intermediate ca)

```bash
ica-bootstrap.sh [-e] <ORG>
            -e          新加入组织
```

```bash
./ica-bootstrap.sh -e org2
```

### 四、环境构建

```text
eyfn_builder.sh [-h] [-d] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <ORG>
            -h|-?               获取此帮助信息
            -d                  从网络下载二进制文件，默认false
            -c <NUM_PEERS>      加入的新Peer组织的peer节点数量，默认为fabric.config中配置的NUM_PEERS
            -o <ORDERER_ORG>    Orderer组织名称，默认为第一个Orderer组织
            -n <ORDERER_NUM>    Orderer节点的索引，默认值为1
            <ORG>               加入的新Peer组织的名称
```

* 脚本需要使用fabric的二进制文件`configtxgen`，请将这些二进制文件置于PATH路径下。
 
     如果脚本找不到，会基于[fabric源码](https://github.com/hyperledger/fabric)自动编译生成二进制文件，
     此时需要保证`$HOME/gopath/src/github.com/hyperledger/fabric`源码存在，且版本一致。
     
     当然你也可以通过指定`-d`选项从网络下载该二进制文件，这可能会很慢，取决于你的网速。

* ~~脚本需要使用fabric的二进制文件`fabric-ca-client`，请将该二进制文件置于PATH路径下。~~

     ~~如果脚本找不到，会基于[fabric ca源码](https://github.com/hyperledger/fabric-ca)自动编译生成二进制文件，
     此时需要保证`$HOME/gopath/src/github.com/hyperledger/fabric-ca`源码存在，且版本一致。~~
    
     ~~编译`fabric-ca`相关代码，需要一些依赖包，可以通过如下命令安装:~~
    
     ```bash
     sudo apt-get install libtool libltdl-dev
     ```
    
     ~~脚本会将编译生成的`fabric-ca-server`和`fabric-ca-client`保存在`$GOPATH/bin`目录下。~~
  
* 此外，你还需要配置当前节点所在服务器的`/etc/host`，内容参见`build/host.config`。
 
如果你执行完上述，那么来启动吧！~😍

> 由于`eyfn_builder.sh`脚本的一些操作需要较高的权限，请使用`root`用户运行。

```bash
./eyfn_builder.sh -c 5 -o org0 -n 1 org2
```

如果你看到如下日志，那么恭喜你，可以进行下一步了：

```text
##### 2018-07-23 17:16:32 Successfully build the environment needed to join the new organization
##### 2018-07-23 17:16:32 Now you can run the do-join script to start the new organization node.
```

### 五、启动Peer

```bash
eyfn-bootstrap.sh [-h] [-c <NUM_PEERS>] [-o <ORDERER_ORG>] [-n <ORDERER_NUM>] <NEW_ORG> <NUM>
    -h|-?               获取此帮助信息
    -c <NUM_PEERS>      加入的新Peer组织的peer节点数量，默认为fabric.config中配置的NUM_PEERS
    -o <ORDERER_ORG>    Orderer组织名称，默认为第一个Orderer组织
    -n <ORDERER_NUM>    Orderer节点的索引，默认值为1
    <NEW_ORG>           启动的新Peer组织的名称
    <NUM>               启动的新Peer组织的节点索引
```

> !!!注意：此步是基于上一步生成的证书文件来执行的，所以请确保正确的执行了上一步操作。

此外，上一步只需要执行一次即可，然后你就可以共享同一份`data`目录，通过修改`NUM`参数，在多台服务器上启动多个新组织的Peer节点。

```bash
./eyfn-bootstrap.sh -c 5 -o org0 -n 1  org2 1
```