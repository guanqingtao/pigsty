# Consul Service Discovery



## 重要概念

在Postgres集群管理中，有如下概念：

* Cluster：一个数据库集簇，包含一台或多个内容相同的实例，**共同组成一个业务服务单元**。本例中定义了一个名为`testdb`的数据库集群。
* Service：同一个数据集簇中的角色划分，服务的命名规则为：`{{ role }}.{{ cluster }}`，目前只有两种：`primary.testdb`和`standby.testdb`。前者提供读写服务，后者提供只读副本服务。前者有且仅有一个实例，后者可能包含零至任意个具体实例。
* Instance：一个具体的数据库服务器，在同一个数据库集簇中采用从1开始的固定自增唯一序号来区分，例如`1.testdb`, `2.testdb`, `3.testdb`。

* Node：一台机器，唯一标识符为IP地址，以及机器的`hostname`。

Consul Agent与Node一一对应。尽管PG单机多实例的情景是存在的，但这里为了简单起见，我们假设部署时统一采用单机单实例的模式，即Instance与Node一一对应。



## 相关知识与约定

Consul是一个类似于etcd，zookeeper的开源分布式共识数据库（DCS），可用于服务发现，元数据管理，域名解析，高可用选主等。

**Consul配置文件**

Consul 的主配置文件位于 `/etc/consul.d/consul.json`

```json
{
  "datacenter": "pigsty",
  "node_name": "{{ instance_name }}",
  "data_dir": "/var/lib/consul",
  "bind_addr": "{{ inventory_hostname }}",
  "retry_join": ["10.10.10.10"],
  "log_level": "INFO",
  "server": false,
  "ui": false,
  "enable_script_checks": true
}
```

这里，重要的配置是`node_name`，会被动态设置为`{{ instance_name }}`，也就是`{{ seq }}.{{ cluster }}`。例如，`testdb`集群中标号为1的机器实例将被命名为`1.testdb`。这个名称将被设置为机器的HOSTNAME，同时也会被设置为consul节点的`node_name`，并在整个集群生命周期中保持不变。

`bind_addr`将绑定服务网卡的IP地址，在本环境中为`10.10.10.X`。

**Consul服务定义**

通过服务定义配置文件，Consul Agent会像Consul Server注册并维护检查本节点上的服务，每个服务都有一个独立的配置文件，同样位于 `/etc/consul.d/`目录下，以`srv-`开头命名，后面接服务的`name`，以`.json`结尾。例如`srv-node_exporter.json`里面就包含了`node_exporter`的服务定义，其内容模版如下：

```json
{"service": {
  "name": "node_exporter",
  "port": 9100,
  "meta": {
    "type": "exporter",
    "role": "${role}",
    "cluster": "{{ cluster }}",
    "service": "${role}.{{ cluster }}",
    "instance": "{{seq}}.{{ cluster }}"
  },
  "tags": ["exporter"],
  "check": {"http": "http://{{ inventory_hostname }}:9100/", "interval": "5s"}
}}
```

**Consul服务的Meta**

每个服务都有与之关联的meta，包含了服务相关的元数据。

**Consul服务的Tag**

每个服务都有与之关联的tag，Tag类似于meta，但却是专门针对过滤筛选的场景而定义，与DNS解析关系紧密。

例如，想要筛选出带有`primary`标签的`postgres`服务，可以通过以下DNS进行查询

```bash
dig @127.0.0.1 -p 8600 primary.postgres.service.consul
```

**Consul UI 面板**

* 列出所有服务：http://c.pigsty/ui/pigsty/services
* 列出所有节点：http://c.pigsty/ui/pigsty/nodes
* 列出Node1上的所有服务：http://c.pigsty/ui/pigsty/nodes/1.testdb

* Patroni的KV元数据：http://c.pigsty/ui/pigsty/kv/pg/testdb/



## 具体服务

目前，Pigsty中所有的服务如下所示

![](img/consul.png)

