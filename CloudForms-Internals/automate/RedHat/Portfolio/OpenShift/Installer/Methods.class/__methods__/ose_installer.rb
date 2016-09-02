#################################################################################
# OSE Installer
#
# Main OSE installer. Processes the OSE policy assigned to the resources in the service.
# Creates the OO-Install-OSE configuration YAML and executes the installation.
#
#

require 'rubygems'
require 'fileutils'
require 'pty'

$evm.root['osePhase'] = "Installer"


f = File.open("/tmp/sequence.log", "a")
f.puts "OSEInstaller"
f.close

#exit MIQ_OK

def log(level, message)
  @method = 'OSE_Installer'
  $evm.log(level, "#{@method}: #{message}")
end

10.times { log(:info, "************ ose_installer ***************") }


@data = {}
@serverCollection = Array.new

def preConfig ()
  @data = {"Vendor" => "OpenShift Origin Community",
           "Name" => "OpenShift Installer Configuration",
           "Version" => "0.0.1",
           "Description" => "This is the configuration file for the OpenShift Installer."
  }
  @dataDNS = writeDNS()
end

def writeHosts (vm)
  roles = writeRoles(vm)
  dataHOSTS = Hash.new
  hostname = vm.custom_get("hostname").to_s
  hostname = hostname.strip
  if @num_of_vms == 1
    dataHOSTS = {
        "state" => "new",
        "host" => hostname,
        "ip_addr" => vm.ipaddresses[0],
        "ip_interface" => "eth0",
        "named_ip_addr" => vm.ipaddresses[0],
        "ssh_host" => hostname,
        "user" => @sshUser,
        "mcollective_user" => @mcollective_user,
        "mcollective_password" => @mcollective_password,
        "mongodb_broker_user" => @mongodb_broker_user,
        "mongodb_broker_password" => @mongodb_broker_password,
        "openshift_user" => @ose_user,
        "openshift_password" => @ose_password,
        "node_profile" => @ose_size,
        "district" => "default-#{@ose_size}",
        "valid_gear_sizes" => @valid_gear_sizes,
        "default_gear_capabilities" => @default_gear_capabilities,
        "default_gear_size" => @ose_size,
        "district_mappings" => {"default-#{@ose_size}" => ["#{hostname}"]},
        "roles" => roles
    }
  else
    dataHOSTS = {
        "host" => hostname,
        "state" => "new",
        "ip_addr" => vm.ipaddresses[0],
        "ip_interface" => "eth0",
        "ssh_host" => hostname,
        "user" => @sshUser,
        "named_ip_addr" => vm.ipaddresses[0],
        "mcollective_user" => @mcollective_user,
        "mcollective_password" => @mcollective_password,
        "mongodb_broker_user" => @mongodb_broker_user,
        "mongodb_broker_password" => @mongodb_broker_password,
        "openshift_user" => @ose_user,
        "openshift_password" => @ose_password,
        "node_profile" => @ose_size,
        "district" => "default-#{@ose_size}",
        "valid_gear_sizes" => @valid_gear_sizes,
        "default_gear_capabilities" => @default_gear_capabilities,
        "default_gear_size" => @ose_size,
        "district_mappings" => {"default-#{@ose_size}" => ["#{hostname}"]},
        "roles" => roles
    }
  end
  @serverCollection << dataHOSTS
  return dataHOSTS
end

def writeDNS()
  dataDNS = Hash.new
  dataDNS = {
      "register_components" => @registerComponents,
      "app_domain" => @appDomain,
      "component_domain" => @componentDomain
  }
  return dataDNS
end

def writeRoles(vm)
  tmpPolicy = Array.new
  osePolicy = vm.tags(:osepolicy)
  osePolicy.each do |policy|
    log(:info, "osePolicy Found - #{policy}")
    tmpPolicy << policy
  end
  return tmpPolicy
#  @data.store("roles", tmpPolicy)
end

def writeSubscription()
  case @sub_type
    when "none"
      dataSUB = {
          "type" => @sub_type,
      }

    when "rhn"
      dataSUB = {
          "rh_username" => @sub_rh_username,
          "type" => @sub_type,
          "rh_password" => @sub_rh_password
      }

    when "rhsm"
      log(:info, "RHSM Not supported")

    when "yum"
      log(:info, "YUM Not supported")

    else
      log(:info, "UNKNOWN Subscription Type")
      exit MIQ_ABORT
  end
  return dataSUB
