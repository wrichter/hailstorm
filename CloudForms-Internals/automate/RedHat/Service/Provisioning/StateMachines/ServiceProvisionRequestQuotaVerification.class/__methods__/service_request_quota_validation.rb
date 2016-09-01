#
# Description: This method validates the group and/or owner quotas in the following order:
# 1. Group model - This looks at the Instance for the following attributes:
# [max_group_cpu, warn_group_cpu, max_group_memory, warn_group_memory, max_group_storage,
# warn_group_storage, max_group_vms, warn_group_vms]
# 2. Group tags - This looks at the Group for the following tag values:
# [quota_max_cpu, quota_warn_cpu, quota_max_memory, quota_warn_memory, quota_max_storage,
# quota_warn_storage, quota_max_vms, quota_warn_vms]
#
def set_hash_value(sequence_id, option_key, value, options_hash)
  return if value.blank?
  $evm.log(:info, "Adding seq_id: #{sequence_id} key: #{option_key.inspect} value: #{value.inspect} to options_hash")
  options_hash[sequence_id][option_key] = value
end

# get_options_hash - Look for dialog variables in the dialog options hash that start with "dialog_option_[0-9]"
def get_options_hash(dialog_options)
  options_hash = Hash.new { |h, k| h[k] = {} }
  # Loop through all of the options and build an options_hash from them
  dialog_options.each do |k, v|
    if /^dialog_option_(?<sequence_id>\d*)_(?<option_key>.*)/i =~ k
      set_hash_value(sequence_id, option_key.downcase.to_sym, v, options_hash)
    else
      set_hash_value(0, k.downcase.to_sym,  v, options_hash)
    end
  end
  $evm.log(:info, "Inspecting options_hash: #{options_hash.inspect}")
  options_hash
end

def vmdb_object(object, id)
  $evm.vmdb(object).find_by_id(id)
end

def cores_per_socket(vmdb_object_find_by, service_type, options_array)
  flavor = $evm.vmdb(:flavor).find_by_id(vmdb_object_find_by)
  return false unless flavor

  message = service_type == 'none' ? "from dialog" : "from Catalog #{service_type}"
  $evm.log(:info, "Retrieving flavor #{flavor.name} cpus => #{flavor.cpus} #{message}")
  options_array << flavor.cpus
  true
end

def allocated_storage(vmdb_object_find_by, service_type, options_array)
  template = vmdb_object(:miq_template, vmdb_object_find_by)
  return false unless template

  $evm.log(:info, "Retrieving template #{template.name} allocated_disk_storage => #{template.allocated_disk_storage}")
  message = service_type == 'none' ? "from dialog" : "from Catalog #{service_type}"
  $evm.log(:info, "#{message}")
  options_array << template.allocated_disk_storage
  true
end

def vm_memory(vmdb_object_find_by, service_type, options_array)
  flavor = vmdb_object(:flavor, vmdb_object_find_by)
  return false unless flavor

  flavor_memory = flavor.memory / 1024**2
  message = service_type == 'none' ? "from dialog" : "from Catalog #{service_type}"
  $evm.log(:info, "Retrieving flavor #{flavor.name} memory => #{flavor.memory} #{message}")
  options_array << flavor_memory
  true
end

def default_option(prov_option, option_value, service_type, array)
  return if option_value.blank?

  message = service_type == 'none' ? "from dialog" : "from Catalog #{service_type}"
  $evm.log(:info, "Retrieving #{prov_option}=>#{option_value} #{message}")
  array << option_value
end

def options_value(prov_option, service_resource, service_type, options_array)
  return unless service_resource.resource.respond_to?('get_option')
  case prov_option
  when :allocated_storage
    option_set = allocated_storage(service_resource.resource.get_option(:src_vm_id), service_type, options_array)
  when :cores_per_socket
    option_set = cores_per_socket(service_resource.resource.get_option(:instance_type), service_type, options_array)
  when :vm_memory
    option_set = vm_memory(service_resource.resource.get_option(:instance_type), service_type, options_array)
  end
  return if option_set
  default_option(prov_option, service_resource.resource.get_option(prov_option), service_type, options_array)
end

