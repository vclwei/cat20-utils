# cat20-utils

这个仓库包含了一些用于 Fractal Bitcoin CAT20 协议的实用工具脚本。

## 使用说明
几个脚本比较适用于自己搭建的 fractal rpc 和 tracker 环境，如果使用的是 docker, 需要自己修改一下。

1. 创建 $HOME/cat/ 目录作为工作目录
2. 将脚本文件复制到 $HOME/cat/ 目录
3. 安装环境，node, yarn, jq
4. 使用 chmod +x 命令赋予脚本执行权限
5. 使用 ./脚本名.sh 命令运行脚本

### 索引数据库备份

为了节省索引时间，备份了一份 Block 到 13888 的 CAT20 索引数据库文件，下载地址 https://mypikpak.com/s/VO6drPV4dk-_42JS6-5ENThmo1 。
也是比较适用于自己安装的 postgresql。

使用方法：
1. tar -zxvf cat20-index-13888.tar.gz 解压文件
2. 将解压后的文件夹 mv 到 /var/lib/postgresql/ 目录下
3. 使用 sudo -i -u postgres 切换到 postgres 用户
4. 使用 psql -U postgres -d postgres -f cat20-index-13888.sql 恢复数据库


### deploy.sh

这个脚本用于部署新的 mint 程序, 代码是从 https://github.com/vclwei/cat-token-box.git 克隆过来的，这个代码库已经去掉了 mint 时 merge 的逻辑。

使用方法：
1. 配置文件中 CONFIG_JSON 的 tracker 和 rpc 信息
2. 运行 ./deploy.sh
3. 运行后会在 $HOME/cat/ 目录下创建一个新的数字目录，里面包含完整的 cat-token-box 代码和钱包信息

### mint.sh
这个脚本用来批量执行 mint 操作，$HOME/cat/ 下有多少个目录，就会执行多少个钱包的 mint 操作。
会自动获取当前的 fee，可以配置 max_fee 来限制最大可接受的 fee。

使用方法：
1. 运行 ./mint.sh 不带参数，表示不限制 fee
2. 运行 ./mint.sh 100，表示最大可接受 fee 为 100 sat/vbyte，如果当前 fee 大于 100 sat/vbyte，则不会 mint

### balance.sh

这个脚本用来批量查询所有目录下的钱包的 FB 和 CAT 余额。

使用方法：
1. 配置文件中中的 BITCOIN_CLI 和 BITCOIN_CONF 路径，BITCOIN_CLI 在 fractal 的 bin 目录下，BITCOIN_CONF 看自己放在那里。
2. 运行 ./balance.sh，会输出 $HOME/cat/ 下所有数字目录程序包中钱包的 FB 和 CAT 余额。
