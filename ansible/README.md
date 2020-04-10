# Postgres Playbooks

这里是Pigsty用到的PG集群管理脚本，包括一系列`bash`脚本与ansible-playbook。

使用Playbook需要指定对应Cluster的Inventory，这里用于演示的[hosts](hosts)文件定义了名为`test`的数据库集群。

### 配置Inventory变量

Inventory文件中包含了初始化集群必要的信息，必须包含一个名为`cluster`的机器分组，且分组中的所有成员都需要配置`seq`实例变量用于区分。
在Cluster中，必须有且仅有一个实例带有`role=primary`标记，表示初始化时用作主库的节点，其他机器将作为从库。默认情况下：
* Primary分组：默认包含一个实例：1.testdb (10.10.10.11)
* Standby分组：默认包含两个实例：2.testdb (10.10.10.12), 3.testdb (10.10.10.13)
* Offline分组：目前空缺，后续会补充。

```ini
[cluster]
10.10.10.11 seq=1 role=primary
10.10.10.12 seq=2 role=standby
10.10.10.13 seq=3 role=standby
```

同时，还需要为Cluster分组指定一些必须的变量取值，包括：

* Cluster名称标示了数据库集群，通过变量`cluster`指定，默认名称为`testdb`
* Version标示了安装与使用的PG主要版本，通过变量`version`指定，默认版本为12

```ini
cluster=testdb
version=12
install_opts="--with-postgis"
initdb_opts="--encoding UTF8 --locale=C --data-checksums"

repl_user=replicator
repl_pass=replicator
mon_user=dbuser_monitor
mon_pass=dbuser_monitor
biz_user=dbuser_test
biz_pass=dbuser_test
biz_db=testdb
```


## 集群初始化流程

在pigsty目录中执行 `make init` 即可完成对数据库集群的初始化.
该命令实际是在`node0:/home/vagrant/playbooks`目录中执行了`init-cluster.yml`剧本

* 初始化机器环境：[`init-node.yml`](`init-node.yml`)
  * 配置使用本地Yum源，安装常用工具，配置Consul, Node Exporter, NTP服务，注册服务。
  * `init-node.yml` 会将机器名初始化为`{seq}.{cluster}`，例如`1.testdb`, `2.testdb`
* 机器初始化与PG安装：[`init-postgres.yml`](init-postgres.yml)
  * 为集群内所有机器安装Postgresql，并初始化指定版本与目录结构
* 手动初始化主库：[`init-primary.yml`](init-primary.yml)
  * 检查，清理，配置，拉起，并初始化一个集群主库，并注册服务
* 手动初始化从库：[`init-standby.yml`](init-standby.yml)
  * 使用已经拉起的集群主库初始化其余的集群从库，并注册服务
* 使用Patroni初始化集群：[`init-patroni.yml`](init-patroni.yml)
  * 如果不希望使用手动初始化，可以通过Patroni自动完成集群的初始化
  * 和`init-primary.yml`与`init-standby.yml`一样，会拉起并注册Postgres服务
* 初始化离线库：[init-offline.yml](init-offline.yml)
  * TBD，目前还需要补充
* 初始化连接池：[init-pgbouncer.yml](init-pgbouncer.yml)
* 初始化监控：[init-monitor.yml](init-monitor.yml)



**集群管理**

* 启动，关闭，重启
* 修改配置
* 修改HBA
* Pgbouncer重定向
* 创建新用户
* 创建新DB
* 重定向复制源: [`ha-retarget.yml`](ha-retarget.yml)

```bash
# change 10.10.10.13 replication source from 10.10.10.11 to 10.10.10.12
# which makes it a cascade standby of node1  
./ha-retarget.yml -i inventory/testdb -e source="10.10.10.12" -e target="10.10.10.13"
```

* Rewind
* 清理，分析，VACUUM
* 临时备份
* Failover
* Switchover

