-- enable roles
update settings_changes set value='--- automate,database_operations,ems_inventory,ems_metrics_collector,ems_metrics_coordinator,ems_metrics_processor,ems_operations,event,notifier,reporting,scheduler,smartproxy,smartstate,user_interface,web_services,websocket\n---\n' where key='/server/role';

-- enable NTP
update settings_changes set value='---\n- 192.168.101.1\n' where key='/ntp/server';

-- update company name
update settings_changes set value='--- Hailstorm\n...\n' where key='/server/company';

-- update Time Zone
update settings_changes set value='--- Berlin\n...\n' where key='/server/timezone';

DO
$do$
BEGIN

-- set roles if they haven't been set before
  IF NOT EXISTS (select * from settings_changes where key='/server/role') THEN
    insert into settings_changes (key,value,created_at,updated_at,resource_type,resource_id) VALUES ('/server/role','--- automate,database_operations,ems_inventory,ems_metrics_collector,ems_metrics_coordinator,ems_metrics_processor,ems_operations,event,notifier,reporting,scheduler,smartproxy,smartstate,user_interface,web_services,websocket\n---\n',now(),now(),'MiqServer',(select id from miq_servers));
  END IF;

-- set NTP if it hasn't been set before
  IF NOT EXISTS (select * from settings_changes where key='/ntp/server') THEN
    insert into settings_changes (key,value,created_at,updated_at,resource_type,resource_id) VALUES ('/ntp/server','---\n- 192.168.101.1\n',now(),now(),'MiqServer',(select id from miq_servers));
  END IF;

-- set company name
  IF NOT EXISTS (select key,value from settings_changes where key='/server/company') THEN
    insert into settings_changes (key,value,created_at,updated_at,resource_type,resource_id) VALUES ('/server/company','--- Hailstom\n...\n',now(),now(),'MiqServer',(select id from miq_servers));
  END IF;

-- set Time Zone
  IF NOT EXISTS (select key,value from settings_changes where key='/server/timezone') THEN
    insert into settings_changes (key,value,created_at,updated_at,resource_type,resource_id) VALUES ('/server/timezone','--- Berlin\n...\n',now(),now(),'MiqServer',(select id from miq_servers));
  END IF;

-- create storage C&U tag
 IF NOT EXISTS (select * from tags where name='/performance/storage/capture_enabled') THEN
    insert into tags (name) values ('/performance/storage/capture_enabled');
  END IF;

-- create host and cluster C&U tag
 IF NOT EXISTS (select * from tags where name='/performance/host_and_cluster/capture_enabled') THEN
    insert into tags (name) values ('/performance/host_and_cluster/capture_enabled');
  END IF;

-- enable C&U for all storages
 IF NOT EXISTS (select * from taggings where tag_id=(select id from tags where name='/performance/storage/capture_enabled')) THEN
    insert into taggings (taggable_id,tag_id,taggable_type) values ((select id from miq_regions),(select id from tags where name='/performance/storage/capture_enabled'),'MiqRegion');
  END IF;

-- enable C&U for all Hosts and Clusters
  IF NOT EXISTS (select * from taggings where tag_id=(select id from tags where name='/performance/host_and_cluster/capture_enabled')) THEN
    insert into taggings (taggable_id,tag_id,taggable_type) values ((select id from miq_regions),(select id from tags where name='/performance/host_and_cluster/capture_enabled'),'MiqRegion');
  END IF;
END;
$do$
