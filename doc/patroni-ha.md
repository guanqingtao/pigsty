# Patroni HA Drill

shortcuts:

```bash
alias pt='patronictl -c /pg/bin/patroni.yml'
```



## Case 1:  Show Cluster Status

```bash
[04-10 11:11:02] postgres@1.testdb:~
$ pt list
+---------+----------+-------------+--------+---------+----+-----------+
| Cluster |  Member  |     Host    |  Role  |  State  | TL | Lag in MB |
+---------+----------+-------------+--------+---------+----+-----------+
|  testdb | 1.testdb | 10.10.10.11 | Leader | running |  1 |           |
|  testdb | 2.testdb | 10.10.10.12 |        | running |  1 |         1 |
|  testdb | 3.testdb | 10.10.10.13 |        | running |  1 |         1 |
+---------+----------+-------------+--------+---------+----+-----------+
```



## Case 2: Switchover

You can watch the monitoring system for more detail: [http://g.pigsty/d/pg_cluster/pg-cluster?orgId=1&refresh=%202s](http://g.pigsty/d/pg_cluster/pg-cluster?orgId=1&refresh= 2s)

```bash
[04-10 11:11:03] postgres@1.testdb:~
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



## Case 3: DCS Down



## Case 4: Standby Down



## Case 5: Primary Down



## Case 6: Promote outside



## Case 7: Managing Existing Cluster



## Case 8: Standby Cluster



## Case 9: Sync Standby