def query_prov_options(prov_option, options_array = [])
  @service_template.service_resources.each do |child_service_resource|
    # skip catalog item if generic
    if @service_template.service_type == 'composite'
      next if child_service_resource.resource.prov_type == 'generic'
      child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
        options_value(prov_option, grandchild_service_template_service_resource, "bundle",  options_array)
      end
    else
      next if @service_template.prov_type.starts_with?("generic")
      options_value(prov_option, child_service_resource, "item",  options_array)
    end
  end
  options_array
end

def dialog_values(prov_option, options_hash, service_type, dialog_array)
  option_set = false
  options_hash.each do |_sequence_id, options|
    if prov_option == :cores_per_socket
      option_set = cores_per_socket(options[:instance_type], service_type, dialog_array)
    elsif prov_option == :vm_memory
      option_set = vm_memory(options[:instance_type], service_type, dialog_array)
    end
    next if option_set
    default_option(prov_option, options[prov_option], service_type, dialog_array)
  end
end

def decide_request_totals(template_totals, dialog_totals)
  template_totals < dialog_totals ? dialog_totals : template_totals
end

def collect_totals(prov_option, array)
  totals = array.collect(&:to_i).inject(&:+).to_i
  $evm.log(:info, "totals(#{prov_option.to_sym}): #{totals.inspect}") unless totals.zero?
  totals
end

def collect_template_totals(prov_option)
  collect_totals(prov_option, query_prov_options(prov_option))
end

def collect_dialog_totals(prov_option, options_hash)
  dialog_values(prov_option, options_hash, 'none', dialog_array = [])
  collect_totals(prov_option, dialog_array)
end

def get_total_requested(options_hash, prov_option)
  dialog_totals = collect_dialog_totals(prov_option, options_hash)
  template_totals = collect_template_totals(prov_option)

  total_requested = decide_request_totals(template_totals.to_i, dialog_totals.to_i)
  $evm.log(:info, "total_requested(#{prov_option.to_sym}): #{total_requested.inspect}")
  total_requested
end

def quota_message(key, value)
  $evm.log(:info, "#{@display_entity} using quota from model: {#{key} => #{value}}") unless value.zero?
end

def check_quotas(entity, quota_hash)
  # set group specific values
  entity_name = entity.description
  entity_type = 'Group'

  entity_consumption = current_consumption(entity)

  return unless entity_consumption

  @display_entity = "#{entity_type}: #{entity_name}"

  cpu_quota_check(entity, entity_consumption, quota_hash)

  memory_quota_check(entity, entity_consumption, quota_hash)

  storage_quota_check(entity, entity_consumption, quota_hash)

  vm_quota_check(entity, entity_consumption, quota_hash)
end

def storage_quota_check(entity, entity_consumption, quota_hash)
  $evm.log(:info, "#{@display_entity} storage alloc: #{entity_consumption[:allocated_storage]}(bytes)")
  max_group_storage = $evm.object['max_group_storage'].to_i
  quota_message('max_group_storage', max_group_storage)
  quota_max_storage = entity_tag_quota(:quota_max_storage, entity.tags(:quota_max_storage).first)
  quota_max_storage = max_group_storage if quota_max_storage.zero?
  args_hash = {:allocated  => entity_consumption[:allocated_storage] / 1024**3,
               :requested  => quota_hash[:total_storage_requested] / 1024**3,
               :limit      => quota_max_storage,
               :quota_hash => quota_hash,
               :unit       => "GB",
               :warn       => false,
               :item       => :group_storage_quota_exceeded}

  quota_check(args_hash) unless quota_max_storage.zero?

  warn_group_storage = $evm.object['warn_group_storage'].to_i
  quota_message('warn_group_storage', warn_group_storage)
  quota_warn_storage = entity_tag_quota(:quota_warn_storage, entity.tags(:quota_warn_storage).first)
  quota_warn_storage = warn_group_storage if quota_warn_storage.zero?
  return if quota_warn_storage.zero?

  args_hash[:limit] = quota_warn_storage
  args_hash[:warn]  = true
  args_hash[:item]  = :group_warn_storage_quota_exceeded
  quota_check(args_hash)
end

