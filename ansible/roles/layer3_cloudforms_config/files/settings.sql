-- enable roles
update settings_changes set value='--- automate,database_operations,ems_inventory,ems_metrics_collector,ems_metrics_coordinator,ems_metrics_processor,ems_operations,event,reporting,scheduler,smartproxy,smartstate,user_interface,web_services,websocket\n---\n' where key='/server/role';

-- enable NTP
update settings_changes set value='---\n- 192.168.101.1\n' where key='/ntp/server';

-- set Company
DO
$do$
BEGIN
  IF NOT EXISTS (select key,value from settings_changes where key='/server/company') THEN
    insert into settings_changes (key,value,created_at,updated_at,resource_type,resource_id) VALUES ('/server/company','--- Hailstom\n...\n',now(),now(),'MiqServer',(select id from miq_servers));
  END IF;
END
$do$

