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
docker run -d --name node_exporter -p 9100:9100 -p 2345:2345 %tag%
docker cp node_exporter:/bin/node_exporter ./cmd/node_exporter
cd ./cmd
tar -czvf "node_exporter.tar.gz" shell node_exporter install.sh