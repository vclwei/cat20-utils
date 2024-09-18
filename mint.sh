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
        
        log "获取账户余额:"
        log "$wallet_address 的资产余额:"

        # 读取当前目录下的 tokens.json 文件并解析 token 信息
        parse_tokens() {
            local tokens_file="tokens.json"
            if [ -f "$tokens_file" ]; then
                jq -r '.[] | "\(.tokenId)|\(.info.symbol)|\(.info.decimals)|\(.info.limit)|\(.info.name)"' "$tokens_file"
            else
                log "警告: tokens.json 文件不存在"
            fi
        }

        # 从 wallet.json 获取 wallet_name
        if [ -f "wallet.json" ]; then
            wallet_name=$(jq -r '.name' wallet.json)
            log "钱包: $wallet_name ($wallet_address)"
            
            # 使用 bitcoin-cli 获取 BTC 余额，指定配置文件
            btc_balance=$("$BITCOIN_CLI" -conf="$BITCOIN_CONF" -rpcwallet="$wallet_name" getbalance)
            log "BTC 余额: $btc_balance"
            total_btc=$(echo "$total_btc + $btc_balance" | bc)
        else
            log "钱包: $wallet_address" 
            log "警告: wallet.json 文件不存在"
            log "BTC 余额: 无法获取"
        fi
    

        # 初始化 token 信息数组
        declare -A token_info

        # 解析 token 信息并存储到数组中
        while IFS='|' read -r id symbol decimals limit name; do
            token_info["$id"]="$symbol|$decimals|$limit|$name"
        done < <(parse_tokens)

        # 使用 API 获取 token 余额
        api_url="${CONFIG_JSON_TRACKER}/api/addresses/${wallet_address}/balances"
        token_balances=$(curl -s "$api_url")

        log "Token 余额:"
        while read -r line; do
            eval "$line"
            if [[ -n "${token_info[$token_id]}" ]]; then
                IFS='|' read -r symbol decimals limit name <<< "${token_info[$token_id]}"
                formatted_balance=$(printf "%.${decimals}f" $(echo "scale=$decimals; $balance / 10^$decimals" | bc))
                if [[ -n "$limit" && "$limit" != "null" ]]; then
                    sheets=$(echo "$formatted_balance / $limit" | bc)
                    remainder=$(printf "%.${decimals}f" $(echo "scale=$decimals; $formatted_balance % $limit" | bc))
                    log "$symbol [$token_id]: $formatted_balance (${sheets} 张完整, 余 ${remainder})"
                else
                    log "$symbol [$token_id]: $formatted_balance"
                fi
            else
                log "未知 Token [$token_id]: $balance"
            fi
        done < <(echo "$token_balances" | jq -r '.data.balances[] | @sh "token_id=\(.tokenId) balance=\(.confirmed)"')

        log "------------------------"
    done

    log "第 $loop_count 次 Mint 尝试完成"
    log "等待30秒后开始下一轮..."
    sleep 30
done

# 注意：这个脚本现在会无限运行，需要手动中断（如按 Ctrl+C）才会停止
