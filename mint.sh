#!/bin/bash

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "当前目录: $(pwd)"
log "用户主目录: $HOME"

# 检查参数数量
if [ $# -eq 0 ]; then
    log "未设置最大可接受fee，将不限制fee"
    max_fee=-1  # 使用-1表示无限制
elif [ $# -eq 1 ]; then
    max_fee=$1
else
    log "使用方法: $0 [最大可接受fee]"
    exit 1
fi

# 获取 $HOME/cat/ 目录中的最大数字
max_num=$(ls -d $HOME/cat/* 2>/dev/null | grep -oE '[0-9]+$' | sort -n | tail -1)

# 初始化循环计数器
loop_count=0

# 无限循环执行命令
while true
do
    # 增加循环计数
    ((loop_count++))
    log "第 $loop_count 次 Mint 尝试------------------------"

    # 获取自动费率
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
        target_dir="$HOME/cat/$j/packages/cli"
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
        yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 --fee-rate $fee
        
        # 获取并显示账户余额
        log "获取账户余额:"
            # 获取并解析 CAT 余额
        balance_output=$(yarn cli wallet balances)
        cat_balance=$(echo "$balance_output" | grep -oP "(?<=│ 'CAT'  │ ')[0-9.]+" || echo "0.00")
        # 打印当前钱包地址及CAT余额
        log "$wallet_address 的 CAT 余额: $cat_balance"

        log "------------------------"
    done

    log "第 $loop_count 次 Mint 尝试完成"
    log "等待30秒后开始下一轮..."
    sleep 30
done

# 注意：这个脚本现在会无限运行，需要手动中断（如按 Ctrl+C）才会停止
