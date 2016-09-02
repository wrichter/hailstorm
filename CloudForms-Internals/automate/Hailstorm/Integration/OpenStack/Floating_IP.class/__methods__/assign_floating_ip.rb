#
#            Assign floating IP to selected VM
#

begin
  $evm.log("info", "EVM Automate Method Started")

  require 'fog/openstack'
  # Dump all of root's attributes to the log
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}

  # def get_fog_object(ext_mgt_system, type="Compute", tenant="admin", auth_token=nil, encrypted=false, verify_peer=false)
  #   proto = "http"
  #   proto = "https" if encrypted
  #
  #   $evm.log("info", "auth url: #{proto}://#{ext_mgt_system.hostname}:#{ext_mgt_system.port}/v2.0/tokens")
  #   $evm.log("info", "inspect: #{ext_mgt_system.inspect}")
  #   $evm.log("info", "auth api_key: #{ext_mgt_system.authentication_password}")
  #   $evm.log("info", "auth username: #{ext_mgt_system.authentication_userid}")
  #
  #   begin
  #     return Object::const_get("Fog").const_get("#{type}").new({
  #       :provider => "OpenStack",
  #       :openstack_api_key => ext_mgt_system.authentication_password,
  #       :openstack_username => ext_mgt_system.authentication_userid,
  #       :openstack_auth_url => "#{proto}://#{ext_mgt_system.hostname}:#{ext_mgt_system.port}/v2.0/tokens",
  #       :openstack_auth_token => auth_token,
  #       :connection_options => { :ssl_verify_peer => verify_peer, :ssl_version => :TLSv1 },
  #       :openstack_tenant => tenant
  #       })
  #   rescue Excon::Errors::SocketError => sockerr
  #     raise unless sockerr.message.include?("end of file reached (EOFError)")
  #     $evm.log("error", "Looks like potentially an ssl connection due to error: #{sockerr}")
  #     return get_fog_object(ext_mgt_system, type, tenant, auth_token, true, verify_peer)
  #   rescue => loginerr
  #     $evm.log("error", "Error logging [#{ext_mgt_system}, #{type}, #{tenant}, #{auth_token rescue "NO TOKEN"}]")
  #     $evm.log("error", loginerr)
  #     $evm.log("error", "Returning nil")
  #   end
  #   return nil
  # end

  def list_external_networks(conn)
    array = []
    networks = conn.list_networks.body
      $evm.log("info", "Networks: #{networks.inspect}")
    for network in networks["networks"]
      array.push(network) if network["router:external"]
    end
    return array
  end

  $evm.log("info", "Begin Automate Method")
  floating_network = $evm.root['dialog_floating_network']
  $evm.log("info", "floating_network from dialog: #{floating_network}")

  vm = $evm.root['vm']

  $evm.log("info", "Found VM: #{vm.inspect}")
  $evm.log("info", "Nova UUID for vm is #{vm.ems_ref}")

  tenant_name = $evm.vmdb(:cloud_tenant).find_by_id(vm.cloud_tenant_id).name

  ext_mgt_system=vm.ext_management_system
  $evm.log("info", "#{ext_mgt_system.methods}")

  # get the MAC address directly from OSP
  # change the tenant name or make it dynamic
  credentials={
    :provider => "OpenStack",
    :openstack_api_key => ext_mgt_system.authentication_password,
    :openstack_username => ext_mgt_system.authentication_userid,
    :openstack_auth_url => "http://#{ext_mgt_system.hostname}:#{ext_mgt_system.port}/v3/auth/tokens",
    :openstack_tenant => tenant_name,
    :openstack_domain_id => ext_mgt_system['uid_ems']
  }

  $evm.log("info", "Connecting to tenant #{tenant_name} with credentials #{credentials}")

  conn = Fog::Compute.new(credentials)

  $evm.log("info", "Got Compute connection #{conn.class} #{conn.inspect}")

  netconn = Fog::Network.new(credentials)

  $evm.log("info", "Got Network connection #{netconn.class} #{netconn.inspect}")

  pool_name = floating_network
  pool_name = list_external_networks(netconn).first["name"] if pool_name.nil?

  $evm.log("info", "Allocating IP from #{pool_name}")

  address = conn.allocate_address(pool_name).body
  $evm.log("info", "Allocated #{address['floating_ip'].inspect}")

  res = conn.associate_address("#{vm.ems_ref}", "#{address['floating_ip']['ip']}")
  $evm.log("info", "Associate: Response: #{res.inspect}")
  vm.custom_set("NEUTRON_floating_ip", "#{address['floating_ip']['ip']}")
  vm.custom_set("NEUTRON_floating_id", "#{address['floating_ip']['id']}")
  vm.refresh

  $evm.log("info", "End Automate Method")

  #
  # Exit method
  #
  $evm.log("info", "EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
