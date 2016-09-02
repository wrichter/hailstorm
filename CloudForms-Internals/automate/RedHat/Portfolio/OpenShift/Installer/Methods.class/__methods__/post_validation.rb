require 'rubygems'
require 'net/ssh'

10.times {$evm.log("info", "*********post_validation state**********")}
$evm.root['osePhase'] = "PostValidation"

f = File.open("/tmp/sequence.log","a")
f.puts "Post-Validation"
f.close

#exit MIQ_ABORT


def log(level, message)
  @method = 'OSE_PostValidation'
  $evm.log(level, "#{@method}: #{message}")
end


def rebootServer(ipaddress)
  $evm.log("info", "Rebooting Server IP:- #{ipaddress}")
  Net::SSH.start(ipaddress, 'root') do |ssh|
    begin
      $result = ssh.exec!("reboot")
    end
  end
end

def processTag(tag, vm, type)
  category = "osestate"
  tag_to_assign = category + "/" + type + tag
  tag_to_unassign = category + "/" + "progress_" + tag
  log(:info, "Assigning Tag --> #{tag_to_assign}")
  log(:info, "UN-Assigning Tag --> #{tag_to_unassign}")
  vm.tag_assign(tag_to_assign)
  vm.tag_unassign(tag_to_unassign)
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

rebootServers = $evm.root['dialog_rebootServers']
$evm.log("info", "Reboot Servers - #{rebootServers}")

oseLogFile = service.tags(:osetemp)[0] + "_ose.log"
#Testing
#oseLogFile = "19000000000067_20140626_1529_ose.log"


failures = Array.new
status = 0

f = File.open("/tmp/#{oseLogFile}", "r")
f.each_line do |line|
  if line.include? "OpenShift: Completed configuring OpenShift."
    log(:info, "COMPLETED - #{line}")
    status = 2
  elsif line.include? "Please examine /tmp/openshift-deploy.log on"
    log(:info, "Failure Found - #{line}")
    failures << line
    status = 1
  end
end

case status
  when 0
    log(:info, "Not Finished, Retrying")
    #retry logic
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = '10.seconds'
	$evm.root['oseStatus'] = "SKIP"
    $evm.log("info", "------------------- RETRY for INSTALL -----------------------\n")
    service.tag_assign("osestate/pending_ose")
    exit MIQ_OK
  when 1
    log(:info, "Number of Failures - #{failures.size}")
    service.vms.each do |vm|
      vm.tags.each do |tag|
        log(:info, "TAG -->>> #{tag}")
        if tag.split("/")[0] == "osepolicy"
          processTag(tag.split("/")[1], vm, "failed_")
        end
      end
    end
    service.tag_assign("osestate/failed_ose")
    service.tag_unassign("osestate/pending_ose")
    
    $evm.root['oseStatus'] = "FAILED"
    $evm.root['oseMessage'] = failures
  $evm.log("info","Failures --> #{failures}")
    exit MIQ_ERROR

  when 2
    log(:info, "***COMPLETED***")
    service.vms.each do |vm|
      if rebootServers == 't'
       $evm.log("info", "Rebooting #{vm.ipaddresses[0]}")
        rebootServer(vm.ipaddresses[0])
      end
      vm.tags.each do |tag|
        log(:info, "TAG -->>> #{tag}")
        if tag.split("/")[0] == "osepolicy"
          processTag(tag.split("/")[1], vm, "completed_")
        end
      end
    end
    service.tag_assign("osestate/completed_ose")
    service.tag_unassign("osestate/pending_ose")

    $evm.root['osePhase'] = "PostValidation"
    $evm.root['oseStatus'] = "PASSED"
    $evm.root['oseMessage'] = "The Post checks have been completed sucessfully"
    exit MIQ_OK
end


exit MIQ_OK
