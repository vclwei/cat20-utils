#!/bin/bash

# 定义 bitcoin-cli 的路径
BITCOIN_CLI="/usr/local/bin/bitcoin-cli"
# 定义 Bitcoin 配置文件的路径
BITCOIN_CONF="/Users/xx/.bitcoin/bitcoin.conf"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "开始查询所有目标目录的 BTC 和 CAT 余额"

# 获取 $HOME/cat/ 目录中的最大数字
max_num=$(ls -d $HOME/cat/* 2>/dev/null | grep -oE '[0-9]+$' | sort -n | tail -1)

# 检查 max_num 是否为空或非数字
if [[ -z "$max_num" ]] || ! [[ "$max_num" =~ ^[0-9]+$ ]]; then
    log "警告：无法获取有效的最大数字，将使用默认值 0"
    max_num=0
fi

# 初始化总余额变量
total_btc=0
total_cat=0

# 遍历所有目标目录
for ((j=1; j<=$max_num; j++))
do
    target_dir="$HOME/cat/$j/packages/cli"
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
        log "BTC 余额: 无法获取"
    fi
    
    # 获取并解析 CAT 余额
    balance_output=$(yarn cli wallet balances)
    cat_balance=$(echo "$balance_output" | grep -oP "(?<=│ 'CAT'  │ ')[0-9.]+" || echo "0.00")
    
    # 计算 CAT 张数
    cat_count=$(echo "$cat_balance" | awk '{print int($1)}')
    cat_sheets=$(echo "$cat_count / 5" | bc)
    cat_remainder=$(echo "$cat_count % 5" | bc)
    
    log "CAT 余额: $cat_balance 个 ($cat_sheets 张完整, 余 $cat_remainder 个)"
    
    total_cat=$(echo "$total_cat + $cat_balance" | bc)
    
    log "------------------------"
done

# 计算总的 CAT 张数
total_cat_count=$(echo "$total_cat" | awk '{print int($1)}')
total_cat_sheets=$(echo "$total_cat_count / 5" | bc)
total_cat_remainder=$(echo "$total_cat_count % 5" | bc)

log "余额查询完成"
log "------------------------"
log "总计:"
log "BTC 总余额: $total_btc"
log "CAT 总余额: $total_cat 个 ($total_cat_sheets 张完整, 余 $total_cat_remainder 个)"