#
#            Automate Method
#

begin
  $evm.log("info", "EVM Automate Method Started")

  # Dump all of root's attributes to the log
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}

  prov=$evm.root["miq_provision"]
  vm=prov.vm
  
  owner=$evm.root["user"]

  open("/tmp/#{vm.name}", "a+") do |f|
    time = Time.new
    f.puts "Current Time : " + time.inspect
    f.puts "VM was created based on a request from #{owner.name}\n"
    f.puts "VM name: #{vm.name}\n"
    f.puts "IP Addresses: #{vm.ipaddresses.inspect}\n"
    f.puts "Floating IPs: #{vm.floating_ip.inspect}\n"
    f.puts "Provider: #{vm.vendor}\n"
  end

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
