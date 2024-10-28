#!/bin/bash

# 执行cat /proc/cpuinfo并读取输出
cpuinfo=$(cat /proc/cpuinfo)

# 使用循环处理每个处理器的信息
while IFS= read -r line; do
    if [[ $line == "processor"* ]]; then
        processor_id=${line##*: }
        core_id=""
        cpu_mhz=""

        # 获取当前处理器的core id和cpu MHz
        while IFS= read -r line; do
            if [[ $line == "core id"* ]]; then
                core_id=${line##*: }
            elif [[ $line == "cpu MHz"* ]]; then
                cpu_mhz=${line##*: }
            elif [[ -n $core_id && -n $cpu_mhz ]]; then
                break
            fi
        done <<< "$(echo "$cpuinfo" | awk -v pid="$processor_id" 'NR>1 {print}')"

        # 如果找到了core id和cpu MHz，输出结果
        if [[ -n $core_id && -n $cpu_mhz ]]; then
            echo "# HELP node_cpu_frequency_hertz Current frequency of the CPU in hertz."
            echo "# TYPE node_cpu_frequency_hertz gauge"
            echo "node_cpu_frequency_hertz{core=\"$core_id\"} $cpu_mhz"
        fi
    fi
done <<< "$cpuinfo"