#!/bin/sh
# vim:sw=2:ts=2:sts=2:et

# NAP startup - duplicated from KIC https://github.com/nginxinc/kubernetes-ingress/blob/main/internal/nginx/manager.go
if [ -x "/opt/app_protect/bin/set_log_level" ]
then
  # Start NAP daemons
  /opt/app_protect/bin/set_log_level info 
  /usr/bin/perl /opt/app_protect/bin/bd_agent &
  LD_LIBRARY_PATH=/usr/lib64/bd /usr/share/ts/bin/bd-socket-plugin tmm_count 4 proc_cpuinfo_cpu_mhz 2000000 total_xml_memory 471859200 total_umu_max_size 3129344 sys_max_account_id 1024 no_static_config &

  # Load the modules
  sed -i '/^worker_processes.*/a load_module modules/ngx_http_app_protect_module.so;' /etc/nginx/nginx.conf
fi


