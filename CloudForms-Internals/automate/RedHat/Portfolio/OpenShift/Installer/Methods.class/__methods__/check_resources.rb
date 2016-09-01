require 'rubygems'
require 'net/ssh'


#exit MIQ_ABORT

f = File.open("/tmp/sequence.log","a")
f.puts "Check_resources"
f.close

def log(level, message)
  @method = 'OSE_Installer'
  $evm.log(level, "#{@method}: #{message}")
end

def name_service(service)
  new_service_name = "#{service.name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
  log(:info, "Naming Service:<#{service.name}> to <#{new_service_name}>")
  service.name = "#{new_service_name}"
end

#test SSH connection to vm
def checkSSH(ipaddress)
  log(:info, "   Connecting to IPaddress - #{ipaddress}")
  begin
    Net::SSH.start(ipaddress, 'root') do |ssh|
      log(:info, "   Checking Ruby Version")
      $result = ssh.exec!("ruby -v")
      notFound = $result.scan(/command/)
      if notFound[0] == "command"
        log(:info, "   Ruby is NOT installed at VM - #{msg}")
        $evm.root['oseStatus'] = "FAILED"
        $evm.root['oseMessage'] = "Cannot connect to #{ipaddress} via ssh"
        log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
      else
        return $result
      end
    end
  rescue
    $evm.root['oseStatus'] = "FAILED"
    $evm.root['oseMessage'] = "Cannot connect to #{ipaddress} via ssh"
    log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
    return "FAILED"
  end
end

def clearLogs(ipaddress)
  Net::SSH.start( ipaddress, 'root' ) do | ssh |
    begin
      log(:info, "Clearing the logfiles")
      currentUser = $evm.root['user'].userid
      fmt = "%Y%m%d_%H%M"
      timeStamp = Time.now.strftime(fmt)
      oseLogFIle = "/tmp/" + currentUser + '_' + timeStamp + '_openshift-deploy.log'
      log(:info, "Executing -->> cp /tmp/openshift-deploy.log #{oseLogFIle};rm -rf /tmp/openshift-deploy.log")
      $result = ssh.exec!("cp /tmp/openshift-deploy.log #{oseLogFIle};rm -rf /tmp/openshift-deploy.log")
    end
  end
end

def validateRubyVersion(rubyVersion)
  log(:info, "      rubyVersion - #{rubyVersion}")
end

def getHostname(ipaddress)
  log(:info, "   Connecting to IPaddress - #{ipaddress}")
  begin
    Net::SSH.start(ipaddress, 'root') do |ssh|
      log(:info, "   Fetching Hostname")
      $result = ssh.exec!("hostname")
      return $result
    end
  rescue
    $evm.root['oseStatus'] = "FAILED"
    $evm.root['oseMessage'] = "Cannot connect to #{ipaddress} via ssh"
    log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
  end
end


10.times {log(:info, "************ START check_resources ***************")}
$evm.root['osePhase'] = "CheckResources"



#grab the service object
service_template_provision_task = $evm.root['service_template_provision_task']
if service_template_provision_task == nil
  service = $evm.root['service']
else
  service = service_template_provision_task.destination
  $evm.root['service_template_provision_task'].message = "Processing Check Resources"

end

$evm.log("info", "Service Inspect --> #{service.inspect}")
passedVMS = Array.new

#sleeping this process to give provisionig of vms a chance to complete, remove in favor od retry code.
# log(:info, "Seeping for 2 minuts - need to remove this!")
#sleep(180)

vmsWithPolicy = Array.new

#enumerate the vms for policy, skip those do not have osepolicy
service.vms.each do |vm|
  log(:info, "-----------------#{vm.name}-------------------")
  log(:info, "Checking vm #{vm.name}")
  vmtags = vm.tags.to_s
  #skip the vm if no osepolicy is found
  next unless vmtags.include? "osepolicy"  
  vmsWithPolicy << vm
end

log(:info, "Number of VMs with OSE Policy = #{vmsWithPolicy.size}")

#enumerate the vms
if vmsWithPolicy.size != 0 
vmsWithPolicy.each do |vm|
  log(:info, "Processing vm #{vm.name}")
  log(:info, "Power State #{vm.power_state}")
  if vm.power_state == "on"
    #we must have an IP address for the vm
    if vm.ipaddresses.size == 0
      message = "No IP Information - Possible tools are missing from Guest OS\nCheck that Cloudforms has the IP addess listed in Insight, refresh the guest releationship states or wait"
      $evm.root['oseStatus'] = "FAILED"
      $evm.root['oseMessage'] = "#{message}"
      log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
      raise MIQ_ERROR
    end
    #connect via ssh to the vm
    rubyVersion = checkSSH(vm.ipaddresses[0])
    if rubyVersion == "FAILED"
      log(:info, "Breaking loop due to failure")
      @skip = true
      break

    end
    validateRubyVersion(rubyVersion)

    #set the custom attribute to include the servers hostname for use later on bu oo-install-ose
    hostname = getHostname(vm.ipaddresses[0])
    vm.custom_set("hostname", hostname)
    log(:info, "Hostname --> #{hostname}")
    log(:info, "Ip Address --> #{vm.ipaddresses[0]}")

    #clear the logs
    clearLogs(vm.ipaddresses[0])
    passedVMS << hostname
    log(:info, "Added #{hostname} to passedVMS")
    @skip = false
  else
    log(:info, "************SKIPPING**********")
    @skip = true
  end
end
else
 $evm.root['oseStatus'] = "FAILED"
  $evm.root['oseMessage'] = "No Virtual Machines or Instances with Policy"
  log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
  exit MIQ_ABORT
end

if passedVMS.size > 0 && @skip == false
  $evm.root['oseStatus'] = "PASSED"
  $evm.root['oseMessage'] = "All Virtal Machines or Instances have Checked OK"
  log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
else
  if $evm.root['ae_state_retries'] != nil
    if $evm.root['ae_state_retries'].to_i < 10
      $evm.root['oseStatus'] = "SKIP"
      $evm.log("info","Comming back becuase VMs are not ready")
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = '60.seconds'
      $evm.log("info", "-------------------RETRY-----------------------\n")
      exit MIQ_OK
    else
      $evm.root['oseStatus'] = "FAILED"
      $evm.root['oseMessage'] = "We have waited more than 10minutes for the VMs to come up, but none have. Failing."
      log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
      exit MIQ_ABORT
    end
  end
  $evm.root['oseStatus'] = "FAILED"
  $evm.root['oseMessage'] = "No Powered ON Virtual Machines or Instances with Policy"
  log(:info, "#{$evm.root['osePhase']} : #{$evm.root['oseStatus']} : #{$evm.root['oseMessage']}")
  exit MIQ_ABORT
end

#if all went good we rename the service with date and time stamp
name_service(service)
log(:info, "************ END check_resources ***************")
exit MIQ_OK
