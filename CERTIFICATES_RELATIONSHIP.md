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