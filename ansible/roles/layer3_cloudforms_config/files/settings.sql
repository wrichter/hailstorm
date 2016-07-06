# enable roles
update settings_changes set value='--- automate,database_operations,ems_inventory,ems_metrics_collector,ems_metrics_coordinator,ems_metrics_processor,ems_operations,event,reporting,scheduler,smartproxy,smartstate,user_interface,web_services,websocket\n---\n' where key='/server/role';

# enable NTP
update settings_changes set value='---\n192.168.101.1\n' where key='/ntp/server';

