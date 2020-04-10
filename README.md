# Pigsty - PostgreSQL Deploy Template

> PIGSTY: Postgres Installation Graphic Standard Template.Yaml

This repo provides a PostgreSQL testing environment based on [vagrant](https://vagrantup.com/) consist of 4 vm nodes.

It is a template for illustrating some practice about running PostgreSQL in real world. A minimal HA cluster consist of 3 nodes (primary, standby, offline) and a battery included control center (monitoring, alerting, DCS, HA, yum..)



## Architecture

![](doc/img/architecture.png)



## Quick Start

1. Install [vagrant](https://vagrantup.com/) and [virtualbox](https://www.virtualbox.org/)
2. `git clone https://github.com/vonng/pigsty && cd pigsty`
3. `make dns` (one-time job, write DNS records to `/etc/hosts`)
4. `make` (pull up vm cluster)
5. `make control` (setup control node)
6. `make init` (init database cluster)

7. Open http://pigsty  (pigsty is a local dns record created in step 3 )

Then you will have a running PostgreSQL cluster with a battery included monitoring/managing system.



## What's Next?

* Explore the monitoring system
* Add some load to cluster
* HA scenario
* Managing postgres cluster with ansible
* blah blah...



## File structure

* [control](control/) contains resource for control node: yum rpms, scripts, ansible playbooks, monitoring system,...
* [ansible](ansible/) contains ansible playbooks to manage this database cluster





## About

Author：Vonng ([fengruohang@outlook.com](mailto:fengruohang@outlook.com))
