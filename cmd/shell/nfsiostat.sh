#!/bin/bash

# 执行 nfsiostat 并将输出存储在变量中
nfs_output=$(nfsiostat)

# 将输出分割成行
IFS=$'\n' read -rd '' -a lines <<< "$nfs_output"

# 存储指标数据
declare -A metrics

# 处理每个挂载点的相关数据
for ((i=0; i<${#lines[@]}; i++)); do
    # 判断是否是挂载点的行
    if [[ ${lines[i]} == *"mounted on"* ]]; then
        # 获取 device
        device=${lines[i]%% mounted on*}

        # 取出下两行的读写数据
        read_line=${lines[i+4]}
        write_line=${lines[i+6]}

        # 提取各列对应的值
        read_iops=$(echo "$read_line" | awk '{print $1}')
        read_rate=$(echo "$read_line" | awk '{print $2}')
        read_avg_rtt=$(echo "$read_line" | awk '{print $6}')
        read_avg_exe=$(echo "$read_line" | awk '{print $7}')

        write_iops=$(echo "$write_line" | awk '{print $1}')
        write_rate=$(echo "$write_line" | awk '{print $2}')
        write_avg_rtt=$(echo "$write_line" | awk '{print $6}')
        write_avg_exe=$(echo "$write_line" | awk '{print $7}')

        # 存储结果到数组
        metrics["nfs_read_iops{device=\"$device\"}"]=$read_iops
        metrics["nfs_read_rate{device=\"$device\"}"]=$read_rate
        metrics["nfs_read_avg_rtt{device=\"$device\"}"]=$read_avg_rtt
        metrics["nfs_read_avg_exe{device=\"$device\"}"]=$read_avg_exe
        metrics["nfs_write_iops{device=\"$device\"}"]=$write_iops
        metrics["nfs_write_rate{device=\"$device\"}"]=$write_rate
        metrics["nfs_write_avg_rtt{device=\"$device\"}"]=$write_avg_rtt
        metrics["nfs_write_avg_exe{device=\"$device\"}"]=$write_avg_exe
    fi
done

# 输出 HELP 和 TYPE 以及对应的 metrics
echo "# HELP nfs_read_iops IOPS for read operations."
echo "# TYPE nfs_read_iops gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_read_iops* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

echo "# HELP nfs_read_rate Read rate in kB/s."
echo "# TYPE nfs_read_rate gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_read_rate* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

echo "# HELP nfs_read_avg_rtt Average round trip time in ms for read operations."
echo "# TYPE nfs_read_avg_rtt gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_read_avg_rtt* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

echo "# HELP nfs_read_avg_exe Average execution time in ms for read operations."
echo "# TYPE nfs_read_avg_exe gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_read_avg_exe* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

# 写入写入操作的指标
echo "# HELP nfs_write_iops IOPS for write operations."
echo "# TYPE nfs_write_iops gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_write_iops* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

echo "# HELP nfs_write_rate Write rate in kB/s."
echo "# TYPE nfs_write_rate gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_write_rate* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

echo "# HELP nfs_write_avg_rtt Average round trip time in ms for write operations."
echo "# TYPE nfs_write_avg_rtt gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_write_avg_rtt* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done

echo "# HELP nfs_write_avg_exe Average execution time in ms for write operations."
echo "# TYPE nfs_write_avg_exe gauge"
for key in "${!metrics[@]}"; do
    if [[ $key == nfs_write_avg_exe* ]]; then
        echo "$key ${metrics[$key]}"
    fi
done
