set GOOS=linux
set GOARCH=amd64

set name=node_exporter

set /p a=<config.ini
@echo read config get %a%
set /a aa=%a% +1
>config.ini echo %aa%

cd ..

set tag=%name%:v%aa%
docker build -t %tag% -f Dockerfile .
docker run -d --name node_exporter_v2 -p 9100:9100 -p 2345:2345 %tag%
