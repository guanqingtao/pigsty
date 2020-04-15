# Patroni HA Drill

Patroni文档：https://patroni.readthedocs.io/en/latest/README.html

可以通过本地`patronictl`二进制或者直接调用Patroni的REST API来完成相关操作

```bash
alias pt='patronictl -c /pg/bin/patroni.yml'
```



## Case 1:  Show Cluster Status

Using `patronictl` or Rest API

```bash
$ pt list
+---------+----------+-------------+--------+---------+----+-----------+
| Cluster |  Member  |     Host    |  Role  |  State  | TL | Lag in MB |
+---------+----------+-------------+--------+---------+----+-----------+
|  testdb | 1.testdb | 10.10.10.11 | Leader | running |  1 |           |
|  testdb | 2.testdb | 10.10.10.12 |        | running |  1 |         1 |
|  testdb | 3.testdb | 10.10.10.13 |        | running |  1 |         1 |
+---------+----------+-------------+--------+---------+----+-----------+
```

或者使用REST API

```json
$ curl -s  node1:8008/cluster | jq
{
  "members": [
    {
      "name": "1.testdb",
      "host": "10.10.10.11",
      "port": 5432,
      "role": "leader",
      "state": "running",
      "api_url": "http://10.10.10.11:8008/patroni",
      "timeline": 1
    },
    {
      "name": "2.testdb",
      "host": "10.10.10.12",
      "port": 5432,
      "role": "replica",
      "state": "running",
      "api_url": "http://10.10.10.12:8008/patroni",
      "timeline": 1,
      "lag": 0
    },
    {
      "name": "3.testdb",
      "host": "10.10.10.13",
      "port": 5432,
      "role": "replica",
      "state": "running",
      "api_url": "http://10.10.10.13:8008/patroni",
      "timeline": 1,
      "lag": 0
    }
  ]
}
```





## Case 2: Switchover

验证主动切换的流程，Switchover是集群健康时的操作，Failover是集群故障时的操作。

