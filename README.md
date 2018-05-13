# fabric-ca

## 使用步骤

请使用如下命令为脚本增加执行权限：

```bash
root@vm10-249-0-4:~/fabric-web/fabric-ca# chmod +x *.sh
root@vm10-249-0-4:~/fabric-web/fabric-ca# 
root@vm10-249-0-4:~/fabric-web/fabric-ca# 
root@vm10-249-0-4:~/fabric-web/fabric-ca# chmod +x scripts/*.sh
```

### 1.构建项目，为不同节点打包脚本

```bash
./network_builder.sh
```

再正式开始前，确保你已经正确完成下列步骤执行：

- 将`build`目录下生成的文件分别拷贝到相应节点的***`fabric.config`配置中指定的用户***目录下，并且将其所有者设置为***`fabric.config`配置中指定的用户***

- 将`host.config`文件中的内容追加到每个节点的`host`

- 每个节点都已下载所需的fabric镜像

    可执行如下命令下载镜像
    
    ```bash
    ./down-images.sh
    ```

### 2.启动CA服务

对于每一个组织都要启动一个rca和ica服务。

##### 2.1. rca(root ca)

一个组织对应一个***root fabric-ca-server***

启动指定组织`<ORG>`的***root fabric-ca-server***命令如下

```bash
./rca-bootstrap.sh <ORG>
```

root CA 初始化时在`/etc/hyperledger/fabric-ca`目录下生成`ca-cert.pem`证书，并将其拷贝为`/${DATA}/${ORG}-ca-cert.pem`。

##### 2.2. ica(intermediate ca)

一个组织对应一个***intermediate fabric-ca-server***

启动指定组织`<ORG>`的***intermediate fabric-ca-server***命令如下

```bash
./ica-bootstrap.sh <ORG>
```

intermediate CA 初始化时在`/etc/hyperledger/fabric-ca`目录下生成`ca-chain.pem`证书，并将其拷贝为`/${DATA}/${ORG}-ca-chain.pem`。

