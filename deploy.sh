#!/bin/bash

# 定义 config.json 的内容
CONFIG_JSON='{
  "network": "fractal-mainnet",
  "tracker": "http://127.0.0.1:3000",
  "dataDir": ".",
  "maxFeeRate": 100,
  "rpc": {
      "url": "http://127.0.0.1:8332",
      "username": "rpc_username",
      "password": "rpc_upassword;"
  }
}'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "开始部署新的 mint 程序"

# 获取当前 $HOME/cat/ 目录中的最大数字
max_num=$(ls -d $HOME/cat/* 2>/dev/null | grep -oE '[0-9]+$' | sort -n | tail -1)

# 检查 max_num 是否为空或非数字
if [[ -z "$max_num" ]] || ! [[ "$max_num" =~ ^[0-9]+$ ]]; then
    log "警告：无法获取有效的最大数字，将使用默认值 0"
    max_num=0
fi

next_num=$((max_num + 1))

# 克隆仓库
target_dir="$HOME/cat/$next_num"
log "克隆仓库到目录: $target_dir"
git clone https://github.com/vclwei/cat-token-box.git "$target_dir"

# 切换到目标目录
cd "$target_dir" || { log "无法切换到目标文件夹: $target_dir"; exit 1; }

# 在项目根目录安装依赖和构建项目
log "在项目根目录安装依赖..."
yarn install

log "在项目根目录构建项目..."
yarn build

# 进入 packages/cli 目录
cd packages/cli || { log "无法进入 packages/cli 目录"; exit 1; }

# 修改 config.json 文件
log "修改 config.json 文件..."
echo "$CONFIG_JSON" > config.json

log "config.json 文件已更新"

# 在 packages/cli 目录下安装依赖和构建项目
log "在 packages/cli 目录下安装依赖..."
yarn install

log "在 packages/cli 目录下构建项目..."
yarn build

# 运行 yarn cli wallet create
log "创建新钱包..."
yarn cli wallet create

wallet_address=$(yarn cli wallet address | grep -oE 'bc1p[a-zA-Z0-9]+')
log "新钱包地址 $wallet_address"

log "目录 $target_dir/packages/cli 部署完成"
log "------------------------"

log "部署完成"