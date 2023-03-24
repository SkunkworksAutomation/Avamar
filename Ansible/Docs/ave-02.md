# Deploy x2 Avamar vProxies to vCenter
````
---
# MISC
ad_domain: vcorp.local

# AVAMAR
ave_host: ave-01
ave_proxy_host1: ave-proxy-01
ave_proxy_host2: ave-proxy-02
ave_proxy_ip1: 192.168.3.112
ave_proxy_ip2: 192.168.3.114
ave_proxy_netmask: 255.255.252.0
ave_gateway: 192.168.1.250
ave_dns: 192.168.1.11
ave_ntp: 192.168.1.11

# VCENTER

vcenter_cluster1: Cluster01
vcenter_cluster2: Cluster02
vcenter_esx1: host-1379
vcenter_esx2: host-5602
vcenter_ds: datastore-6764

vcenter_dc: DC01-VC01

vcenter_network: network-1363
````