end

def assignTag(tag, vm)
  category = "osestate"
  t = "progress_" + tag
  tag_to_assign = category + "/" + t
  log(:info, "Assigning Tag --> #{tag_to_assign}")
  vm.tag_assign(tag_to_assign)
end

#grab the service object
service_template_provision_task = $evm.root['service_template_provision_task']
if service_template_provision_task == nil
  service = $evm.root['service']
else
  service = service_template_provision_task.destination
  $evm.root['service_template_provision_task'].message = "Processing Check Resources"
end

$evm.log("info", "Service Inspect --> #{service.inspect}")

#varibales
@oseInstallPath = "/root/oo-install-ose/" #oo-install-ose location
@oseTemplatePath = "/root/.openshift/" #oo-install template location
log(:info, "@oseInstallPath -->#{@oseInstallPath}")
@sshUser = $evm.root['dialog_sshUser']
log(:info, "@sshUser -->#{@sshUser}")
@appDomain = $evm.root['dialog_appDomain']
log(:info, "@appDomain -->#{@appDomain}")
@componentDomain = $evm.root['dialog_componentDomain']
log(:info, "@componentDomain -->#{@componentDomain}")
@registerComponents = $evm.root['dialog_registerComponents']
log(:info, "@registerComponents -->#{@registerComponents}")
if @registerComponents == 't'
  @registerComponents = 'Y'
else
  @registerComponents = 'N'
end

log(:info, "@registerComponents -->#{@registerComponents}")
@sub_rh_username = $evm.root['dialog_sub_rh_username']
log(:info, "@sub_rh_username -->#{@sub_rh_username}")
@sub_type = $evm.root['dialog_depot_type']
log(:info, "@sub_type -->#{@sub_type}")
@sub_rh_password = $evm.root.decrypt('dialog_sub_rh_password')
log(:info, "@sub_rh_password -->#{@sub_rh_password}")
@ose_user = $evm.root['dialog_ose_user']
log(:info, "@ose_user -->#{@ose_user}")
@ose_password = $evm.root.decrypt('dialog_ose_password')
log(:info, "@ose_password -->#{@ose_password}")
@mcollective_user = $evm.root['dialog_mcollective_user']
log(:info, "@mcollective_user -->#{@mcollective_user}")
@mcollective_password = $evm.root.decrypt('dialog_mcollective_password')
log(:info, "@mcollective_password -->#{@mcollective_password}")
@mongodb_broker_user = $evm.root['dialog_mongodb_broker_user']
log(:info, "@mongodb_broker_user -->#{@mongodb_broker_user}")
@mongodb_broker_password = $evm.root.decrypt('dialog_mongodb_broker_password')
log(:info, "@mongodb_broker_password -->#{@mongodb_broker_password}")

@ose_size = $evm.root['dialog_ose_size']
log(:info, "@ose_size -->#{@ose_size}")

@valid_gear_sizes = ""
if $evm.root['dialog_small_gears'] == "t"
  @valid_gear_sizes = @valid_gear_sizes + "small" + ","
end
if $evm.root['dialog_medium_gears'] == "t"
  @valid_gear_sizes = @valid_gear_sizes + "medium" + ","
end
if $evm.root['dialog_large_gears'] == "t"
  @valid_gear_sizes = @valid_gear_sizes + "large" + ","
end
log(:info, "@valid_gear_sizes -->#{@valid_gear_sizes}")

@default_gear_capabilities = ""
if $evm.root['dialog_default_small_gears'] == "t"
  @default_gear_capabilities = @default_gear_capabilities + "small" + ","
end
if $evm.root['dialog_default_medium_gears'] == "t"
  @default_gear_capabilities = @default_gear_capabilities + "medium" + ","
end
if $evm.root['dialog_default_large_gears'] == "t"
  @default_gear_capabilities = @default_gear_capabilities + "large" + ","
end
log(:info, "@default_gear_capabilities -->#{@default_gear_capabilities}")


