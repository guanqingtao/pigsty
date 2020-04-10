# Control Ndoe

Control node is a special vm in pigsty which is consist of several major components:

* Yum:  a nginx server listen @ 80 (for yum and all )
* Dashboards: grafana server listen @ 3000
* Montoring:  prometheus server listen @ 9090
* Alerting:   alertmanager server listen @ 9093
* Consul:     consul DCS service listen @ 8500

http://c.control    -> Consul       @ 8500
http://g.control    -> Grafana      @ 3000
http://p.control    -> Prometheus   @ 9090
http://am.control   -> Alertmanager @ 9093

 