| Service                                                      | Port       | Tags                     |
| :----------------------------------------------------------- | ---------- | :----------------------- |
| [prometheus](http://c.pigsty/ui/pigsty/services/prometheus)  | 9090       | control                  |
| [alertmanager](http://c.pigsty/ui/pigsty/services/alertmanager) | 9093       | control                  |
| [grafana](http://c.pigsty/ui/pigsty/services/grafana)        | 3000       | control                  |
| [nginx](http://c.pigsty/ui/pigsty/services/nginx)            | 80         | control                  |
| [consul](http://c.pigsty/ui/pigsty/services/consul)          | 8500, 8600 | control  consul          |
| [node_exporter](http://c.pigsty/ui/pigsty/services/node_exporter) | 9100       | exporter                 |
| [pg_exporter](http://c.pigsty/ui/pigsty/services/pg_exporter) | 9630       | exporter                 |
| [pgbouncer_exporter](http://c.pigsty/ui/pigsty/services/pgbouncer_exporter) | 9631       | exporter                 |
| [patroni](http://c.pigsty/ui/pigsty/services/patroni)        | 8008       | primary  testdb  standby |
| [pgbouncer](http://c.pigsty/ui/pigsty/services/pgbouncer)    | 6432       | primary  testdb  standby |
| [postgres](http://c.pigsty/ui/pigsty/services/postgres)      | 5432       | primary  testdb  standby |
| [testdb](http://c.pigsty/ui/pigsty/services/testdb)          | 5432       | primary standby 1 2 3    |

其中，带有Control标签的是中控机/管理节点node0上的服务，可以忽略。

在普通DB节点上，Consul上注册的服务包括：

* consul (node level)：用于服务发现，选主，健康检测的Consul Agent
* node_exporter (node level)：节点监控指标
* patroni (ins level)：HA Agent
* postgres (ins level)：Postgres服务本体
* pgbouncer (ins level)：Postgres连接池中间件
* pg_exporter (ins level)：Postgres监控指标
* pgbouncer_exporter (ins level)：连接池中间件监控指标

此外，还有一个特殊的服务`{{ cluster }}`，本例中为`testdb`，它实际上是Postgres或Pgbouncer的服务别名，通过Consul DNS的标签机制，可以同时动态解析集群`Cluster`，`Service`, `Instance` 三个级别的域名。

```ini
# Cluster level domain name
testdb

# Service level domain name
primary.testdb
standby.testdb

# Instance level domain nameo
1.testdb
2.testdb
3.testdb
```

这里，`primary`, `standby`, `1`, `2`, `3` 都是`testdb`这个虚拟服务的Tag，作为Consul DNS查询的Filter。

所以一个PG服务，包含了围绕它的5个服务（postgres, pgbouncer, pg_exporter, pgbouncer_exporter, patroni），其中，postgres是服务本体，其他的都是1:1对应的Sidecar。另外考虑到单机单实例部署的假设，我们可以将`node_exporter`也视作与Postgres服务一一对应的Sidercar Service。

此外，还有一个特殊的服务，以集群名称命名，例如：`testdb`，这类服务其实是 postgres（或pgbouncer）的别名，通过`primary`与`standby`的标签，实现动态的服务发现。下面会详细介绍



## Consul服务

这里，以`1.testdb`为例，介绍DB节点上注册的服务



## Consul

Consul本身也是一个服务，本地8500端口。

```json
{"service": {
    "name": "consul",
    "port": 8500,
    "tags": ["consul"],
    "check": {"http": "http://localhost:8500/","interval": "5s"}
}}
```





## Postgres

Postgres是数据库的核心服务，PG默认监听5432端口。

```json
{"service": {
    "name": "postgres",
    "port": 5432,
    "meta": {
        "type": "postgres",
        "role": "primary",
        "cluster": "testdb",
        "service": "primary.testdb",
        "instance": "1.testdb"
    },
    "tags": ["primary", "testdb"],
    "check": {"tcp": "10.10.10.11:5432", "interval": "5s"}
}}
```

因为带有`primary`与`testdb`两个标签，可以通过DNS接口列出某个集群的所有机器，以及所有的集群主库或从库

```bash
# 找出集群testdb的所有机器
dig testdb.postgres.service.consul

# 找出所有集群的主库
dig primary.postgres.service.consul
```



## Pgbouncer

Pgbouncer是PG数据库的连接池中间件，可以提高系统的整体性能，并引入更灵活的流量控制。

Pgbouncer监听6432端口，使用与Postgres同样的元数据。元数据中`type=postgres`是因为Pgbouncer使用起来和Postgres没有什么区别，所以是一个（伪）Postgres服务。

```json
{"service": {
    "name": "pgbouncer",
    "port": 6432,
    "meta": {
        "type": "postgres",
        "role": "primary",
        "cluster": "testdb",
        "service": "primary.testdb",
        "instance": "1.testdb"
    },
    "tags": ["primary", "testdb"],
    "check": {"tcp": "10.10.10.11:6432", "interval": "5s"}
}}
```



## Patroni

[Patroni](https://github.com/zalando/patroni) 是一个开源的Postgres HA模板。它本身是一个部署在数据库机器上的Agent，用于管理Postgres实例。

Patroni监听8008端口，提供了RestAPI用于健康检查，流量分发，以及控制。

```json
{"service": {
    "name": "patroni",
    "port": 8008,
    "meta": {
        "type": "patroni",
        "role": "primary",
        "cluster": "testdb",
        "service": "primary.testdb",
        "instance": "1.testdb"
    },
    "tags": ["primary", "testdb"],
    "check": {"tcp": "10.10.10.11:8008", "interval": "5s"}
}}
```



## 特殊服务{{ cluster }}

这个是对外提供服务的DNS域名，它实际上是Pgbouncer服务的别名。

假设cluster的名字为`testdb`，那么该服务的定义文件位于`/etc/consul.d/srv-testdb.json`。

该服务的元数据中使用了特殊的`type=db`，表明这是一个提供实际数据库服务的Service。

```json
{"service": {
    "name": "testdb",
    "port": 6432,
    "meta": {
        "type": "db",
        "role": "primary",
        "cluster": "testdb",
        "service": "primary.testdb",
        "instance": "1.testdb"
    },
    "tags": ["primary", "1"],
    "check": {
        "http": "http://10.10.10.11:8008/master", "interval": "5s"
    }
}}
```

这个服务会使用`{{ role }}` 和 `{{ seq }}`作为自己的标签，所以外部应用可以通过DNS的方式通过`{{ role }}.testdb.service.consul`和`{{ seq }}.testdb.service.consul`找到该服务。

实际效果就是，可以通过`primary.testdb`和`standby.testdb`动态定位到对应的服务，也可以通过`1.testdb`,`...`,`n.testdb`定位到具体的实例。

```ini
# Cluster level domain name
testdb

# Service level domain name
primary.testdb
standby.testdb

# Instance level domain nameo
1.testdb
2.testdb
3.testdb
```

这里，`primary`, `standby`, `1`, `2`, `3` 都是`testdb`这个虚拟服务的Tag，作为Consul DNS查询的Filter。







## Node Exporter

Node Exporter向prometheus暴露节点的监控指标，尽管单机多实例部署是可能的，但为了简单起见，我们仍然将NodeExporter视作Instance级别的服务。

带有`exporter`标签的服务会被Prometheus作为抓取对象，Exporter有三个：`node_exporter, pg_exporter, pgbouncer_exporter`。其共性为服务元数据中都包含`role`, `cluster` `service` ,`instance`四个标签。这四个标签会作为Prometheus指标中的维度（`role`, `cls`, `srv`, `ins`）用于监控与报警。

```json
{"service": {
  "name": "node_exporter",
  "port": 9100,
  "meta": {
    "type": "exporter",
    "role": "primary",
    "cluster": "testdb",
    "service": "primary.testdb",
    "instance": "1.testdb"
  },
  "tags": ["exporter"],
  "check": {"http": "http://10.10.10.11:9100/", "interval": "5s"}
}}
```



## PG Exporter

[PG Exporter](https://github.com/Vonng/pg_exporter)是我编写的用于Postgres与Pgbouncer的监控组件，可以抓取数据库与连接池的监控指标。`pg_exporter`默认监听9630端口。带有`exporter`标签的服务会被Prometheus作为抓取对象。

 ```json
{"service": {
  "name": "pg_exporter",
  "port": 9630,
  "meta": {
    "type": "exporter",
    "role": "primary",
    "cluster": "testdb",
    "service": "primary.testdb",
    "instance": "1.testdb"
  },
  "tags": ["exporter"],
  "check": {"http": "http://10.10.10.11:9630/", "interval": "5s"}
}}
 ```



## PGB Exporter

`pgbouncer_exporter` 与`pg_exporter`使用同样的二进制程序与配置文件，但`pgbouncer_exporter`监听9631端口，抓取连接池的指标。带有`exporter`标签的服务会被Prometheus作为抓取对象。



```json
{"service": {
    "name": "pgbouncer_exporter",
    "port": 9631,
    "meta": {
        "type": "exporter",
        "role": "primary",
        "cluster": "testdb",
        "service": "primary.testdb",
        "instance": "1.testdb"
    },
    "tags": ["exporter"],
    "check": {"http": "http://10.10.10.11:9631/", "interval": "5s"}
}}
```







## 服务变更

当数据库发生Switchover与Failover时，应当修改注册服务中的角色（`{{ role }}`），以便反映数据库的真实情况。脚本[`/pg/bin/register.sh`](../ansible/templates/register.sh)用于完成这项工作。

```bash
# 将本机服务的元数据修改为 cluster=testdb role=primary
register.sh primary testdb

# 将本机服务的元数据修改为 cluster=testdb role=standby
register.sh standby testdb
```

当通过Patroni进行Failover操作时，Patroni的回调脚本[`/pg/bin/callback.sh`](../ansible/templates/callback.sh)会调用上面的`register.sh`完成身份变更工作。


