# Oracle Entreprise

## Logar no Oracle Container Registry

```
docker login -u marquezjp
docker login container-registry.oracle.com -u joaopaulo.marquez@gmail.com
```

```
Dud4Jul14
```

## Baixar o Container Oracle Database Enterprise

```
docker pull container-registry.oracle.com/database/enterprise:latest
```


## Copiar as Base do SIGRH e SEGAD

```
sudo cp -r /windows/jotapessd/DBServer/SEGADDB /var/lib/docker/volumes/segad-data
sudo cp -r /windows/jotapessd/DBServer/Oracle/SIGRH-RR /var/lib/docker/volumes/sigrh-data
```
