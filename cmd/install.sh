#!/bin/bash

mkdir /usr/local/bin/node_exporter
mv node_exporter /usr/local/bin/node_exporter
mv shell /usr/local/bin/node_exporter

chmod +x /usr/local/bin/node_exporter/*

cat<<EOF >/usr/lib/systemd/system/node-exporter.service
[Unit]
Description=node exporter
After=network.target

[Service]
User=root
Type=simple
ExecStart=/usr/local/bin/node_exporter/node_exporter --log.level=error --collector.shellfile.directory=/usr/local/bin/node_exporter/shell
Restart=always

[Install]
WantedBy=multi-user.target

EOF

chmod 754 /usr/lib/systemd/system/node-exporter.service
systemctl enable node-exporter.service

systemctl start node-exporter

if [[ $? = 0 ]]; then
    echo "install Success!!"
else
    echo "install Failed !!"
fi
