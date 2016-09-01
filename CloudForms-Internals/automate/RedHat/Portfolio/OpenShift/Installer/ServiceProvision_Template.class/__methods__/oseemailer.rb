$evm.log("info", "----------------OSE Emailer Started----------------")

status = $evm.root['oseStatus']
phase = $evm.root['osePhase']
message = $evm.root['oseMessage']

$evm.log("info", "oseStatus Status - #{status}")
$evm.log("info", "oseStatus Phase - #{phase}")
$evm.log("info", "oseStatus Message - #{message}")

def emailrequester(message, phase, status, appliance)
  user = $evm.root['user']
  requester = user.name
  requester_email = user.email || nil

  to = nil
  to ||= requester_email
  to ||= $evm.object['to_email_address']
  from = nil
  from ||= $evm.object['from_email_address']
  signature = nil
  signature ||= $evm.object['signature']
  subject = "OpenShift Enterprise Installer STATUS - #{status}"
  # Build email body
  body = "Hello, #{requester}"
  body += "<br>Your request for OpenShift Enterprise has a STATUS of #{status}<br><hr>"

  #grab the service object
service_template_provision_task = $evm.root['service_template_provision_task'] 
if service_template_provision_task == nil
	service = $evm.root['service']
else  
	service = service_template_provision_task.destination 
  $evm.root['service_template_provision_task'].message = "Processing Check Resources"  
end

$evm.log("info", "Service Inspect --> #{service.inspect}")
 
  case phase

    when "CheckResources"
      $evm.log("info", "***CheckResources***")

      case status

        when "PASSED"
          body += "<br>Progress (1)---2---3"
          body += "<br>"

          body += "<br>#{message}"
          body += "<br>The Virtual Machines will now be installed with OpenShift Enterprise."
          body += "<br>The next email to be sent will confirm that the installer has started."

        when "FAILED"
          body += "<br>Progress (1)---2---3"
          body += "<br>"

          body += "<br>#{message}"
          body += "<br>Please contact your support/administrator"

        when "SKIP"
          exit MIQ_OK


      end

    when "Installer"
      $evm.log("info", "***Installer***")
  @oseLogFile = service.tags(:osetemp)[0] + "_ose.log"
  $evm.log("info", "Logfile --> /tmp/#{@oseLogFile}")

      case status

        when "RUNNING"
          body += "<br>Progress 1---(2)---3"
          body += "<br>"

          body += "<br>#{message}"
          body += "<br>OpenShift Enterprise installer is now processing the virtual mahcines"
          body += "<br>The log file for oo-install-ose can be found in /tmp/#{@oseLogFile} on the CloudForms Appliance #{@appliance}"
          body += "<br>There will also be indvidual log files per virtual machine, locally at each vm called /tmp/openshift-deploy.log"


        when "FAILED"
          body += "<br>Progress 1---(2)---3"
          body += "<br>"

          body += "<br>#{message}"
          body += "<BR>The failure can be identified in /tmp/#{@oseLogFile} on the CloudForms Appliance #{@appliance}"
          body += "<BR>You may also be required to view the failure locally in the failed virtual machine log files found /tmp/openshift-deploy.log"
          body += "<br>Please contact your support/administrator"
      end

    when "PostValidation"
      $evm.log("info", "***PostValidation***")
      @oseLogFile = service.tags(:osetemp)[0] + "_ose.log"
  $evm.log("info", "Logfile --> /tmp/#{@oseLogFile}")

      case status

        when "SKIP"
          $evm.log("info", "***SKIPPING***")
          exit MIQ_OK

        when "PASSED"
          $evm.log("info", "***PASSED***")
          body += "<br>Progress 1---2---(3)"
          body += "<br>"
          body += "<br>#{message}"
          body += "<br>Congratulations you have a new OpenShift Enterprise deployment."
          body += "<br><br>Roles"
          body += "<br>-----"

          service.vms.each do |vm|
            $evm.log("info", "Looking at VM #{vm.name}")
            vmtags = vm.tags.to_s
            #skip the vm if no osepolicy is found
            next unless vmtags.include? "osepolicy"
            $evm.log("info", "Policy at VM #{vm.name} --> #{vmtags}")
            vm.tags.each do |tag|
              case tag.split("/")[1]
                when "broker"
                  $evm.log("info", "***Broker***")

                  body += "<br>Your OpenShift URL will be \<a href=\"http:\/\/#{vm.ipaddresses[0]}/console\" target=\"_blank\" rel=\"\" name=\"http:\/\/#{vm.ipaddresses[0]}/console\">http:\/\/#{vm.ipaddresses[0]}/console</a> <br>"
                  body += "First login details will be<br>"
                  body += "Username : demo<br>"
                  body += "Password : changeme<br>"
                  body += "<br>The broker IP address is #{vm.ipaddresses[0]}"

                when "node"
                  $evm.log("info", "***Node***")

                  body += "<br>Node IP address is #{vm.ipaddresses[0]}"

                when "msgserver"
                  $evm.log("info", "***msgSERVER***")

                  body += "<br>msgServer IP address is #{vm.ipaddresses[0]}"

                when "dbserver"
                  $evm.log("info", "***dbSERVER***")

                  body += "<br>dbServer IP address is #{vm.ipaddresses[0]}"

              end #tag end

            end #vms.tags end
          end #service.vms


        when "FAILED"
          $evm.log("info", "***FAILED***")
          body += "<br>Progress 1---2---(3)"
          body += "<br>"
          body += "<br>#{message}"
          body += "<br>Unforutanlty there has been a problem with the OpenShift Install"
          body += "<br>To debug this issue further you will need to request assitance with the OpenShift log files."
          body += "<br>The oo-install-ose logfile can be found in /tmp/#{@oseLogFile} on the CloudForms Appliance #{@appliance} "
          body += "<br>Further debugging can be done by logging into each role and looking at logs /tmp/ose-deploy.log"
          body += "<br>Roles"
          body += "<br>-----"
          service.vms.each do |vm|
            $evm.log("info", "Looking at VM #{vm.name}")
            vmtags = vm.tags.to_s

            #skip the vm if no osepolicy is found
            next unless vmtags.include? "osepolicy"
            $evm.log("info", "Policy at VM #{vm.name} --> #{vmtags}")

            vm.tags.each do |tag|
              case tag.split("/")[1]

                when "broker"
                  $evm.log("info", "***Broker***")

                  body += "<br>The broker IP address is #{vm.ipaddresses[0]}"

                when "node"
                  $evm.log("info", "***Node***")

                  body += "<br>Node IP address is #{vm.ipaddresses[0]}"

                when "msgserver"
                  $evm.log("info", "***msgSERVER***")

                  body += "<br>msgServer IP address is #{vm.ipaddresses[0]}"

                when "dbserver"
                  $evm.log("info", "***dbSERVER***")

                  body += "<br>dbServer IP address is #{vm.ipaddresses[0]}"

              end #case end
            end #vm.tags.each end

          end # service vms
      end #case status end
  end #proc end


  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.log("info", "Body - #{body}")
  result = $evm.execute(:send_email, to, from, subject, body)
  $evm.log("info", "Email Result - #{result}")
end

appliance = nil
@appliance ||= $evm.root['miq_server'].ipaddress

# Email Requester
emailrequester(message, phase, status, appliance)

exit MIQ_OK
$evm.log("info", "----------------OSE Emailer Ended----------------")