Watch monitoring system for more detail: [http://g.pigsty/d/pg_cluster/pg-cluster?orgId=1&refresh=%202s](http://g.pigsty/d/pg_cluster/pg-cluster?orgId=1&refresh= 2s)

监控系统可以观察到：

* 老主库`1.testdb`被Fencing
* 新主库`2.testdb`被Promote，时间线+1
* `1.testdb`和`3.testdb`重启，从新主库`2.testdb`开始流复制。

```bash
$ pt switchover
Master [1.testdb]: 1.testdb
Candidate ['2.testdb', '3.testdb'] []: 2.testdb
When should the switchover take place (e.g. 2020-04-10T12:11 )  [now]: now
Current cluster topology
+---------+----------+-------------+--------+---------+----+-----------+
| Cluster |  Member  |     Host    |  Role  |  State  | TL | Lag in MB |
+---------+----------+-------------+--------+---------+----+-----------+
|  testdb | 1.testdb | 10.10.10.11 | Leader | running |  1 |           |
|  testdb | 2.testdb | 10.10.10.12 |        | running |  1 |         0 |
|  testdb | 3.testdb | 10.10.10.13 |        | running |  1 |         0 |
+---------+----------+-------------+--------+---------+----+-----------+
Are you sure you want to switchover cluster testdb, demoting current master 1.testdb? [y/N]: y
2020-04-10 11:11:39.53290 Successfully switched over to "2.testdb"
+---------+----------+-------------+--------+---------+----+-----------+
| Cluster |  Member  |     Host    |  Role  |  State  | TL | Lag in MB |
+---------+----------+-------------+--------+---------+----+-----------+
|  testdb | 1.testdb | 10.10.10.11 |        | stopped |    |   unknown |
|  testdb | 2.testdb | 10.10.10.12 | Leader | running |  1 |           |
|  testdb | 3.testdb | 10.10.10.13 |        | running |  1 |         0 |
+---------+----------+-------------+--------+---------+----+-----------+
```

也可以调用Patroni的HTTP API完成切换，必须指定`leader`与`candidate`的名称。

```bash
$ curl -s -i -X POST -d '{"leader":"2.testdb", "candidate": "1.testdb"}' http://node1:8008/switchover
Successfully switched over to "1.testdb"
```





## Case 3: Standby Down

分情况讨论：

* **Postgres服务中止，Patroni存活**：

  * patronictl list显示节点状态为running
  * Postgres会重新被Patroni拉起来。

* **Patroni被停掉，Postgres也中止**

  * patroni list节点状态显示stopped，一段时间(TTL=15s)后会被踢出集群。
  * 恢复时，启动Patroni会自动启动PG

* **Patroni中止，手工重启PG**

  * 先启动PG，再启动Patroni也可以，Patroni会自动接管现存的PG
  * 托管后，再次杀掉Patroni，PG也随之中止，说明后启动Patroni也可以将活动的PG纳入管理，这对于改造现有集群非常重要。

* 失误场景：拷贝了错误的集群或错误的初始化：会通过cluster ID来检测判断避免

  CRITICAL: system ID mismatch, node 1.testdb belongs to a different cluster: 6813173841234113561 != 6813181462887476504



## Case 4: Primary Down

会触发Failover，自动切换。

主库如果Restart足够快，不会触发Failover。如果需要长时间，通过`pt pause`启动维护模式。



## Case 5: Failover

Failover是集群故障时的操作，通常是自动触发的。但也可以手动执行，例如当所有节点都处于非健康状态时（例如因为复制延迟过大而没有自动触发Failover），可以手动执行Failover。

Failover只需要新主库的名称作为参数（参数名 `candidate`）。

```bash
Candidate ['2.testdb', '3.testdb'] []: 2.testdb
Current cluster topology
+---------+----------+-------------+--------+---------+----+-----------+
| Cluster |  Member  |     Host    |  Role  |  State  | TL | Lag in MB |
+---------+----------+-------------+--------+---------+----+-----------+
|  testdb | 1.testdb | 10.10.10.11 | Leader | running |  3 |           |
|  testdb | 2.testdb | 10.10.10.12 |        | running |  3 |         0 |
|  testdb | 3.testdb | 10.10.10.13 |        | running |  3 |         0 |
+---------+----------+-------------+--------+---------+----+-----------+
Are you sure you want to failover cluster testdb, demoting current master 1.testdb? [y/N]: y
2020-04-13 02:00:54.29116 Successfully failed over to "2.testdb"
+---------+----------+-------------+--------+---------+----+-----------+
| Cluster |  Member  |     Host    |  Role  |  State  | TL | Lag in MB |
+---------+----------+-------------+--------+---------+----+-----------+
|  testdb | 1.testdb | 10.10.10.11 |        | stopped |    |   unknown |
|  testdb | 2.testdb | 10.10.10.12 | Leader | running |  3 |           |
|  testdb | 3.testdb | 10.10.10.13 |        | running |  3 |         0 |
+---------+----------+-------------+--------+---------+----+-----------+
```

REST API方式：

```bash
$ curl -s -i -X POST -d '{"candidate": "1.testdb"}' http://node1:8008/failover
HTTP/1.0 200 OK
Successfully failed over to "1.testdb"
```

### **Failover的触发时机**

不会触发Failover的情况：维护模式，由Patroni托管的主库重启，或者外部短暂重启主库，都不会触发Failover。

如果主库被关闭时间过长，失去Leader锁，则会触发。取决于Leader Lock TTL的设置。

当主库时长不可用超过阈值，则会触发Failover

```bash
pg_ctl -D /pg/data stop
```

如果没有足够健康的节点，延迟过大 

```bash
# standby
psql -c 'select pg_wal_replay_pause();'
psql -c 'select pg_is_wal_replay_paused();'
# psql -c 'select pg_wal_replay_resume();'

# primary
pgbench -i -s 10 
pgbench -n -v -T 1000
```

### Corner Case

如果Failover发生时，目标节点的`pg_is_wal_replay_paused`，那么就会出现Patroni认为Failover成功，其他从库都挂到候选主库之下，但候选主库始终无法进入Primary状态。需要当心。需要执行`select pg_wal_replay_resume();`之后才能正式成为主库。所以

 



## Case 6: DCS Down

DCS挂了是高可用方案中最大的风险点。有三种情况，DCS服务不可用，主库上的DCS Client挂了，从库上的DCS Client挂了。

### DCS Server宕机不可用

**==如果DCS挂了，当前主库会在retry_timeout 后Demote成从库，导致集群不可写==。**

```bash
# do this on control (stop the only consul server)
systemctl stop consul
```

失联后Patroni会等待`retry_timeout [default=10]`的时间，如果还没有恢复联系，就会Deomote Primary。

 重联后如果没有其他Leader，原来的Leader会停止standby状态，但这里因为没有发生promote，时间线维持不变。

```bash
2020-04-08 03:47:08,352 INFO: demoted self because DCS is not accessible and i was a leader
2020-04-08 03:47:08,354 WARNING: Loop time exceeded, rescheduling immediately.
2020-04-08 03:47:17,064 WARNING: Retry got exception: 500 No known Consul servers
```

如果某台主库连不上DSN，它无法判断自己到底是DCS挂了还是自己处于网络分区中。为了避免脑裂，需要将自己Demote拒绝写入。

实际上这个问题可以解决，如果Patroni之间有点对点通信，它们应当通过p2p的方式确认是DCS挂了，如果可以确认自己所处的分区是Major分区，则应当允许当前分区的主库继续服务。

曲线救国的办法是，有一些参数可以控制重试的行为，

* `retry_timeout`: 如果DCS失联时长低于此阈值，Primary不会Demote。这个值默认是30秒。

那么一个合理的选项就是使用报警系统监控Consul本身的健康，并为`retry_timeout`配置一个足够大的值（例如大于每年DCS SLA允许的最大值，或者人工响应需要的时长）。这样在集群进入不可写状态前，可以有足够的时间使Patroni进入维护模式。



### 主库上的DCS Client宕机不可用

**==如果主库上的DCS Client挂了，集群仍然可写可读，但读取的是陈旧副本，因为从库复制会中断。==**

如果主库的DCS Client挂了，但Patroni本身没有挂，其他的节点通过P2P通信仍然能感知到Primary的存在，因此在老主库Fencing掉之前，不会选主。于是系统就进入一种尴尬的状态。

```bash
# do this on node1 (stop primary server consul agent)
sudo systemctl stop consul
```

老Primary节点持有Leader Key，但因为连接不上Consul导致TTL超时。其他节点看到Leader key过期，准备进入Failover过程，但因为感知到老主库仍然存活，因而不得不等待老主库死去。在这个阶段，主库是可写的，从库是可读的，但主库到从库的复制被Patroni中断了。因此会积累出现复制延迟。

手工关闭老主库上的Patroni可以解决这一困境，重启Consul Agent后，老主库会重新作为从库加入集群。

配置Linux的Fencing watchdog是否可以避免这一困境有待验证

Consul官方对这一问题的解释是：

> The short answer is that as long as you have 3 or more Consul servers, Consul won't have a single point of failure. Having on Consul client on each node in your environment doesn't make things less resilient, as it's in the same failure domain as that host.



### 从库上的DCS Client宕机不可用

从库上的DCS Client挂了目前来看没什么直接影响，复制仍然会进行，依然可读。

但从库将无法参与选主与Failover。





## Case 9 Fencing

如果启用了Linux上的Watchdog，就可以确保Fencing

```bash
modprobe softdog
chown postgres /dev/watchdog
```

在测试的时候，可以指定不重启的选项，查看`dmesg`获取重启消息。

```
modprobe softdog soft_noboot=1
chown postgres /dev/watchdog
```





## Case 8: Standby Cluster

[Standby Cluster](https://patroni.readthedocs.io/en/latest/replica_bootstrap.html#standby-cluster)

```bash
# 抹掉patroni集群，但保留配置文件
./init-patroni.yml --tags=clean,setup

# 手工初始化一个非托管的Primary
./init-primary.yml
```

编辑2.testdb 3.testdb配置，在`bootstrap->dcs->standby_cluster`添加新主库的连接信息

```yml
bootstrap:
  dcs:
    standby_cluster:
      host: 10.10.10.11
      port: 5432
      create_replica_methods:
        - basebackup
```

启动Patroni，可以看到存在Standby Leader

```
+---------+----------+-------------+----------------+---------+----+-----------+
| Cluster |  Member  |     Host    |      Role      |  State  | TL | Lag in MB |
+---------+----------+-------------+----------------+---------+----+-----------+
|  testdb | 2.testdb | 10.10.10.12 | Standby Leader | running |  1 |           |
+---------+----------+-------------+----------------+---------+----+-----------+
```

这个功能对于迁移改造非常重要，可以做一个纯粹的从库集群，挂到现有主库上。然后将`Standby Leader` Promote成Real Leader即可。



## Case 9: Sync Standby

使用EditConfig修改

```
pt edit-config
```





## Case 10: Takeover existing cluster

验证已有集群可以被Patroni接管。

是可行的，只要保证填写的Replication用户存在，Patroni可以用于托管现存集群。



## Case 11: Failover with load

注意Checkpoint

```bash
# 初始化
pgbench -is10 postgres://dbuser_test:dbuser_test@primary.testdb.service.consul:6432/testdb

# 主库读写查询
pgbench -nv -c 3 -P 1 -T 1000 postgres://dbuser_test:dbuser_test@primary.testdb.service.consul:6432/testdb

# 从库只读查询
pgbench -nv --select-only -c 3 -P 1 -T 1000 postgres://dbuser_test:dbuser_test@standby.testdb.service.consul:6432/testdb
```



## Case