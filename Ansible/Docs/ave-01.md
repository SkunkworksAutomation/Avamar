# Deploy Avamar, PowerProtect DD joined together with vCenter
````
---
# MISC
ad_domain: vcorp.local
artifact_path: /var/lib/awx/projects/common

# AVAMAR ave-01, or ave-02, 192.168.3.105 or 192.168.3.108
ave_host: ave-02
ave_old_pwd: changeme
ave_ip: 192.168.3.108
ave_netmask: 22
ave_gateway: 192.168.1.250
ave_dns: 192.168.1.11
ave_ntp: 192.168.1.11
ave_timezone: "America/Chicago"
ave_ova: AVE-19.4.0.124.ova

# POWERPROTECT DD ddve-01 or ddve-02, 192.168.3.110 or 192.168.3.111
ddve_host: ddve-02
ddve_acct: sysadmin
ddve_old_pwd: changeme
ddve_ip: 192.168.3.111
ddve_netmask: 255.255.252.0
ddve_gateway: 192.168.1.250
ddve_dns1: 192.168.1.11
ddve_dns2: 192.168.1.11
ddve_ova: ddve-7.10.0.20-1023227.ova
ddve_disk_size: 500
ddve_disk_type: thin
ddve_boost_user: boostuser
ddve_community_string: public

# VCENTER
vcenter_host: vc-01.vcorp.local
vcenter_dc: DC01-VC01
vcenter_ds: Unity-DS1
vcenter_folder: "/{{vcenter_dc}}/vm/Deploy/"
vcenter_network: VM Network
````