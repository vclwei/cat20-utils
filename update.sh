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

log "开始更新所有目标目录的仓库"

# 获取 WORK_PATH 目录中的最大数字
max_num=$(ls -d "$WORK_PATH"/* 2>/dev/null | grep -oE '[0-9]+$' | sort -n | tail -1)

# 检查 max_num 是否为空或非数字
if [[ -z "$max_num" ]] || ! [[ "$max_num" =~ ^[0-9]+$ ]]; then
    log "警告：无法获取有效的最大数字，将使用默认值 0"
    max_num=0
fi

# 遍历所有目标目录
for ((j=1; j<=$max_num; j++))
do
    target_dir="$WORK_PATH/$j"
    log "处理目录: $target_dir"
    if [ ! -d "$target_dir" ]; then
        log "目录不存在: $target_dir"
        continue
    fi
    cd "$target_dir" || { log "无法切换到目标文件夹: $target_dir"; continue; }
    
    # 检查是否为git仓库
    if [ -d ".git" ]; then
        log "更新git仓库..."
        git pull
        
        # 检查是否存在package.json文件
        if [ -f "package.json" ]; then
            log "安装依赖..."
            yarn install
            
            log "编译项目..."
            yarn build
        else
            log "未找到package.json文件，跳过编译步骤"
        fi
        
        # 进入 packages/cli 目录并重新编译
        cli_dir="$target_dir/packages/cli"
        if [ -d "$cli_dir" ]; then
            log "进入 packages/cli 目录..."
            cd "$cli_dir" || { log "无法切换到 packages/cli 目录"; continue; }
            
            if [ -f "package.json" ]; then
                log "在 packages/cli 中安装依赖..."
                yarn install
                
                log "在 packages/cli 中编译项目..."
                yarn build
            else
                log "packages/cli 中未找到 package.json 文件，跳过编译步骤"
            fi
            
            cd "$target_dir"
        else
            log "packages/cli 目录不存在，跳过"
        fi
    else
        log "不是git仓库，跳过更新"
    fi
    
    log "完成处理目录: $target_dir"
    log "------------------------"
done

log "所有目录更新完成"
