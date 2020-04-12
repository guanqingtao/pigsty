# Pigsty - PostgreSQL Deploy Template

> PIGSTY: Postgres Installation Good Standard Template.Yaml 😂

This project provides a PostgreSQL testing environment based on [vagrant](https://vagrantup.com/). 

It is a template for setup, deploying, monitoring, managing a high available PostgreSQL cluster.

Minimal PG HA cluster consist of 3 DB nodes managed by [patroni](https://github.com/zalando/patroni). 

A battery included control node including a series of ansible playbooks and a powerful monitoring system.

![](doc/img/pg-cluster.png)

![](doc/img/pg-instance.png)

![](doc/img/consul.png)



## Quick Start

1. Install [vagrant](https://vagrantup.com/) and [virtualbox](https://www.virtualbox.org/)
2. `git clone https://github.com/vonng/pigsty && cd pigsty`
3. `make dns` (one-time job, write DNS records to `/etc/hosts`)
4. `./build.sh` (pull up vm cluster, setup control node and init postgres cluster)
5. Open http://pigsty to explore (pigsty is a local dns record created in step 3 )

Then you will have a running PostgreSQL cluster with a battery included monitoring/managing system.

> **Tips**: bootstrap pigsty may takes a long time to download yum packages. Once you have a functional pigsty instance. Run `make cache` to copy rpm packages to `pigsty/control/yum`, so next time it would be much faster (15min to 1min)

6. Do whatever you like to explore Postgres

```bash
# for example, pgbench default database
pgbench postgres://dbuser_test:dbuser_test@primary.testdb.service.consul:5432/testdb -i -s 10

# bench primary service
pgbench postgres://dbuser_test:dbuser_test@primary.testdb.service.consul:6432/testdb -n -v -T 100

# bench standby service
pgbench postgres://dbuser_test:dbuser_test@standby.testdb.service.consul:6432/testdb --select-only -n -v -T 100
```





## Architecture

![](doc/img/architecture.png)

This cluster contains 4 nodes running following services:

| Node  | IP          | Default Role       | Service                                                      |
| ----- | ----------- | ------------------ | ------------------------------------------------------------ |
| node0 | 10.10.10.10 | control node       | Nginx, Grafana, Prometheus, Altermanger, Dnsmasq, PgAdmin4, Consul |
| node1 | 10.10.10.11 | 1.testdb (primary) | consul, postgres, pgbouncer, patroni, node_exporter, pg_exporter, pgbouncer_exporter |
| node2 | 10.10.10.12 | 2.testdb (standby) | same as above                                                |
| node3 | 10.10.10.13 | 3.testdb (standby) | same as above                                                |

**Control Node Services** 

* Nginx (10.10.10.10:80)：Local yum server, and proxy for grafana, prometheus, alertmanager, consul, etc...
* Yum (10.10.10.10:80): http://yum.pigsty/pigsty/
* Consul (10.10.10.10:8500): http://c.pigsty/
* Consul DNS Service (10.10.10.10:8600)
* Grafana (10.10.10.10:3000): http://g.pigsty/
* Prometheus (10.10.10.10:9090): http://p.pigsty/
* AlertManager (10.10.10.10:9093): http://am.pigsty/

* DNSMASQ (10.10.10.10:53)

**DB Node Services**

* consul (:8500) agent mode
* postgres (:5432) major service
*  pgbouncer (:6432) connection pool
* patroni (:8008) HA agent
* node_exporter (:9100) prometheus machine metrics collector 
* pg_exporter (:9630) prometheus postgres metrics collector
* pgbouncer_exporter (:9630) prometheus pgbouncer metrics collector

**Domain Names**

Default database cluster is named 'testdb'

`testdb` is a virtual service registered to consul, which have optional tags: `primary`, `standby` ,`1`,`2`,`3`. You can discover these services via common domain names. 

* TestDB primary service domain name: `primary.testdb.service.consul`
* TestDB standby service domain name: `standby.testdb.service.consul` 

**DSN**

Default database name: `testdb`, default business user is `dbuser_test` and password is `dbuser_test` too

```bash
# connect to primary
psql postgres://dbuser_test:dbuser_test@primary.testdb.service.consul:5432/testdb

# conntect to standby (random choose one)
psql postgres://dbuser_test:dbuser_test@standby.testdb.service.consul:5432/testdb
```





## What's Next?

* Explore the monitoring system
* [How service discovery works](doc/consul_sd.md)
* Add some load to cluster
* Managing postgres cluster with ansible
* [Patroni HA Drill](doc/patroni-ha.md)





## About

Author：Vonng ([fengruohang@outlook.com](mailto:fengruohang@outlook.com))

LICENSE: [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)