>其它节点下列操作需要使用rca(`USE_INTERMEDIATE_CA`为`false`时)或者ica(`USE_INTERMEDIATE_CA`为true`时)根证书
>
>- 向CA服务端申请根证书时使用;
>- 向CA服务端登记CA管理员身份时使用;
>    
>    之所以*登记CA管理员身份*，是因为需要使用CA管理员身份去注册orderer和peer相关用户实体。
>    
>    ***!!! 执行注册新用户实体的客户端必须已经通过登记认证，并且拥有足够的权限来进行注册 !!!***
>
>- 向CA服务端登记***Orderer组织管理员身份和Peer组织管理员身份***、***Orderer节点身份和Peer节点身份***，以及***Peer组织普通用户身份***时使用;

因此，

- `USE_INTERMEDIATE_CA`为`false`，即未启用中间层CA时，**_需要将`/etc/hyperledger/fabric-ca/ca-cert.pem`拷贝到其它节点作为`CA_CHAINFILE`_**；
- `USE_INTERMEDIATE_CA`为`true`，即启用中间层CA时，**_需要将`/etc/hyperledger/fabric-ca/ca-chain.pem`拷贝到其它节点作为`CA_CHAINFILE`_**;

不必担心，这些工作脚本已经帮我们完成了！~ :laughing: 

原理是其它节点通过ssh远程拷贝ca上的根证书，但这需要你在执行的过程中输入对应CA服务器的密码，如果你想避免这一步骤，可以考虑配置ssh免登陆。 

> 💡 !!!确保:
> - CA服务端开启22端口；
> - CA服务端的DATA目录的所有者为`fabric.config`中的`CA.UNAME`，否则无法远程获取上述证书；

### 3. 启动setup

setup容器用于向中间层fabric-ca-servers注册Orderer和Peer身份

启动命令如下：

```bash
./setup-bootstrap.sh
```

### 4. 启动orderer

```text
orderer-bootstrap.sh [-h] [-?] <ORG> <NUM>
    -h|-?  - 获取此帮助信息
    <ORG>   - 启动的orderer组织名称
    <NUM>   - 启动的orderer组织的第几个节点
```

```bash
./orderer-bootstrap.sh <ORG> <NUM>
```

### 5. 启动peer

```text
peer-bootstrap.sh [-h] [-?] <ORG> <NUM>
    -h|-?  - 获取此帮助信息
    <ORG>   - 启动的peer组织的名称
    <NUM>   - 启动的peer组织的节点索引
```

```bash
./peer-bootstrap.sh <ORG> <NUM>
```

### 6. 启动run

```bash
./run-bootstrap.sh
```

## TODO

- 每个节点执行`down-images.sh`脚本，只下载该节点必须的fabric镜像

## FAQ

### 证书对比

💡 使用`diff`你会发现，`/data/org1-ca-cert.pem`（`fabric-ca-server init` root CA初始化生成的证书）
与`/data/orgs/org1/msp/cacerts/ica-org1-7054.pem`（`fabric-ca-client getcacert` 向CA服务端为组织申请根证书所返回的证书链(CAChain)的第一个证书）是同一个证书文件。
同样的，org1组织的peer1节点下`/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/cacerts/ica-org1-7054.pem`（`fabric-ca-client enroll` 登记peer节点身份获取peer节点身份证书）证书文件也与之相同。

```bash
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/cacerts# diff /root/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/org1-ca-cert.pem /root/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/cacerts/ica-org1-7054.pem 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/cacerts# 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/cacerts# 

# 将peer1-org1节点下/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/cacerts/ica-org1-7054.pem文件拷贝为peerMsp/ica-org1-7054.pem
# 然后将其与/data/org1-ca-cert.pem比较
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# mkdir peerMsp
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# ll
total 40
drwx------ 10 root root 4096 May 10 23:54 ./
drwx------  4 root root 4096 May  9 11:12 ../
drwxr-xr-x  2 root root 4096 May  9 11:12 admincerts/
drwxr-xr-x  2 root root 4096 May  9 11:12 cacerts/
drwxr-xr-x  2 root root 4096 May  9 11:12 intermediatecerts/
drwx------  2 root root 4096 May  9 11:12 keystore/
drwxr-xr-x  2 root root 4096 May 10 23:54 peerMsp/
drwxr-xr-x  2 root root 4096 May  9 11:12 signcerts/
drwxr-xr-x  2 root root 4096 May  9 11:12 tlscacerts/
drwxr-xr-x  2 root root 4096 May  9 11:12 tlsintermediatecerts/
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# docker ps
CONTAINER ID        IMAGE                                                                                      COMMAND                  CREATED             STATUS              PORTS               NAMES
86cee48f984f        dev-peer2-org2-mycc-1.0-ecac5550a3036994766397ac6b43d7a7a5555cbd037fd36e290d0153bba6526a   "chaincode -peer.add…"   37 hours ago        Up 37 hours                             dev-peer2-org2-mycc-1.0
98d57c15f806        dev-peer1-org1-mycc-1.0-6197b07806b619d1c3d8fe1cf7cbbc1bf22dbb309b8bcb2713e34545de6965ba   "chaincode -peer.add…"   37 hours ago        Up 37 hours                             dev-peer1-org1-mycc-1.0
0e9fb63d0a2b        dev-peer1-org2-mycc-1.0-c4f6f043734789c3ff39ba10d25a5bf4bb7da6be12264d48747f9a1ab751e9fe   "chaincode -peer.add…"   37 hours ago        Up 37 hours                             dev-peer1-org2-mycc-1.0
367a17d54e53        hyperledger/fabric-ca-peer                                                                 "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours                             peer2-org2
5b2fb89302d8        hyperledger/fabric-ca-peer                                                                 "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours                             peer2-org1
821c8933782a        hyperledger/fabric-ca-peer                                                                 "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours                             peer1-org1
4acf714e3b81        hyperledger/fabric-ca-orderer                                                              "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7050/tcp            orderer1-org0
803c44136ab0        hyperledger/fabric-ca-peer                                                                 "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours                             peer1-org2
1a6c89010fa9        hyperledger/fabric-ca                                                                      "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7054/tcp            ica-org0
76c0c58e652e        hyperledger/fabric-ca                                                                      "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7054/tcp            ica-org1
2a9e6f4109c8        hyperledger/fabric-ca                                                                      "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7054/tcp            ica-org2
cb82cbe099e5        hyperledger/fabric-ca                                                                      "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7054/tcp            rca-org0
c41f819ad8a8        hyperledger/fabric-ca                                                                      "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7054/tcp            rca-org1
b314c45774b2        hyperledger/fabric-ca                                                                      "/bin/bash -c '/scri…"   37 hours ago        Up 37 hours         7054/tcp            rca-org2
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# docker cp 821c8933782a:/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/cacerts/ica-org1-7054.pem peerMsp/ica-org1-7054.pem
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp# cd peerMsp/
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/peerMsp# 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/peerMsp# ll
total 12
drwxr-xr-x  2 root root 4096 May 10 23:58 ./
drwx------ 10 root root 4096 May 10 23:54 ../
-rw-r--r--  1 root root  761 May  9 11:12 ica-org1-7054.pem
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/peerMsp# diff /root/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/org1-ca-cert.pem ica-org1-7054.pem
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data/orgs/org1/msp/peerMsp# 
```

```text
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data# cat org1-ca-cert.pem
-----BEGIN CERTIFICATE-----
MIICBjCCAa2gAwIBAgIUEsuR5CLvaUYA3beogtNkchwjmDEwCgYIKoZIzj0EAwIw
YDELMAkGA1UEBhMCVVMxFzAVBgNVBAgTDk5vcnRoIENhcm9saW5hMRQwEgYDVQQK
EwtIeXBlcmxlZGdlcjEPMA0GA1UECxMGRmFicmljMREwDwYDVQQDEwhyY2Etb3Jn
MTAeFw0xODA1MDkwMzA3MDBaFw0zMzA1MDUwMzA3MDBaMGAxCzAJBgNVBAYTAlVT
MRcwFQYDVQQIEw5Ob3J0aCBDYXJvbGluYTEUMBIGA1UEChMLSHlwZXJsZWRnZXIx
DzANBgNVBAsTBkZhYnJpYzERMA8GA1UEAxMIcmNhLW9yZzEwWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAARKy2OQzzAbFPdvDGPr5Ba70et40yLUCNVt/Pf/SNS0Zj1N
IJoONT7Yd4c1p9ODDNtoblSIi+JK9W096TMhNaVLo0UwQzAOBgNVHQ8BAf8EBAMC
AQYwEgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQUmFr/+27LrHM6F8Pk/ZA/
NnTbtVUwCgYIKoZIzj0EAwIDRwAwRAIgNAm7GlMOevpvuHoQxCmADn/biM73Fm2U
CZ6EbpIZdawCIEFwHGOE2+68jMe7IDa+ZqRCL29Ha+B83Hp/Ng7b5/4M
-----END CERTIFICATE-----
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data# cat org1-ca-chain.pem 
-----BEGIN CERTIFICATE-----
MIICLjCCAdSgAwIBAgIULEd+HyPce73eHsGbKEPWr/MsB2owCgYIKoZIzj0EAwIw
YDELMAkGA1UEBhMCVVMxFzAVBgNVBAgTDk5vcnRoIENhcm9saW5hMRQwEgYDVQQK
EwtIeXBlcmxlZGdlcjEPMA0GA1UECxMGRmFicmljMREwDwYDVQQDEwhyY2Etb3Jn
MTAeFw0xODA1MDkwMzA3MDBaFw0yMzA1MDgwMzEyMDBaMGYxCzAJBgNVBAYTAlVT
MRcwFQYDVQQIEw5Ob3J0aCBDYXJvbGluYTEUMBIGA1UEChMLSHlwZXJsZWRnZXIx
DzANBgNVBAsTBmNsaWVudDEXMBUGA1UEAxMOcmNhLW9yZzEtYWRtaW4wWTATBgcq
hkjOPQIBBggqhkjOPQMBBwNCAAQ8okmlq32DDeuClx77DSB2JppiBH5aD3JlwrDG
V2OA1QkcxL7W3HljBTkH6j2gKunY7diyxIq2DPwrpSV83DFuo2YwZDAOBgNVHQ8B
Af8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUgOEjiOGy3/UQ
9qir8/SENlGydjQwHwYDVR0jBBgwFoAUmFr/+27LrHM6F8Pk/ZA/NnTbtVUwCgYI
KoZIzj0EAwIDSAAwRQIhAL3nYeGEYLGPAgCn8/l3621BJQ9PmtMJgAOLo3OT5a0j
AiAFj3dCygeBI58uU0TojWUHKvjfPXGxRfbHIDSUr352Fg==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICBjCCAa2gAwIBAgIUEsuR5CLvaUYA3beogtNkchwjmDEwCgYIKoZIzj0EAwIw
YDELMAkGA1UEBhMCVVMxFzAVBgNVBAgTDk5vcnRoIENhcm9saW5hMRQwEgYDVQQK
EwtIeXBlcmxlZGdlcjEPMA0GA1UECxMGRmFicmljMREwDwYDVQQDEwhyY2Etb3Jn
MTAeFw0xODA1MDkwMzA3MDBaFw0zMzA1MDUwMzA3MDBaMGAxCzAJBgNVBAYTAlVT
MRcwFQYDVQQIEw5Ob3J0aCBDYXJvbGluYTEUMBIGA1UEChMLSHlwZXJsZWRnZXIx
DzANBgNVBAsTBkZhYnJpYzERMA8GA1UEAxMIcmNhLW9yZzEwWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAARKy2OQzzAbFPdvDGPr5Ba70et40yLUCNVt/Pf/SNS0Zj1N
IJoONT7Yd4c1p9ODDNtoblSIi+JK9W096TMhNaVLo0UwQzAOBgNVHQ8BAf8EBAMC
AQYwEgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQUmFr/+27LrHM6F8Pk/ZA/
NnTbtVUwCgYIKoZIzj0EAwIDRwAwRAIgNAm7GlMOevpvuHoQxCmADn/biM73Fm2U
CZ6EbpIZdawCIEFwHGOE2+68jMe7IDa+ZqRCL29Ha+B83Hp/Ng7b5/4M
-----END CERTIFICATE-----
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data# 
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data# cat orgs/org1/msp/intermediatecerts/ica-org1-7054.pem 
-----BEGIN CERTIFICATE-----
MIICLjCCAdSgAwIBAgIULEd+HyPce73eHsGbKEPWr/MsB2owCgYIKoZIzj0EAwIw
YDELMAkGA1UEBhMCVVMxFzAVBgNVBAgTDk5vcnRoIENhcm9saW5hMRQwEgYDVQQK
EwtIeXBlcmxlZGdlcjEPMA0GA1UECxMGRmFicmljMREwDwYDVQQDEwhyY2Etb3Jn
MTAeFw0xODA1MDkwMzA3MDBaFw0yMzA1MDgwMzEyMDBaMGYxCzAJBgNVBAYTAlVT
MRcwFQYDVQQIEw5Ob3J0aCBDYXJvbGluYTEUMBIGA1UEChMLSHlwZXJsZWRnZXIx
DzANBgNVBAsTBmNsaWVudDEXMBUGA1UEAxMOcmNhLW9yZzEtYWRtaW4wWTATBgcq
hkjOPQIBBggqhkjOPQMBBwNCAAQ8okmlq32DDeuClx77DSB2JppiBH5aD3JlwrDG
V2OA1QkcxL7W3HljBTkH6j2gKunY7diyxIq2DPwrpSV83DFuo2YwZDAOBgNVHQ8B
Af8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUgOEjiOGy3/UQ
9qir8/SENlGydjQwHwYDVR0jBBgwFoAUmFr/+27LrHM6F8Pk/ZA/NnTbtVUwCgYI
KoZIzj0EAwIDSAAwRQIhAL3nYeGEYLGPAgCn8/l3621BJQ9PmtMJgAOLo3OT5a0j
AiAFj3dCygeBI58uU0TojWUHKvjfPXGxRfbHIDSUr352Fg==
-----END CERTIFICATE-----
root@vm10-249-0-4:~/gopath/src/github.com/hyperledger/fabric-samples-cn/fabric-ca/data# 
```

💡 通过上面的输出，不难发现，`/data/org1-ca-chain.pem`包含`/data/org1-ca-cert.pem`（同 `/data/orgs/org1/msp/cacerts/ica-org1-7054.pem`，根证书）证书的内容和`/data/orgs/org1/msp/intermediatecerts/ica-org1-7054.pem`（中间层证书）证书的内容。