def vm_quota_check(entity, entity_consumption, quota_hash)
  $evm.log(:info, "#{@display_entity} current VMs allocated: #{entity_consumption[:vms]}")
  max_group_vms = $evm.object['max_group_vms'].to_i
  quota_message('max_group_vms', max_group_vms)
  quota_max_vms = entity_tag_quota(:quota_max_vms, entity.tags(:quota_max_vms).first)
  quota_max_vms = max_group_vms if quota_max_vms.zero? 
  args_hash = {:allocated  => entity_consumption[:vms],
               :requested  => quota_hash[:total_vms_requested],
               :limit      => quota_max_vms,
               :quota_hash => quota_hash,
               :unit       => "",
               :warn       => false,
               :item       => :group_vms_quota_exceeded}

  quota_check(args_hash) unless quota_max_vms.zero?

  warn_group_vms = $evm.object['warn_group_vms'].to_i
  quota_message('warn_group_vms', warn_group_vms)
  quota_warn_vms = entity_tag_quota(:quota_warn_vms, entity.tags(:quota_warn_vms).first)
  quota_warn_vms = warn_group_vms if quota_warn_vms.zero?

  return if quota_warn_vms.zero?
  args_hash[:limit] = quota_warn_vms
  args_hash[:warn]  = true
  args_hash[:item]  = :group_warn_vms_quota_exceeded
  quota_check(args_hash)
end

def cpu_quota_check(entity, entity_consumption, quota_hash)
  $evm.log(:info, "#{@display_entity} current vCPU allocated: #{entity_consumption[:cpu]}")
  max_group_cpu = $evm.object['max_group_cpu'].to_i
  quota_message('max_group_cpu', max_group_cpu)
  quota_max_cpu = entity_tag_quota(:quota_max_cpu, entity.tags(:quota_max_cpu).first)

  quota_max_cpu = max_group_cpu if quota_max_cpu.zero? 
  args_hash = {:allocated  => entity_consumption[:cpu],
               :requested  => quota_hash[:total_cpus_requested],
               :limit      => quota_max_cpu,
               :quota_hash => quota_hash,
               :unit       => "",
               :warn       => false,
               :item       => :group_cpu_quota_exceeded}

  quota_check(args_hash) unless quota_max_cpu.zero?

  warn_group_cpu = $evm.object['warn_group_cpu'].to_i
  quota_message('warn_group_cpu', warn_group_cpu)
  quota_warn_cpu = entity_tag_quota(:quota_warn_cpu, entity.tags(:quota_warn_cpu).first)
  quota_warn_cpu = warn_group_cpu if quota_warn_cpu.zero? 

  return if quota_warn_cpu.zero?
  args_hash[:limit] = quota_warn_cpu
  args_hash[:warn]  = true
  args_hash[:item]  = :group_warn_cpu_quota_exceeded
  quota_check(args_hash)
end

def memory_quota_check(entity, entity_consumption, quota_hash)
  $evm.log(:info, "#{@display_entity} current vRAM allocated: #{entity_consumption[:memory]}(bytes)")
  max_group_memory = $evm.object['max_group_memory'].to_i
  quota_message('max_group_memory', max_group_memory)
  # If entity is tagged then override
  quota_max_memory = entity_tag_quota(:quota_max_memory, entity.tags(:quota_max_memory).first)
  quota_max_memory = max_group_memory if quota_max_memory.zero? 
  args_hash = {:allocated  => entity_consumption[:memory] / 1024**2,
               :requested  => quota_hash[:total_memory_requested],
               :limit      => quota_max_memory,
               :quota_hash => quota_hash,
               :unit       => "MB",
               :warn       => false,
               :item       => :group_memory_quota_exceeded}

  quota_check(args_hash) unless quota_max_memory.zero?

  # If entity tagged with quota_warn_memory then override model
  warn_group_memory = $evm.object['warn_group_memory'].to_i
  quota_message('warn_group_memory', warn_group_memory)
  quota_warn_memory = entity_tag_quota(:quota_warn_memory, entity.tags(:quota_warn_memory).first)
  quota_warn_memory = warn_group_memory if quota_warn_memory.zero? 

  return if quota_warn_memory.zero?
  args_hash[:limit] = quota_warn_memory
  args_hash[:warn]  = true
  args_hash[:item]  = :group_warn_memory_quota_exceeded
  quota_check(args_hash)
end

def quota_check(args_hash)
  return unless quota_exceeded?(args_hash[:allocated].to_i, args_hash[:requested].to_i, args_hash[:limit].to_i)
  quota_exceeded(args_hash, args_hash[:item], reason(args_hash))
