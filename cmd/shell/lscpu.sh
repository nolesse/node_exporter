#!/bin/bash

# 运行 lscpu 命令并获取输出
output=$(lscpu)

# 从 lscpu 的输出中提取需要的信息
sockets=$(echo "$output" | grep "Socket(s):" | awk '{print $2}')
socketCore=$(echo "$output" | grep "Core(s) per socket:" | awk '{print $4}')
cpuMHz=$(echo "$output" | grep "CPU MHz:" | awk '{print $3}')

# 如果 sockets 和 socketCore 非空，则计算物理核心数并输出相关信息
if [[ -n "$sockets" && -n "$socketCore" ]]; then
    physical_cores=$((sockets * socketCore))
    echo "# HELP node_cpu_physical_cores Number of physical CPU cores on the node."
    echo "# TYPE node_cpu_physical_cores gauge"
    echo "node_cpu_physical_cores $physical_cores"
fi

# 如果 cpuMHz 非空，则输出与 CPU 频率相关的内容
if [[ -n "$cpuMHz" ]]; then
    echo "# HELP node_cpu_frequency_hertz Current frequency of the CPU in hertz."
    echo "# TYPE node_cpu_frequency_hertz gauge"
    echo "node_cpu_frequency_hertz $cpuMHz"
fi