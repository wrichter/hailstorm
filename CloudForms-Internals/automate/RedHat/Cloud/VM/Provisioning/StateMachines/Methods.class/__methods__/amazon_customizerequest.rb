#
# Description: This method is used to Customize the Amazon Provisioning Request
#

# process_customization - mapping instance_types, key pairs, security groups and cloud-init templates
def process_customization(mapping, prov, template, product, provider )
  log(:info, "Processing Amazon customizations...", true)
  case mapping
  when 0
    # No mapping
  when 1
    ws_values = prov.options.fetch(:ws_values, {})

    if prov.get_option(:instance_type).nil? && ws_values.has_key?(:instance_type)
      provider.flavors.each do |flavor|
        if flavor.name.downcase == ws_values[:instance_type].downcase
          prov.set_option(:instance_type, [flavor.id, "#{flavor.name}':'#{flavor.description}"])
          log(:info, "Provisioning object updated {:instance_type => #{prov.get_option(:instance_type).inspect}}")
        end
      end
    end

    if prov.get_option(:guest_access_key_pair).nil? && ws_values.has_key?(:guest_access_key_pair)
      provider.key_pairs.each do |keypair|
        if keypair.name == ws_values[:guest_access_key_pair]
          prov.set_option(:guest_access_key_pair, [keypair.id,keypair.name])
          log(:info, "Provisioning object updated {:guest_access_key_pair => #{prov.get_option(:guest_access_key_pair).inspect}}")
        end
      end
    end

    if prov.get_option(:security_groups).blank? && ws_values.has_key?(:security_groups)
      provider.security_groups.each do |securitygroup|
        if securitygroup.name == ws_values[:security_groups]
          prov.set_option(:security_groups, [securitygroup.name])
          log(:info, "Provisioning object updated {:security_groups => #{prov.get_option(:security_groups).inspect}}")
        end
      end
    end

    if prov.get_option(:customization_template_id).nil?
      customization_template_search_by_function       = "#{prov.type}_#{prov.get_tags[:function]}" rescue nil
      customization_template_search_by_template_name  = template.name
      customization_template_search_by_ws_values      = ws_values[:customization_template] rescue nil
      log(:info, "prov.eligible_customization_templates: #{prov.eligible_customization_templates.inspect}")
      customization_template = nil

      unless customization_template_search_by_function.nil?
        # Search for customization templates enabled for Cloud-Init that equal MiqProvisionAmazon_prov.get_tags[:function]
        if customization_template.blank?
          log(:info, "Searching for customization templates (Cloud-Init) enabled that are named: #{customization_template_search_by_function}")
          customization_template = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(customization_template_search_by_function)==0 }
        end
      end
      unless customization_template_search_by_template_name.nil?
        # Search for customization templates enabled for Cloud-Init that match the template/image name
        if customization_template.blank?
          log(:info, "Searching for customization templates (Cloud-Init) enabled that are named: #{customization_template_search_by_template_name}")
          customization_template = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(customization_template_search_by_template_name)==0 }
        end
      end
      unless customization_template_search_by_ws_values.nil?
        # Search for customization templates enabled for Cloud-Init that match ws_values[:customization_template]
        if customization_template.blank?
          log(:info, "Searching for customization templates (Cloud-Init) enabled that are named: #{customization_template_search_by_ws_values}")
          customization_template = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(customization_template_search_by_ws_values)==0 }
        end
      end
      if customization_template.blank?
        log(:warn, "Failed to find matching Customization Template", true)
      else
        log(:info, "Found Customization Template ID: #{customization_template.id} Name: #{customization_template.name} Description: #{customization_template.description}")
        prov.set_customization_template(customization_template) rescue nil
        log(:info, "Provisioning object updated {:customization_template_id => #{prov.get_option(:customization_template_id).inspect}}")
        log(:info, "Provisioning object updated {:customization_template_script => #{prov.get_option(:customization_template_script).inspect}}")
      end
    else
      log(:info, "Customization Template selected from dialog ID: #{prov.get_option(:customization_template_id).inspect}} Script: #{prov.get_option(:customization_template_script).inspect}")
    end
  end # case mapping
  log(:info, "Processing Amazon customizations...Complete", true)
end

def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

# Get provisioning object
prov = $evm.root["miq_provision"]

log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

template = prov.vm_template
provider = template.ext_management_system
product  = template.operating_system['product_name'].downcase rescue nil
log(:info, "Template: #{template.name} Provider: #{provider.name} Vendor: #{template.vendor} Product: #{product}")

mapping = 0
process_customization(mapping, prov, template, product, provider)
