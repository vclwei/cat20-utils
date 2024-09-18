# cat20-utils

这个仓库包含了一些用于 Fractal Bitcoin CAT20 协议的实用工具脚本。

## 使用说明

这些脚本主要适用于自己搭建的 fractal rpc 和 tracker 环境。如果使用的是 docker，可能需要进行一些修改。

1. 创建 `$HOME/cat/` 目录作为工作目录
2. 将脚本文件复制到 `$HOME/cat/` 目录
3. 安装必要的环境：node, yarn, jq
4. 使用 `chmod +x` 命令赋予脚本执行权限
5. 使用 `./脚本名.sh` 命令运行脚本

## 索引数据库备份

为了节省索引时间，我们提供了一份 Block 到 13888 的 CAT20 索引数据库文件备份。

下载地址：[CAT20 索引数据库备份](https://www.dropbox.com/scl/fi/1dvfi4bwkog5g126b713j/cat_index_postgres_13888.sql.tar.gz?rlkey=9lkzi8wew02bgqh2kd4w8itfk&st=963g7iim&dl=0)

这个备份主要适用于自行安装的 PostgreSQL。

### 如何恢复数据库备份

参考：[How to backup and restore a postgres database](https://tembo.io/docs/getting-started/postgres_guides/how-to-backup-and-restore-a-postgres-database)

步骤：
1. 解压文件：`tar -zxvf cat20-index-13888.tar.gz`
2. 将解压后的文件夹移动到 PostgreSQL 目录：`mv cat20-index-13888 /var/lib/postgresql/`
3. 切换到 postgres 用户：`sudo -i -u postgres`
4. 恢复数据库：`psql -U postgres -d postgres -f cat20-index-13888.sql`

## 脚本说明

### deploy.sh

用于部署新的 mint 程序。

使用方法：
1. 在 .env 文件中配置 CONFIG_JSON 相关的环境变量
2. 运行 `./deploy.sh`
3. 脚本会在 `$HOME/cat/` 目录下创建一个新的数字目录，包含完整的 cat-token-box 代码和钱包信息

### mint.sh

用于批量执行 mint 操作。

使用方法：
1. 不限制 fee：`./mint.sh <交易ID>`
2. 限制最大 fee：`./mint.sh <交易ID> <最大可接受fee>`

例如：`./mint.sh 100` 表示最大可接受 fee 为 100 sat/vbyte

### balance.sh

用于批量查询所有目录下钱包的 FB 和 CAT 余额。

使用方法：
1. 在 .env 文件中配置 BITCOIN_CLI 和 BITCOIN_CONF 路径
2. 运行 `./balance.sh`

### update.sh

用于更新所有目录中的仓库。

使用方法：
1. 运行 `./update.sh`

## 环境配置

在运行脚本之前，请确保在当前目录中存在 .env 文件。.env 文件应包含以下变量：

```
WORK_PATH="/path/to/work/directory"
BITCOIN_CLI="/path/to/bitcoin-cli"
BITCOIN_CONF="/path/to/bitcoin.conf"
```

# CONFIG_JSON 配置
```
CONFIG_JSON_NETWORK="fractal-mainnet"
CONFIG_JSON_TRACKER="http://127.0.0.1:3000"
CONFIG_JSON_DATA_DIR="."
CONFIG_JSON_RPC_URL="http://127.0.0.1:8332"
CONFIG_JSON_RPC_USERNAME="rpc_username"
CONFIG_JSON_RPC_PASSWORD="rpc_password"
```

请根据您的实际配置修改这些路径和值。
