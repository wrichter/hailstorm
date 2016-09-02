#
#            Automate Method
#

begin
  $evm.log("info", "EVM Automate Method Started")

	require 'rest-client'
	require 'json'
  require 'socket'

  def get_json(location)
  	response = RestClient::Request.new(
  		:method => :get,
  		:url => location,
  		:verify_ssl => false,
  		:user => @foreman_user,
  		:password => @foreman_password,
  		:headers => { :accept => :json,
  		:content_type => :json }
  	).execute

  	results = JSON.parse(response.to_str)
  end

  def put_json(location, json_data)
  	response = RestClient::Request.new(
  		:method => :put,
  		:url => location,
  		:verify_ssl => false,
  		:user => @foreman_user,
  		:password => @foreman_password,
  		:headers => { :accept => :json,
  		:content_type => :json},
  		:payload => json_data
  	).execute
  	results = JSON.parse(response.to_str)
  end

  # Dump all of root's attributes to the log
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}

  vm=$evm.root["vm"]
  if not vm.hostnames[0].nil?
		host=vm.hostnames[0]
		$evm.log("info", "Found FQDN #{host} for this VM")
	else
    hostname = Socket.gethostname
    domainname=hostname.split('.')[1,hostname.length].join('.')
		host="#{vm.name}.#{domainname}"
		$evm.log("info", "Found no FQDN for this VM, will try #{host} instead")
  end

	@foreman_host = $evm.object['foreman_host']
	@foreman_user = $evm.object['foreman_user']
	@foreman_password = $evm.object.decrypt('foreman_password')

	katello_url = "https://#{@foreman_host}/katello/api/v2/"

	systems = get_json(katello_url+"systems")
  uuid = {}
  hostExists = false
  systems['results'].each do |system|
  	if system['name'].include? host
  		$evm.log("info","Host ID #{system['id']}")
  		$evm.log("info","Host UUID #{system['uuid']}")
  		uuid = system['uuid'].to_s
  		hostExists = true
      break
  	end
  end

  if !hostExists
    $evm.log("info", "Host #{host} not found on Satellite")
    exit MIQ_OK
  end

  uri=katello_url+"systems/"+uuid+"/"

  @headers = {
  	:content_type => 'application/json',
  	:accept => 'application/json;version=2',
  	:authorization => "Basic #{Base64.strict_encode64("#{@foreman_user}:#{@foreman_password}")}"
  }

  request = RestClient::Request.new(
  	method: :delete,
  	url: uri,
  	headers: @headers,
  	verify_ssl: OpenSSL::SSL::VERIFY_NONE
  )

  $evm.log("info","Calling DELETE URL #{uri}")
  result=request.execute
  $evm.log("info", "Result: #{result}")

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

exit()
