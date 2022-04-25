# Demo

Tutorial: https://selectel.ru/blog/tutorials/how-to-set-up-vpn-ipsec/

Scheme
![164717256-556621a5-ddbb-4726-aaad-6359120a8add](https://user-images.githubusercontent.com/8326634/165049175-c03ddb5f-f559-4503-a4b7-dd576afe55b0.png)

Commands:
```shell
# vpn1
curl https://raw.githubusercontent.com/selectel/ipsec-vpn-demo/main/ipsec-configure.sh | bash -s -- 51.250.39.22 192.168.10.0/24 192.168.20.0/24 qLGLTVQOfqvGLsWP75FEtLGtwN3Hu0ku6C5HItKo6ac= MASTER 192.168.10.100/24 188.68.206.158/29

# vpn2
curl https://raw.githubusercontent.com/selectel/ipsec-vpn-demo/main/ipsec-configure.sh | bash -s -- 51.250.39.22 192.168.10.0/24 192.168.20.0/24 qLGLTVQOfqvGLsWP75FEtLGtwN3Hu0ku6C5HItKo6ac= BACKUP 192.168.10.100/24 188.68.206.158/29
```
