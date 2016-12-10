#------------------------------------------------------------------------------
#
# CFME Automate Method: add_disk
#
# Authors: Kevin Morey, Peter McGowan (Red Hat)
#
# Notes: This method adds a disk to a RHEV VM
#
#------------------------------------------------------------------------------

require 'rest_client'
require 'nokogiri'

@debug = false

begin
  
  
  
  #------------------------------------------------------------------------------
  def call_rhev(servername, username, password, action, ref=nil, body_type=:xml, body=nil)
    #
    # If ref is a url then use that one instead
    #
    unless ref.nil?
      url = ref if ref.include?('http')
    end
    url ||= "https://#{servername}#{ref}"
    
    params = {
      :method => action,
      :url => url,
      :user => username,
      :password => password,
      :headers => { :content_type=>body_type, :accept=>:xml },
      :verify_ssl => false
    }
    params[:payload] = body if body
    if @debug
      $evm.log(:info, "Calling RHEVM at: #{url}")
      $evm.log(:info, "Action: #{action}")
      $evm.log(:info, "Payload: #{params[:payload]}")
    end
    rest_response = RestClient::Request.new(params).execute
    #
    # RestClient raises an exception for us on any non-200 error
    #
    return rest_response
  end
  #------------------------------------------------------------------------------

  #------------------------------------------------------------------------------
  # Start of main code
  #
  case $evm.root['vmdb_object_type']
  when 'miq_provision'                  # called from a VM provision workflow
    if $evm.root['miq_provision'].get_option(:dialog_add_disk_check) == false
      $evm.root['ae_result'] = 'ok'
      exit MIQ_OK
    end
    vm = $evm.root['miq_provision'].destination
    disk_size_bytes = $evm.root['miq_provision'].get_option(:dialog_disk_size_gb).to_i * 1024**3
    $evm.log(:info, "Add Disk Provision: #{disk_size_bytes}")
  when 'vm'
    vm = $evm.root['vm']                # called from a button
    $evm.log(:info, "Add Disk Button pushed")
    if $evm.root['dialog_btn_add_disk_check'] == false
      $evm.log(:info, "Add Disk Check is false")
      $evm.root['ae_result'] = 'ok'
      exit MIQ_OK
    end
    disk_size_bytes = $evm.root['dialog_btn_disk_size_gb'].to_i * 1024**3
    $evm.log(:info, "Add Disk Button: #{disk_size_bytes}")
  end
  
  storage_id = vm.storage_id rescue nil
  $evm.log(:info, "VM Storage ID: #{storage_id}") if @debug
  #
  # Extract the RHEV-specific Storage Domain ID
  #
  unless storage_id.nil? || storage_id.blank?
    storage = $evm.vmdb('storage').find_by_id(storage_id)
    storage_domain_id = storage.ems_ref.match(/.*\/(\w.*)$/)[1]
    if @debug
      $evm.log(:info, "Found Storage: #{storage.name}")
      $evm.log(:info, "ID: #{storage.id}")
      $evm.log(:info, "ems_ref: #{storage.ems_ref}") 
      $evm.log(:info, "storage_domain_id: #{storage_domain_id}")
    end
  end

  unless storage_domain_id.nil?
    #
    # Extract the IP address and credentials for the RHEV Provider
    #
    servername = vm.ext_management_system.ipaddress || vm.ext_management_system.hostname
    username = vm.ext_management_system.authentication_userid
    password = vm.ext_management_system.authentication_password

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.disk {
        xml.storage_domains {
          xml.storage_domain :id => storage_domain_id
        }
        xml.size disk_size_bytes
        xml.type 'system'
        xml.interface 'virtio'
        xml.format 'cow'
        xml.bootable 'false'
      }
    end

    body = builder.to_xml
    $evm.log(:info, "Adding #{disk_size_bytes / 1024**3} GByte disk to VM: #{vm.name}")
    response = call_rhev(servername, username, password, :post, "#{vm.ems_ref}/disks", :xml, body)
    #
    # Parse the response body XML
    #
    doc = Nokogiri::XML.parse(response.body)
    #
    # Pull out some re-usable href's from the initial response
    #
    disk_href = doc.at_xpath("/disk")['href']
    creation_status_href = doc.at_xpath("/disk/link[@rel='creation_status']")['href']
    activate_href = doc.at_xpath("/disk/actions/link[@rel='activate']")['href']
    if @debug
      $evm.log(:info, "disk_href: #{disk_href}")
      $evm.log(:info, "creation_status_href: #{creation_status_href}")
      $evm.log(:info, "activate_href: #{activate_href}")
    end
    #
    # Validate the creation_status (wait for up to a minute)
    #
    creation_status = doc.at_xpath("/disk/creation_status/state").text
    counter = 13
    $evm.log(:info, "Creation Status: #{creation_status}")
    while creation_status != "complete"
      counter -= 1
      if counter == 0
        raise "Timeout waiting for new disk creation_status to reach \"complete\": \
               Creation Status = #{creation_status}"
      else
        sleep 5
        response = call_rhev(servername, username, password, :get, creation_status_href, :xml, nil)
        doc = Nokogiri::XML.parse(response.body)
        creation_status = doc.at_xpath("/creation/status/state").text
        $evm.log(:info, "Creation Status: #{creation_status}")
      end
    end
    #
    # Disk has been created successfully,
    # now check its activation status and if necessary activate it
    #
    response = call_rhev(servername, username, password, :get, disk_href, :xml, nil)
    doc = Nokogiri::XML.parse(response.body)
    if doc.at_xpath("/disk/active").text != "true"
      $evm.log(:info, "Activating disk")
      body = "<action/>"
      response = call_rhev(servername, username, password, :post, activate_href, :xml, body)
    else
      $evm.log(:info, "New disk already active")
    end
  end
  #
  # Exit method
  #
  $evm.root['ae_result'] = 'ok'
  exit MIQ_OK
  #
  # Set Ruby rescue behavior
  #
rescue RestClient::Exception => err
  $evm.log(:error, "The REST request failed with code: #{err.response.code}") unless err.response.nil?
  $evm.log(:error, "The response body was:\n#{err.response.body.inspect}") unless err.response.nil?
  $evm.root['ae_reason'] = "The REST request failed with code: #{err.response.code}" unless err.response.nil?
  $evm.root['ae_result'] = 'error'
  exit MIQ_STOP
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_reason'] = "Unspecified error, see automation.log for backtrace"
  $evm.root['ae_result'] = 'error'
  exit MIQ_STOP
end