end

def current_consumption(entity)
  # count all entity vms that are not archived
  {
    :cpu                 => entity.allocated_vcpu,
    :memory              => entity.allocated_memory,
    :vms                 => entity.vms.select { |vm| vm.id unless vm.archived }.count,
    :allocated_storage   => entity.allocated_storage,
    :provisioned_storage => entity.provisioned_storage
  }
end

def entity_tag_quota(tag, tag_value)
  tag_value = tag_value.to_i
  $evm.log(:info, "#{@display_entity} using quota from tag: {#{tag} => #{tag_value}}") unless tag_value.zero?
  tag_value
end

def quota_exceeded?(allocated, requested, quota)
  allocated + requested > quota
end

def reason(args_hash)
  "#{args_hash[:item]} - #{args_hash[:allocated]}#{args_hash[:unit]} plus requested " \
  "#{args_hash[:requested]}#{args_hash[:unit]} &gt; quota #{args_hash[:limit]}#{args_hash[:unit]}"
end

def quota_exceeded(quota_hash, quota_hash_key, reason)
  quota_hash[:warn] ? (quota_hash[:quota_hash][:quota_warn_exceeded] = true) : (quota_hash[:quota_hash][:quota_exceeded] = true)
  $evm.log(:info, "#{@display_entity} #{reason}")
  quota_hash[:quota_hash][quota_hash_key] = reason
end

def quota_exceeded_message(quota_hash, type)
  case type
  when 'limit'
    message = "Service request denied due to the following quota limits: "
    warn = nil
  else
    message = "Service request warning due to the following quota thresholds: "
    warn = 'warn_'
  end
  message += "#{@display_entity} - "
  ["group_#{warn}cpu_quota_exceeded".to_sym,
   "group_#{warn}ram_quota_exceeded".to_sym,
   "group_#{warn}storage_quota_exceeded".to_sym,
   "group_#{warn}vms_quota_exceeded".to_sym].each do |q|
     message += "(#{quota_hash[q]}) " if quota_hash[q]
   end

  $evm.log(:info, "Inspecting quota_message: #{message}")
  @miq_request.set_message(message[0..250])
  @miq_request.set_option("service_quota_#{warn}exceeded".to_sym, message)
end

# get the request object from root
@miq_request = $evm.root['miq_request']
$evm.log(:info, "Request id: #{@miq_request.id} options: #{@miq_request.options.inspect}")

# Get dialog options from miq_request
dialog_options = @miq_request.options[:dialog]
$evm.log(:info, "Inspecting Dialog Options: #{dialog_options.inspect}")
options_hash = get_options_hash(dialog_options)

# lookup the service_template object
@service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
$evm.log(:info, "service_template id: #{@service_template.id} service_type: #{@service_template.service_type}")
$evm.log(:info, "services: #{@service_template.service_resources.count}")

# get the user and group objects
user = @miq_request.requester
group = user.current_group

quota_hash = {:quota_exceeded => false, :quota_warn_exceeded => false}

# specify whether quotas should be managed (valid options are [true | false])
manage_quotas_by_group = $evm.object['manage_quotas_by_group'] || true
if manage_quotas_by_group =~ (/(true|t|yes|y|1)$/i)
  quota_hash[:total_cpus_requested]     = get_total_requested(options_hash, :cores_per_socket)
  quota_hash[:total_memory_requested]   = get_total_requested(options_hash, :vm_memory)
  quota_hash[:total_storage_requested]  = get_total_requested(options_hash, :allocated_storage)
  quota_hash[:total_vms_requested]      = get_total_requested(options_hash, :number_of_vms)
  check_quotas(group, quota_hash)
end

$evm.log(:info, "quota_hash: #{quota_hash.inspect}")
if quota_hash[:quota_exceeded]
  quota_exceeded_message(quota_hash, 'limit')
  $evm.root['ae_result'] = 'error'
elsif quota_hash[:quota_warn_exceeded]
  quota_exceeded_message(quota_hash, 'threshold')
  $evm.root['ae_result'] = 'ok'
  # send a warning message that quota threshold is close
  $evm.instantiate('/Service/Provisioning/Email/ServiceTemplateProvisionRequest_Warning')
end
