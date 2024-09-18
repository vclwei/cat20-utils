#!/bin/bash

# 加载 .env 文件
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "错误：当前目录中不存在 .env 文件"
    exit 1
fi

# 检查必要的环境变量是否存在
if [ -z "$WORK_PATH" ]; then
    echo "错误：WORK_PATH 未在 .env 文件中定义"
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "当前目录: $(pwd)"
log "工作目录: $WORK_PATH"

# 检查参数数量
if [ $# -eq 0 ]; then
    log "使用方法: $0 <交易ID> [最大可接受fee]"
    exit 1
elif [ $# -eq 1 ]; then
    tid=$1
    max_fee=-1  # 使用-1表示无限制
elif [ $# -eq 2 ]; then
    tid=$1
    max_fee=$2
else
    log "使用方法: $0 <交易ID> [最大可接受fee]"
    exit 1
fi

# 获取 WORK_PATH 目录中的最大数字
max_num=$(ls -d "$WORK_PATH"/* 2>/dev/null | grep -oE '[0-9]+$' | sort -n | tail -1)

# 初始化循环计数器
loop_count=0

# 无限循环执行命令
while true
do
    # 增加循环计数
    ((loop_count++))
    log "第 $loop_count 次 Mint 尝试------------------------"

    # 获取自动
    response=$(curl -s https://mempool.fractalbitcoin.io/api/v1/fees/mempool-blocks)
    fastestFee=$(echo "$response" | jq '.[0].feeRange | .[-4] | floor') # 倒数第四档，向下取整
    fastestFee=${fastestFee%.*}  # 移除小数部分

    # 如果成功获取到 fastestFee，且小于 max_fee（或无限制），则使用 fastestFee，否则跳过本次循环
    if [ -z "$fastestFee" ] || [ "$fastestFee" == "null" ]; then
        log "获取费率失败，等待10秒后继续下一次循环"
        sleep 10
        continue
    elif [ $max_fee -eq -1 ] || [ "$fastestFee" -le "$max_fee" ]; then
        fee=$fastestFee
        log "执行费率: $fee"
    else
        log "当前费率 $fastestFee 超过最大可接受费率 $max_fee，等待30秒后继续下一次循环"
        sleep 30
        continue
    fi
    
    # 内部循环,切换目标地址中的数字1到最大数字
    for ((j=1; j<=$max_num; j++))
    do
        target_dir="$WORK_PATH/$j/packages/cli"
        log "切换到目录: $target_dir"
        if [ ! -d "$target_dir" ]; then
            log "目录不存在: $target_dir"
            continue
        fi
        cd "$target_dir" || { log "无法切换到目标文件夹: $target_dir"; continue; }
        
        # 获取钱包地址
        wallet_address=$(yarn cli wallet address | grep -oE 'bc1p[a-zA-Z0-9]+')
        log " $wallet_address 进行 Mint"
        
        # 执行指定的命令
        yarn cli mint -i $tid --fee-rate $fee
        
        # 在 mint.sh 文件中，替换原有的获取并显示账户余额的代码
        log "获取账户余额:"
        balance_output=$(yarn cli wallet balances)
        log "$wallet_address 的资产余额:"

        # 读取 tokens.json 文件
        tokens_json=$(cat tokens.json)

        # 使用 awk 解析输出并按指定格式显示
        parsed_balance=$(echo "$balance_output" | awk -v tokens="$tokens_json" '
        BEGIN {
            # 解析 tokens.json
            split(tokens, token_array, /[{}]/)
            for (i in token_array) {
                if (token_array[i] ~ /"id":/) {
                    split(token_array[i], fields, /,/)
                    token_id = ""
                    token_limit = ""
                    for (j in fields) {
                        if (fields[j] ~ /"id":/) {
                            split(fields[j], id_field, /:/)
                            gsub(/[" ]/, "", id_field[2])
                            token_id = id_field[2]
                        }
                        if (fields[j] ~ /"limit":/) {
                            split(fields[j], limit_field, /:/)
                            gsub(/[" ]/, "", limit_field[2])
                            token_limit = limit_field[2]
                        }
                    }
                    if (token_id != "" && token_limit != "") {
                        token_limits[token_id] = token_limit
                    }
                }
            }
        }
        NR>2 && NF>1 {
            gsub(/^[ \t]+|[ \t]+$/, "", $2);
            gsub(/^[ \t]+|[ \t]+$/, "", $3);
            gsub(/^[ \t]+|[ \t]+$/, "", $4);
            gsub(/'\''/, "", $2);
            gsub(/'\''/, "", $3);
            gsub(/'\''/, "", $4);
            if($2 != "" && $3 != "" && $4 != "") {
                balance = $4 + 0  # 将余额转换为数字
                limit = token_limits[$2] + 0  # 获取对应的 limit 值并转换为数字
                if (limit > 0) {
                    sheets = int(balance / limit)
                    remainder = balance % limit
                    printf "%s (%s): %s (%.2f 张完整, 余 %.2f)\n", $3, $2, $4, sheets, remainder
                } else {
                    printf "%s (%s): %s\n", $3, $2, $4
                }
            }
        }')

        echo "$parsed_balance"

        log "------------------------"
    done

    log "第 $loop_count 次 Mint 尝试完成"
    log "等待30秒后开始下一轮..."
    sleep 30
done

# 注意：这个脚本现在会无限运行，需要手动中断（如按 Ctrl+C）才会停止
