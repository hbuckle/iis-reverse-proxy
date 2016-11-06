$jsonstring = Get-Content "$PSScriptRoot\servers.json" -Raw
docker -H docker-host:2375 run -d --name iisrp -p 443:443 hbuckle/iis-reverse-proxy "$jsonstring" "mydomain.com"