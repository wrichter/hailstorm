
def log(level, message)
  @method = 'OSE_PostValidation'
  $evm.log(level, "#{@method}: #{message}")
end

def create_tag(category, name, description)
  $evm.execute('tag_create', "#{category}", :name => "#{name}", :description => "#{description}")
  log(:info, "Creating Tag -->> #{category}/#{name}")
end


if $evm.execute('category_exists?', "osepolicy")
  log(:info, "Classification osePOLICY exists")
else
  log(:info, "Classification osePOLICY doesn't exist, creating category")
  $evm.execute('category_create', :name => "osepolicy", :single_value => false, :description => "OSE Policy")

  create_tag("osepolicy","broker","Broker")
  create_tag("osepolicy","msgserver","msgServer")
  create_tag("osepolicy","dbserver","dbServer")
  create_tag("osepolicy","node","Node")
  create_tag("osepolicy","nameserver","nameserver")
end

if $evm.execute('category_exists?', "osestate")
  log(:info, "Classification oseSTATE exists")
else
  log(:info, "Classification oseSTATE doesn't exist, creating category")
  $evm.execute('category_create', :name => "osestate", :single_value => false, :description => "OSE Status")

  create_tag("osestate","completed_broker","Completed Broker")
  create_tag("osestate","completed_node","Completed Node")
  create_tag("osestate","completed_msgserver","Completed msgServer")
  create_tag("osestate","completed_dbserver","Completed dbServer")
  create_tag("osestate","completed_ose","Completed OpenShift Enterprise")

  create_tag("osestate","failed_broker","Failed Broker")
  create_tag("osestate","failed_node","Failed Node")
  create_tag("osestate","failed_msgserver","Failed msgServer")
  create_tag("osestate","failed_dbserver","Failed dbServer")
  create_tag("osestate","failed_ose","Failed OpenShift Enterprise")

  create_tag("osestate","progress_broker","In Progress Broker")
  create_tag("osestate","progress_node","In Progress Node")
  create_tag("osestate","progress_msgserver","In Progress msgServer")
  create_tag("osestate","progress_dbserver","In Progress dbServer")
  create_tag("osestate","pending_ose","In Progress OpenShift Enterprise")
end

  
