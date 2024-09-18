#!/bin/bash

# 加载 .env 文件
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "错误：当前目录中不存在 .env 文件"
    exit 1
fi

# 检查必要的环境变量是否存在
if [ -z "$BITCOIN_CLI" ] || [ -z "$BITCOIN_CONF" ] || [ -z "$WORK_PATH" ] || [ -z "$CONFIG_JSON_TRACKER" ]; then
    echo "错误：BITCOIN_CLI、BITCOIN_CONF、WORK_PATH 或 CONFIG_JSON_TRACKER 未在 .env 文件中定义"
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "开始查询所有目标目录的 BTC 和 token 余额"

# 获取 WORK_PATH 目录中的最大数字
max_num=$(ls -d "$WORK_PATH"/* 2>/dev/null | grep -oE '[0-9]+$' | sort -n | tail -1)

# 检查 max_num 是否为空或非数字
if [[ -z "$max_num" ]] || ! [[ "$max_num" =~ ^[0-9]+$ ]]; then
    log "警告：无法获取有效的最大数字，将使用默认值 0"
    max_num=0
fi

# 初始化总余额变量和所有token信息
total_btc=0
declare -A total_tokens
declare -A all_token_info

# 遍历所有目标目录
for ((j=1; j<=$max_num; j++))
do
    target_dir="$WORK_PATH/$j/packages/cli"
    log "查询目录: $target_dir"
    if [ ! -d "$target_dir" ]; then
        log "目录不存在: $target_dir"
        continue
    fi
    cd "$target_dir" || { log "无法切换到目标文件夹: $target_dir"; continue; }
    
    # 读取当前目录下的 tokens.json 文件并解析 token 信息
    parse_tokens() {
        local tokens_file="tokens.json"
        if [ -f "$tokens_file" ]; then
            jq -r '.[] | "\(.tokenId)|\(.info.symbol)|\(.info.decimals)|\(.info.limit)|\(.info.name)"' "$tokens_file"
        else
            log "警告: tokens.json 文件不存在"
        fi
    }

    # 解析 token 信息并存储到 all_token_info 数组中，进行去重
    while IFS='|' read -r id symbol decimals limit name; do
        if [[ -n "$id" && -z "${all_token_info[$id]}" ]]; then
            all_token_info["$id"]="$symbol|$decimals|$limit|$name"
        fi
    done < <(parse_tokens)

    # 获取钱包地址
    wallet_address=$(yarn cli wallet address | grep -oE 'bc1p[a-zA-Z0-9]+')
    
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
    
    # 使用 API 获取 token 余额
    api_url="${CONFIG_JSON_TRACKER}/api/addresses/${wallet_address}/balances"
    token_balances=$(curl -s "$api_url")

    log "Token 余额:"
    while read -r line; do
        eval "$line"
        if [[ -n "${all_token_info[$token_id]}" ]]; then
            IFS='|' read -r symbol decimals limit name <<< "${all_token_info[$token_id]}"
            formatted_balance=$(printf "%.${decimals}f" $(echo "scale=$decimals; $balance / 10^$decimals" | bc))
            if [[ -n "$limit" && "$limit" != "null" ]]; then
                sheets=$(echo "$formatted_balance / $limit" | bc)
                remainder=$(printf "%.${decimals}f" $(echo "scale=$decimals; $formatted_balance % $limit" | bc))
                log "$symbol [$token_id]: $formatted_balance (${sheets} 张完整, 余 ${remainder})"
            else
                log "$symbol [$token_id]: $formatted_balance"
            fi
            # 更新总余额
            current_total="${total_tokens[$token_id]:-0}"
            total_tokens[$token_id]=$(echo "$current_total + $formatted_balance" | bc)
        else
            log "未知 Token [$token_id]: $balance"
        fi
    done < <(echo "$token_balances" | jq -r '.data.balances[] | @sh "token_id=\(.tokenId) balance=\(.confirmed)"')

    log "------------------------"
done

log "余额查询完成"
log "------------------------"
log "总计:"
log "BTC 总余额: $total_btc"

log "代币总余额:"
for token_id in "${!total_tokens[@]}"; do
    balance=${total_tokens[$token_id]}
    if [[ -n "${all_token_info[$token_id]}" ]]; then
        IFS='|' read -r symbol decimals limit name <<< "${all_token_info[$token_id]}"
        formatted_balance=$(printf "%.${decimals}f" $balance)
        if [[ -n "$limit" && "$limit" != "null" ]]; then
            sheets=$(echo "$formatted_balance / $limit" | bc)
            remainder=$(printf "%.${decimals}f" $(echo "scale=$decimals; $formatted_balance % $limit" | bc))
            log "$name ($symbol) [$token_id]: $formatted_balance (${sheets} 张完整, 余 ${remainder})"
        else
            log "$name ($symbol) [$token_id]: $formatted_balance"
        fi
    else
        log "未知 Token [$token_id]: $balance"
    fi
done