#write out the inital yaml
preConfig
vmsWithPolicy = Array.new

#enumerate the vms for policy, skip those do not have osepolicy
service.vms.each do |vm|
  log(:info, "-----------------#{vm.name}-------------------")
  log(:info, "Checking vm #{vm.name}")
  vmtags = vm.tags.to_s
  #skip the vm if no osepolicy is found
  next unless vmtags.include? "osepolicy"
  vm.tags.each do |tag|
    log(:info, "TAG -->>> #{tag}")
    if tag.split("/")[0] == "osepolicy"
      assignTag(tag.split("/")[1], vm)
    end
  end
  vmsWithPolicy << vm
end

@num_of_vms = service.vms.size
@rtrHosts = Array.new

#Work with only those vms that have policy in the service  
vmsWithPolicy.each do |vm|
  log(:info, "Processing vm #{vm.name}")
  @rtrHosts << writeHosts(vm)
end

#put it all together  
@data.store("Deployment", {
    "Hosts" => @rtrHosts,
    "DNS" => @dataDNS
})

#write the subscription data  
subs = writeSubscription()
@data.store("Subscription", subs)

#write out the config

dirname = @oseTemplatePath
unless File.directory?(dirname)
  FileUtils.mkdir_p(dirname)
end

log(:info, "Writing - #{@oseTemplatePath}oo-install-cfg.yml")
file = File.open("#{@oseTemplatePath}oo-install-cfg.yml", 'w')
file.write(@data.to_yaml)
file.close

#Temporay read back in the config for debug in automate log. 
File.open("#{@oseTemplatePath}oo-install-cfg.yml", "r") do |infile|
  while (line = infile.gets)
    log(:info, "OSE Config File --> #{line}")
  end
end

#execute the install 
currentUser = $evm.root['user'].userid
fmt = "%Y%m%d_%H%M"
timeStamp = Time.now.strftime(fmt)
oseLogFIle = "/tmp/" + service.id.to_s + '_' + timeStamp + '_ose.log'

log(:info, "OSE Path - #{@oseInstallPath}")
log(:info, "OSE LogFile - #{oseLogFIle}")

#tag the service with the logfilename

if $evm.execute('category_exists?', "osetemp")
  log(:info, "Classification oseTEMP exists")
else
  log(:info, "Classification oseTEMP doesn't exist, creating category")
  $evm.execute('category_create', :name => "osetemp", :single_value => true, :description => "Temp OSE State")
end

tag_to_assign = service.id.to_s + '_' + timeStamp
$evm.execute('tag_create', "osetemp", :name => "#{tag_to_assign}", :description => "/tmp/#{tag_to_assign}_ose.log - OSE Log File name")
log(:info, "Assigning Service Tag -->> osetemp/#{tag_to_assign}")
service.tag_assign("osetemp/#{tag_to_assign}")

Dir.chdir(@oseInstallPath)
spawn_options = {
    :in => "/dev/null",
    :out => "#{oseLogFIle}",
    :err => "#{oseLogFIle}"
}

pid = Process.spawn('./oo-install-ose', '-w enterprise_deploy', spawn_options)
log(:info, "PID --> #{pid}")

Process.detach(pid)

log(:info, "PID Detached")
$evm.root['oseLogFile'] = "#{oseLogFIle}"
sleep(60)
f = File.open(oseLogFIle, "r")
f.each_line do |line|
  if line.include? "The validation attempt uncovered errors"
    message = "The validation attempt uncovered errors, Check Logs"
    log(:info, "#{message}")
    log(:info, "************ ose_installer EXIT ***************")
    $evm.root['oseStatus'] = "FAILED"
    $evm.root['oseMessage'] = "#{message}"
    log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
    exit MIQ_ABORT
  elsif line.include? "tail -f \/tmp\/openshift-deploy.log"
    meesage = "OSEInstaller is processing the install, await validation"
    log(:info, "#{message}")
    log(:info, "************ ose_installer RUNNING ***************")
    $evm.root['oseStatus'] = "RUNNING"
    $evm.root['oseMessage'] = "#{message}"
    log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
    exit MIQ_OK
  end
end

log(:info, "************ ose_installer UNKOWN ***************")
