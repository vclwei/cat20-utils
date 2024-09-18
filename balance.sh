#!/bin/bash

# 加载 .env 文件
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "错误：当前目录中不存在 .env 文件"
    exit 1
fi

# 检查必要的环境变量是否存在
if [ -z "$BITCOIN_CLI" ] || [ -z "$BITCOIN_CONF" ] || [ -z "$WORK_PATH" ]; then
    echo "错误：BITCOIN_CLI、BITCOIN_CONF 或 WORK_PATH 未在 .env 文件中定义"
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

# 初始化总余额变量
total_btc=0
declare -A total_tokens

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
    
    # 获取钱包地址
    wallet_address=$(yarn cli wallet address | grep -oE 'bc1p[a-zA-Z0-9]+')
    log "钱包地址: $wallet_address"
    
    # 从 wallet.json 获取 wallet_name
    if [ -f "wallet.json" ]; then
        wallet_name=$(jq -r '.name' wallet.json)
        log "钱包名称: $wallet_name"
        
        # 使用 bitcoin-cli 获取 BTC 余额，指定配置文件
        btc_balance=$("$BITCOIN_CLI" -conf="$BITCOIN_CONF" -rpcwallet="$wallet_name" getbalance)
        log "BTC 余额: $btc_balance"
        total_btc=$(echo "$total_btc + $btc_balance" | bc)
    else
        log "警告: wallet.json 文件不存在"
        log "BTC 余额: 无法取"
    fi
    
    # 获取并解析余额
    balance_output=$(yarn cli wallet balances)
    log "钱包余额:"

    # 读取 tokens.json 文件
    tokens_json=$(cat tokens.json)

    # 使用 jq 解析 tokens.json 文件
    parse_tokens() {
        echo "$tokens_json" | jq -r '.[] | "\(.tokenId)|\(.symbol)|\(.info.limit)"'
    }

    # 创建关联数组来存储 token 信息
    declare -A token_info

    # 解析 token 信息并存储到关联数组中
    while IFS='|' read -r id symbol limit; do
        token_info["$id"]="$symbol|$limit"
    done < <(parse_tokens)

    # 使用 awk 解析输出并按指定格式显示
    parsed_balance=$(echo "$balance_output" | awk -v token_info="$(declare -p token_info)" '
    BEGIN {
        FS = "│"
        eval token_info
    }
    NR > 3 && NF > 3 {  # 跳过表头和分隔线
        gsub(/^[ \t''\'']+|[ \t''\'']+$/, "", $2)  # tokenId
        gsub(/^[ \t''\'']+|[ \t''\'']+$/, "", $3)  # symbol
        gsub(/^[ \t''\'']+|[ \t''\'']+$/, "", $4)  # balance
        if ($2 != "" && $3 != "" && $4 != "") {
            balance = $4 + 0  # 将余额转换为数字
            if ($2 in token_info) {
                split(token_info[$2], info, "|")
                symbol = info[1]
                limit = info[2] + 0
                if (limit > 0) {
                    sheets = int(balance / limit)
                    remainder = balance % limit
                    printf "%s (%s): %s (%.2f 张完整, 余 %.2f)\n", symbol, $2, $4, sheets, remainder
                } else {
                    printf "%s (%s): %s\n", symbol, $2, $4
                }
            } else {
                printf "%s (%s): %s\n", $3, $2, $4
            }
        }
    }')

    echo "$parsed_balance"

    # 更新总 token 余额
    echo "$parsed_balance" | while IFS= read -r line; do
        symbol=$(echo "$line" | awk -F'[()]' '{print $1}' | xargs)
        balance=$(echo "$line" | awk '{print $3}')
        current_total=${total_tokens[$symbol]:-0}
        total_tokens[$symbol]=$(echo "$current_total + $balance" | bc)
    done

    log "------------------------"
done

log "余额查询完成"
log "------------------------"
log "总计:"
log "BTC 总余额: $total_btc"
for symbol in "${!total_tokens[@]}"; do
    balance=${total_tokens[$symbol]}
    token_id=$(echo "$parsed_balance" | awk -v sym="$symbol" '$0 ~ sym {gsub(/.*\(|\).*/,""); print}')
    limit=$(echo "$tokens_json" | jq -r --arg id "$token_id" '.[] | select(.id == $id) | .limit')
    if [[ -n "$limit" && "$limit" != "null" ]]; then
        sheets=$(echo "$balance / $limit" | bc)
        remainder=$(echo "$balance % $limit" | bc)
        log "$symbol 总余额: $balance (${sheets} 张完整, 余 ${remainder})"
    else
        log "$symbol 总余额: $balance"
    fi
done