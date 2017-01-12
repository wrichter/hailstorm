#
#            Automate Method
#

begin
  $evm.log("info", "EVM Automate Method Started")

	require 'rest-client'
	require 'json'
  require 'socket'

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
	@foreman_password = $evm.object['foreman_password']

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

	url = "https://#{@foreman_host}/api/v2/"
	katello_url = "https://#{@foreman_host}/katello/api/v2/"
  satellite_api_url = "https://#{@foreman_host}/api/"

  systems = get_json(katello_url+"systems")
  uuid = {}
  host_id = {}
  hostExists = false
  systems['results'].each do |system|
		$evm.log("info","Current Name: #{system["name"]} comparing to #{host}")
  	if system['name'].include? host
  		$evm.log("info","Host ID #{system['host_id']}")
  		$evm.log("info","Host UUID #{system['uuid']}")
  		uuid = system['uuid'].to_s
      host_id = system['host_id'].to_s
  		hostExists = true
      break
  	end
  end

  if !hostExists
    $evm.log("info", "Host #{host} not found on Satellite")
    exit MIQ_OK
  end

  #erratas = get_json(katello_url+"systems/"+uuid+"/errata")
  erratas = get_json(satellite_api_url+"hosts/" + host_id + "/errata")
  errata_list = Array.new
  erratas['results'].each do |errata|
  	errata_id = errata['errata_id']
  	$evm.log("info", "Errata id[#{errata["errata_id"]}] title[#{errata["title"]} severity[#{errata["severity"]} found")
  	errata_list.push errata_id
  end

  if erratas['results'].nil? || erratas['results'].empty?
  	$evm.log("info","No erratas found for host #{host}")
  end

  #errata_result = put_json(katello_url+"systems/"+uuid+"/errata/apply", JSON.generate({"errata_ids"=>errata_list}))
  errata_result = put_json(satellite_api_url+"hosts/"+host_id+ "/errata/apply", JSON.generate({"errata_ids"=>errata_list}))

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
