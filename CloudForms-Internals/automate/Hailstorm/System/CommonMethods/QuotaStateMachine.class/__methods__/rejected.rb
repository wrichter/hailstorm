#
# Description: <Method description here>
#

$evm.log('info', "Request denied because of #{$evm.root["miq_request"].message}")
$evm.root["miq_request"].deny("admin", "Quota Exceeded")

# Build email to requester with reason
def emailrequester(miq_request, appliance, msg)
  $evm.log("info", "Requester email logic starting")

  # Get requester object
  requester = miq_request.requester

  # Get requester email else set to nil
  requester_email = requester.email || nil

  # Get Owner Email else set to nil
  owner_email = miq_request.options[:owner_email] || nil
  $evm.log("info", "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

  # if to is nil then use requester_email or owner_email
  to = nil
  to ||= requester_email || owner_email

  # If to is still nil use to_email_address from model
  to ||= $evm.object['to_email_address']

  # Get from_email_address from model unless specified below
  from = nil
  from ||= $evm.object['from_email_address']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']
  
  # Set email subject
  subject = "Request ID #{miq_request.id} - Virtual Machine request was denied due to quota limitations"

  # Build email body
  body = "Hello, "
  body += "<br>#{msg}."
  body += "<br><br>For more information you can go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute(:send_email, to, from, subject, body)
end

# Get miq_request from root
miq_request = $evm.root['miq_request']
msg = miq_request.message
raise "miq_request missing" if miq_request.nil?
$evm.log("info", "Detected Request:<#{miq_request.id}> with Approval State:<#{miq_request.approval_state}>")

# Override the default appliance IP Address below
appliance = nil
appliance ||= $evm.root['miq_server'].hostname

# Email Requester
emailrequester(miq_request, appliance, msg)
