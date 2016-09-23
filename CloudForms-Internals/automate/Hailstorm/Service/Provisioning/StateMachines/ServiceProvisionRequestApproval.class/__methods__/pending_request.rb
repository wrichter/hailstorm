# service_request_pending.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is executed when the service request is NOT auto-approved
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # get the request object from root
  @miq_request = $evm.root['miq_request']
  log(:info, "Request id: #{@miq_request.id} options: #{@miq_request.options.inspect}")

  # lookup the service_template object
  service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
  log(:info, "service_template id: #{service_template.id} service_type: #{service_template.service_type} description: #{service_template.description} services: #{service_template.service_resources.count}")

  # Get objects
  msg = $evm.object['reason']
  @miq_request.set_option(:pending_reason, msg)
  log(:info, "Reason: #{msg}")

  # Raise automation event: request_pending
  @miq_request.pending
  
  # send mail to approver
  to="approver@cd.coe.muc.redhat.com"
  user=$evm.root["user"]
  user.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
  from=user["email"]
  subject="A VM Request needs approval"
  body="A VM request needs approval."
  owner_name = user["name"]
  body+="</br>Requester: #{owner_name}"
  body+="</br>Regards,"
  body+="</br>Virtualization Team"
  
  $evm.execute(:send_email, to, from, subject, body)

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
