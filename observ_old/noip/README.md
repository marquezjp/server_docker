# No-IP

## my.noip.com

usuário: marquezjp
senha: Dud4Jul14

## DDNS

mrqz.ddns.net

## Docker

```
docker run -d --env-file noip-duc.env --name noip-duc ghcr.io/noipcom/noip-duc:latest
```

```
docker run noip-duc --help
docker logs noip-duc
docker restart noip-duc
```

## Env File

```noip-duc.env
# noip-duc.env with DDNS Key
NOIP_USERNAME=yathmhe
NOIP_PASSWORD=BYsBRXdmAwYx
NOIP_HOSTNAMES=all.ddnskey.com
```

