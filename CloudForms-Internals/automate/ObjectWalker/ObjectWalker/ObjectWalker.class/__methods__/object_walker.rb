#
# object_walker
#
# Can be called from anywhere in the CloudForms / ManageIQ automation namespace, and will walk the automation object structure starting from $evm.root
# and dump (to automation.log) its attributes, any objects found, their attributes, virtual columns, and associations, and so on.
#
# Author:   Peter McGowan (pemcg@redhat.com)
#           Copyright 2016 Peter McGowan, Red Hat
#
require 'active_support/core_ext/string'
require 'securerandom'
require 'json'

VERSION = "1.8"
#
#-------------------------------------------------------------------------------------------------------------
# Method:       walk_automation_objects
# Purpose:      Recursively walk and record the automation object hierarchy from $evm.root downwards
# Arguments:    service_object 
# Returns:      A completed Struct::ServiceObject data structure
#-------------------------------------------------------------------------------------------------------------

def walk_automation_objects(service_object)
  automation_object = Struct::ServiceObject.new(service_object.to_s, "", Array.new)
  if service_object.to_s == $evm.root.to_s
    automation_object.position = 'root'
  elsif service_object.to_s == $evm.parent.to_s
    automation_object.position = 'parent'
  elsif service_object.to_s == $evm.object.to_s
    automation_object.position = 'object'
  end
  kids = service_object.children
  unless kids.nil? || (kids.kind_of?(Array) and kids.length.zero?)
    Array.wrap(kids).each do |child|
      automation_object.children << walk_automation_objects(child)
    end
  end
  return automation_object
end

# End of walk_object_hierarchy
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       print_automation_objects
# Purpose:      recursively walk & dump the service object hierarchy discovered by walk_automation_objects
# Arguments:    hierarchy: the service object hierarchy
#               indent_level: the indentation string
# Returns:      Nothing
#-------------------------------------------------------------------------------------------------------------

def print_automation_objects(indent_level, hierarchy)
  case hierarchy.position
  when 'root'
    print_line(indent_level, "#{hierarchy.obj_name}  ($evm.root)")
  when 'parent'
    print_line(indent_level, "#{hierarchy.obj_name}  ($evm.parent)")
  when 'object'
    print_line(indent_level, "#{hierarchy.obj_name}  ($evm.object)")
  else
    print_line(indent_level, "#{hierarchy.obj_name}")
  end
  indent_level += 1
  hierarchy.children.each do |child|
    print_automation_objects(indent_level, child)
  end
end

# End of walk_object_hierarchy
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       print_line
# Purpose:      Wraps $evm.log(:info....)
# Arguments:    indent_level: the indentation string
#               string: the actual message to print
# Returns:      Nothing
#-------------------------------------------------------------------------------------------------------------

def print_line(indent_level, string)
  $evm.log("info", "#{@method}:[#{indent_level.to_s}] #{string}")
end

# End of print_linedumps

#-------------------------------------------------------------------------------------------------------------
# Method:       type
# Purpose:      Returns a string containing the type of the object passed as an argument
# Arguments:    object: object to be type tested
# Returns:      string
#-------------------------------------------------------------------------------------------------------------

def type(object)
  if object.is_a?(DRb::DRbObject)
    string = "(type: #{object.class}, URI: #{object.__drburi()})"
  else
    string = "(type: #{object.class})"
  end
  return string
end

# End of type
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       ping_attr
# Purpose:      Some attributes returned by object.attributes are actually hash keys rather than
#               attributes. We need to know which is which so that we can format our pretty output
#               correctly, so here we try to access the attribute as a method, and if that fails
#               we try to access it as a hash key
# Arguments:    this_object: object to be tested
#               attribute: the attribute to be tested
# Returns:      hash {:format_string => ".attribute" | "['attribute']", :value => value} 
#-------------------------------------------------------------------------------------------------------------

def ping_attr(this_object, attribute)
  value = "<unreadable_value>"
  format_string = ".<unknown_attribute>"
  begin
    #
    # See if it's an attribute that we access using '.attribute'
    #
    value = this_object.send(attribute)
    format_string = ".#{attribute}"
  rescue NoMethodError
    #
    # Seems not, let's try to access as if it's a hash value
    #
    value = this_object[attribute]
    format_string = "['#{attribute}']"
  end
  return {:format_string => format_string, :value => value}
end

# End of ping_attr
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       str_or_sym
# Purpose:      format a string containing the argument correctly depending on whether the value
#               is a symbol or string
# Arguments:    value: the thing to be string-formatted
# Returns:      string containing either ":value" or "'value'"
#-------------------------------------------------------------------------------------------------------------

def str_or_sym(value)
  value_as_string = ""
  if value.is_a?(Symbol)
    value_as_string = ":#{value}"
  else
    value_as_string = "\'#{value}\'"
  end
  return value_as_string
end

# End of str_or_sym
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       print_attributes
# Purpose:      Print the attributes of an object
# Arguments:    object_string     : friendly text string name for the object
#               this_object       : the Ruby object whose virtual_column_names are to be dumped
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def print_attributes(object_string, this_object)
  begin
    #
    # Print the attributes of this object
    #
    if this_object.respond_to?(:attributes)
      print_line(@recursion_level, "Debug: this_object.inspected = #{this_object.inspect}") if @debug
      if this_object.attributes.respond_to?(:keys)
        if this_object.attributes.keys.length > 0
          print_line(@recursion_level, "--- attributes follow ---")
          this_object.attributes.keys.sort.each do |attribute_name|
            attribute_value = this_object.attributes[attribute_name]
            if attribute_name != "options"
              if attribute_value.is_a?(DRb::DRbObject)
                if attribute_value.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
                  print_line(@recursion_level,
                            "#{object_string}[\'#{attribute_name}\'] => #{attribute_value}   #{type(attribute_value)}")
                  walk_object("#{object_string}[\'#{attribute_name}\']", attribute_value)
                else
                  print_line(@recursion_level,
                            "Debug: not dumping, attribute_value.method_missing(:class) = " \
                            "#{attribute_value.method_missing(:class)}") if @debug
                end
              else
                begin
                  attr_info = ping_attr(this_object, attribute_name)
                  if attr_info[:value].nil?
                    print_line(@recursion_level,
                              "#{object_string}#{attr_info[:format_string]} = nil") if @print_nil_values
                  else
                    print_line(@recursion_level,
                              "#{object_string}#{attr_info[:format_string]} = #{attr_info[:value]}   #{type(attr_info[:value])}")
                  end
                rescue ArgumentError
                  if attribute_value.nil?
                    print_line(@recursion_level,
                              "#{object_string}.#{attribute_name} = nil") if @print_nil_values
                  else
                    print_line(@recursion_level,
                              "#{object_string}.#{attribute_name} = #{attribute_value}   #{type(attribute_value)}")
                  end
                end
              end
            else
              #
              # Option key names can be mixed symbols and strings which confuses .sort
              # Create an option_map hash that maps option_name.to_s => option_name
              #
              option_map = {}
              options = attribute_value.keys
              options.each do |option_name|
                option_map[option_name.to_s] = option_name
              end
              option_map.keys.sort.each do |option|
                if attribute_value[option_map[option]].nil?
                  print_line(@recursion_level,
                            "#{object_string}.options[#{str_or_sym(option_map[option])}] = nil") if @print_nil_values
                else
                  print_line(@recursion_level,
                            "#{object_string}.options[#{str_or_sym(option_map[option])}] = " \
                            "#{attribute_value[option_map[option]]}   #{type(attribute_value[option_map[option]])}")
                end
              end
            end
          end
          print_line(@recursion_level, "--- end of attributes ---")
        else  
          print_line(@recursion_level, "--- no attributes ---")
        end
      else
        print_line(@recursion_level, "*** attributes is not a hash ***")
      end
    else
      print_line(@recursion_level, "--- no attributes ---")
    end
  rescue => err
    $evm.log("error", "#{@method} (print_attributes) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end

# End of print_attributes
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       print_virtual_columns
# Purpose:      Prints the virtual_columns_names of the object passed to it
# Arguments:    object_string     : friendly text string name for the object
#               this_object       : the Ruby object whose virtual_column_names are to be dumped
#               this_object_class : the class of the object whose associations are to be dumped
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def print_virtual_columns(object_string, this_object, this_object_class)
  begin
    #
    # Only dump the virtual columns of an MiqAeMethodService::* class
    #
    if this_object.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
      #
      # Print the virtual columns of this object 
      #
      virtual_column_names = []
      if this_object.respond_to?(:virtual_column_names)
        virtual_column_names = Array.wrap(this_object.virtual_column_names)
        if virtual_column_names.length.zero?
          print_line(@recursion_level, "--- no virtual columns ---")
        else
          print_line(@recursion_level, "--- virtual columns follow ---")
          virtual_column_names.sort.each do |virtual_column_name|
            begin
              virtual_column_value = this_object.send(virtual_column_name)
              if virtual_column_value.nil?
                print_line(@recursion_level,
                          "#{object_string}.#{virtual_column_name} = nil") if @print_nil_values
              else
                print_line(@recursion_level,
                          "#{object_string}.#{virtual_column_name} = " \
                          "#{virtual_column_value}   #{type(virtual_column_value)}")
              end
            rescue NoMethodError
              print_line(@recursion_level,
                        "*** #{this_object_class} virtual column: \'#{virtual_column_name}\' " \
                        "gives a NoMethodError when accessed (product bug?) ***")
            end
          end
          print_line(@recursion_level, "--- end of virtual columns ---")
        end
      else
        print_line(@recursion_level, "--- no virtual columns ---")
      end
    end
  rescue => err
    $evm.log("error", "#{@method} (print_virtual_columns) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end

# End of print_virtual_columns
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       is_plural?
# Purpose:      Test whether a string is plural (as opposed to singular)
# Arguments:    astring: text string to be tested
# Returns:      Boolean
#-------------------------------------------------------------------------------------------------------------

def is_plural?(astring)
  astring.singularize != astring
end

# End of is_plural?
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       walk_association
# Purpose:      Walks the association into the object passed to it
# Arguments:    object_string       : friendly text string name for the object
#               association         : friendly text string name for the association
#               associated_objects  : the list of objects in the association
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def walk_association(object_string, association, associated_objects)
  begin
    #
    # Assemble some fake code to make it look like we're iterating though associations (plural)
    #
    number_of_associated_objects = associated_objects.length
    if is_plural?(association)
      assignment_string = "#{object_string}.#{association}.each do |#{association.singularize}|"
    else
      assignment_string = "#{association} = #{object_string}.#{association}"
    end
    print_line(@recursion_level, "#{assignment_string}")
    associated_objects.each do |associated_object|
      associated_object_class = "#{associated_object.method_missing(:class)}".demodulize
      associated_object_id = associated_object.id rescue associated_object.object_id
      print_line(@recursion_level, "(object type: #{associated_object_class}, object ID: #{associated_object_id})")
      if is_plural?(association)
        walk_object("#{association.singularize}", associated_object)
        if number_of_associated_objects > 1
          print_line(@recursion_level,
                    "--- next #{association.singularize} ---")
          number_of_associated_objects -= 1
        else
          print_line(@recursion_level,
                    "--- end of #{object_string}.#{association}.each do |#{association.singularize}| ---")
        end
      else
        walk_object("#{association}", associated_object)
      end
    end
  rescue => err
    $evm.log("error", "#{@method} (walk_association) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end

# End of walk_association
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       print_associations
# Purpose:      Prints the associations (if any) of the object passed to it
# Arguments:    object_string     : friendly text string name for the object
#               this_object       : the Ruby object whose associations are to be dumped
#               this_object_class : the class of the object whose associations are to be dumped
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def print_associations(object_string, this_object, this_object_class)
  begin
    #
    # Only dump the associations of an MiqAeMethodService::* class
    #
    if this_object.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
      #
      # Print the associations of this object according to the
      # @walk_associations_whitelist & @walk_associations_blacklist hashes
      #
      associations = []
      associated_objects = []
      duplicates = []
      if this_object.respond_to?(:associations)
        associations = Array.wrap(this_object.associations)
        if associations.length.zero?
          print_line(@recursion_level, "--- no associations ---")
        else
          print_line(@recursion_level, "--- associations follow ---")
          duplicates = associations.select{|item| associations.count(item) > 1}
          if duplicates.length > 0
            print_line(@recursion_level,
                      "*** De-duplicating the following associations: #{duplicates.inspect} (product bug?) ***")
          end
          associations.uniq.sort.each do |association|
            begin
              associated_objects = Array.wrap(this_object.send(association))
              if associated_objects.length == 0
                print_line(@recursion_level,
                          "#{object_string}.#{association} (type: Association (empty))")
              else
                print_line(@recursion_level, "#{object_string}.#{association} (type: Association)")
                #
                # See if we need to walk this association according to the walk_association_policy
                # variable, and the walk_association_{whitelist,blacklist} hashes
                #
                if @walk_association_policy == 'whitelist'
                  if @walk_association_whitelist.has_key?(this_object_class) &&
                      (@walk_association_whitelist[this_object_class].include?('ALL') ||
                       @walk_association_whitelist[this_object_class].include?(association.to_s))
                    walk_association(object_string, association, associated_objects)
                  else
                    print_line(@recursion_level,
                              "*** not walking: \'#{association}\' isn't in the walk_association_whitelist " \
                              "hash for #{this_object_class} ***")
                  end
                elsif @walk_association_policy == 'blacklist'
                  if @walk_association_blacklist.has_key?(this_object_class) &&
                      (@walk_association_blacklist[this_object_class].include?('ALL') ||
                       @walk_association_blacklist[this_object_class].include?(association.to_s))
                    print_line(@recursion_level,
                              "*** not walking: \'#{association}\' is in the walk_association_blacklist " \
                              "hash for #{this_object_class} ***")
                  else
                    walk_association(object_string, association, associated_objects)
                  end
                else
                  print_line(@recursion_level,
                            "*** Invalid @walk_association_policy: #{@walk_association_policy} ***")
                  exit MIQ_ABORT
                end
              end
            rescue NoMethodError
              print_line(@recursion_level,
                        "*** #{this_object_class} association: \'#{association}\', gives a " \
                        "NoMethodError when accessed (product bug?) ***")
              next
            end
          end
          print_line(@recursion_level, "--- end of associations ---")
        end
      else
        print_line(@recursion_level, "--- no associations ---")
      end
    end
  rescue => err
    $evm.log("error", "#{@method} (print_associations) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end

# End of print_associations
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       print_methods
# Purpose:      Prints the methods (if any) of the object class passed to it
# Arguments:    object_string     : friendly text string name for the object
#               this_object       : the Ruby object whose methods are to be dumped
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def print_methods(object_string, this_object)
  begin
    #
    # Only dump the methods of an MiqAeMethodService::* class
    #
    if this_object.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
      print_line(@recursion_level,
                "Class of remote DRb::DRbObject is: #{this_object.method_missing(:class)}") if @debug
      #
      # Get the instance methods of the class and convert to string
      #
      if this_object.method_missing(:class).respond_to?(:instance_methods)
        instance_methods = this_object.method_missing(:class).instance_methods.map { |x| x.to_s }
        #
        # Now we need to remove method names that we're not interested in...
        #
        # ...attribute names...
        #
        attributes = []
        if this_object.respond_to?(:attributes)
          if this_object.attributes.respond_to? :each
            this_object.attributes.each do |key, value|
              attributes << key
            end
          end
        end
        attributes << "attributes"
        $evm.log("info", "Removing attributes: #{instance_methods & attributes}") if @debug
        instance_methods -= attributes
        #
        # ...association names...
        #
        associations = []
        if this_object.respond_to?(:associations)
          associations = Array.wrap(this_object.associations)
        end
        associations << "associations"
        $evm.log("info", "Removing associations: #{instance_methods & associations}") if @debug
        instance_methods -= associations
        #
        # ...virtual column names...
        #
        virtual_column_names = []
        virtual_column_names = this_object.method_missing(:virtual_column_names)
        virtual_column_names << "virtual_column_names"
        $evm.log("info", "Removing virtual_column_names: #{instance_methods & virtual_column_names}") if @debug
        instance_methods -= virtual_column_names
        #
        # ... MiqAeServiceModelBase methods ...
        #
        $evm.log("info", "Removing MiqAeServiceModelBase methods: " \
                         "#{instance_methods & @service_mode_base_instance_methods}") if @debug
        instance_methods -= @service_mode_base_instance_methods
        #
        # Add in the base methods as it's useful to show that they can be used with this object
        #
        instance_methods += ['inspect', 'inspect_all', 'reload', 'model_suffix',
                             'tags', 'tag_assign', 'tag_unassign', 'tagged_with?']
        #
        # and finally dump out the list
        #
        if instance_methods.length.zero?
          print_line(@recursion_level, "--- no methods ---")
        else
          print_line(@recursion_level, "--- methods follow ---")
          instance_methods.sort.each do |instance_method|
            print_line(@recursion_level, "#{object_string}.#{instance_method}")
          end
          print_line(@recursion_level, "--- end of methods ---")
        end
      else
        print_line(@recursion_level, "--- no methods ---")
      end
    end
  rescue => err
    $evm.log("error", "#{@method} (print_methods) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end
# End of print_methods
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       print_tags
# Purpose:      Prints the tags (if any) of the object class passed to it
# Arguments:    this_object       : the Ruby object whose tags are to be printed
#               this_object_class : the class of the object whose associations are to be dumped
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def print_tags(this_object, this_object_class)
  begin
    if this_object.respond_to?(:tags)
      tags = Array.wrap(this_object.tags)
      if tags.length.zero?
        print_line(@recursion_level, "--- no tags ---")
      else
        print_line(@recursion_level, "--- tags follow ---")
        tags.sort.each do |tag|
          print_line(@recursion_level, "#{tag}")
        end
        print_line(@recursion_level, "--- end of tags ---")
      end
    else
      print_line(@recursion_level, "--- no tags ---")
    end
    
  rescue NoMethodError
    print_line(@recursion_level,
              "*** #{this_object_class} gives a NoMethodError when the :tags method is accessed (product bug?) ***")
  rescue => err
    $evm.log("error", "#{@method} (print_tags) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end
# End of print_tags
#-------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------
# Method:       print_custom_attributes
# Purpose:      Prints the custom attributes (if any) of the object class passed to it
# Arguments:    object_string     : friendly text string name for the object
#               this_object       : the Ruby object whose tags are to be printed
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def print_custom_attributes(object_string, this_object)
  begin
    if this_object.respond_to?(:custom_keys)
      custom_attribute_keys = Array.wrap(this_object.custom_keys)
      if custom_attribute_keys.length.zero?
        print_line(@recursion_level, "--- no custom attributes ---")
      else
        print_line(@recursion_level, "--- custom attributes follow ---")
        custom_attribute_keys.sort.each do |custom_attribute_key|
          custom_attribute_value = this_object.custom_get(custom_attribute_key)
          print_line(@recursion_level, "#{object_string}.custom_get(\'#{custom_attribute_key}\') = \'#{custom_attribute_value}\'")
        end
        print_line(@recursion_level, "--- end of custom attributes ---")
      end
    else
      print_line(@recursion_level, "--- The #{object_string} object does not support custom attributes ---")
    end    
  rescue => err
    $evm.log("error", "#{@method} (print_custom_attributes) - [#{err}]\n#{err.backtrace.join("\n")}")
  end
end
# End of print_custom_attributes
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       walk_object
# Purpose:      Prints the details of the object passed to it
# Arguments:    indent_level      : the numeric value to use to indicate output indent (represents recursion depth)
#               object_string : friendly text string name for the object
#               this_object   : the Ruby object to be dumped
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def walk_object(object_string, this_object)
  begin
    #
    # Make sure that we don't exceed our maximum recursion level
    #
    @recursion_level += 1
    if @recursion_level > @max_recursion_level
      print_line(@recursion_level, "*** exceeded maximum recursion level ***")
      @recursion_level -= 1
      return
    end
    #
    # Make sure we haven't dumped this object already (some data structure links are cyclical)
    #
    this_object_id = this_object.id.to_s rescue this_object.object_id.to_s
    print_line(@recursion_level,
              "Debug: this_object.method_missing(:class) = #{this_object.method_missing(:class)}") if @debug
    this_object_class = "#{this_object.method_missing(:class)}".demodulize
    print_line(@recursion_level, "Debug: this_object_class = #{this_object_class}") if @debug
    if @object_recorder.key?(this_object_class)
      if @object_recorder[this_object_class].include?(this_object_id)
        print_line(@recursion_level,
                  "Object #{this_object_class} with ID #{this_object_id} has already been printed...")
        @recursion_level -= 1
        return
      else
        @object_recorder[this_object_class] << this_object_id
      end
    else
      @object_recorder[this_object_class] = []
      @object_recorder[this_object_class] << this_object_id
    end
    #
    # Dump out the things of interest
    #
    print_attributes(object_string, this_object)
    print_virtual_columns(object_string, this_object, this_object_class)
    print_associations(object_string, this_object, this_object_class)
    print_methods(object_string, this_object) if @print_methods
    # print_tags(this_object, this_object_class)  Commented out until all service model classes support the tag-related methods
    print_custom_attributes(object_string, this_object)
  
    @recursion_level -= 1
  rescue => err
    $evm.log("error", "#{@method} (walk_object) - [#{err}]\n#{err.backtrace.join("\n")}")
    @recursion_level -= 1
  end
end

# End of walk_object
#-------------------------------------------------------------------------------------------------------------

# -------------------------------------------- Start of main code --------------------------------------------
begin
  @recursion_level    = 0
  MAX_RECURSION_LEVEL = 7
  @object_recorder    = {}
  @debug              = false
  @print_methods      = true
  @print_evm_object   = false
  #
  # We need to record the instance methods of the MiqAeMethodService::MiqAeServiceModelBase class so that we can
  # subtract this list from the methods we discover for each object
  #
  @service_mode_base_instance_methods = []
  #
  # Change @max_recursion_level to adjust the depth of recursion that object_walker traverses through the objects
  #
  @max_recursion_level = $evm.object['max_recursion_level'] || MAX_RECURSION_LEVEL
  #
  # @print_nil_values can be used to toggle whether or not to include keys that have a nil value in the
  # output dump. There are often many, and including them will usually increase verbosity, but it is
  # sometimes useful to know that a key/attribute exists, even if it currently has no assigned value.
  #
  @print_nil_values = $evm.object['print_nil_values'].nil? ? true : $evm.object['print_nil_values']
  unless [FalseClass, TrueClass].include? @print_nil_values.class
    $evm.log(:error, "*** print_nil_values must be a boolean value ***")
    exit MIQ_ERROR
  end
  #
  # @walk_association_policy should have the value of either 'whitelist' or 'blacklist'. This will determine whether we either 
  # walk all associations _except_ those in the walk_association_blacklist hash, or _only_ the associations in the
  # walk_association_whitelist hash
  #
  @walk_association_policy = $evm.object['walk_association_policy'] || 'whitelist'
  #
  # if @walk_association_policy = 'whitelist', then object_walker will only traverse associations of objects that are explicitly
  # mentioned in the @walk_association_whitelist hash. This enables us to carefully control what is dumped. If object_walker finds
  # an association that isn't in the hash, it will print a line similar to:
  #
  # $evm.root['user'].current_tenant (type: Association)
  # *** not walking: 'current_tenant' isn't in the walk_association_whitelist hash for MiqAeServiceUser ***
  #
  # If you wish to explore and dump this association, edit the hash to add the association name to the list associated with the object type. The string
  # 'ALL' can be used to walk all associations of an object type
  #
  dialog_walk_association_whitelist = ($evm.root['dialog_walk_association_whitelist'] != '') ? $evm.root['dialog_walk_association_whitelist'] : nil
  walk_association_whitelist = dialog_walk_association_whitelist || $evm.object['walk_association_whitelist']
  #
  # if @walk_association_policy = 'blacklist', then object_walker will traverse all associations of all objects, except those
  # that are explicitly mentioned in the @walk_association_blacklist hash. This enables us to run a more exploratory dump, at the cost of a
  # much more verbose output. The string 'ALL' can be used to prevent walking any associations of an object type
  #
  # You have been warned, using a blacklist walk_association_policy produces a lot of output!
  #
  dialog_walk_association_blacklist = ($evm.root['dialog_walk_association_blacklist'] != '') ? $evm.root['dialog_walk_association_blacklist'] : nil
  walk_association_blacklist = dialog_walk_association_blacklist || $evm.object['walk_association_blacklist'] 
  #
  # Generate a random string to identify this object_walker dump
  #
  randomstring = SecureRandom.hex(4).upcase
  @method = "object_walker##{randomstring}"
  
  $evm.log("info", "#{@method}:   Object Walker #{VERSION} Starting")
  print_line(0, "*** detected 'print_nil_values = false' so attributes with nil values will not be printed ***") if !@print_nil_values
  
  if @print_methods
    #
    # If we're dumping object methods, then we need to find out the methods of the
    # MiqAeMethodService::MiqAeServiceModelBase class so that we can subtract them from the method list
    # returned from each object. We know that MiqAeServiceModelBase is the superclass of
    # MiqAeMethodService::MiqAeServiceMiqServer, so we can get what we're after via $evm.root['miq_server']
    #
    miq_server = $evm.root['miq_server'] rescue nil
    unless miq_server.nil?
      if miq_server.method_missing(:class).superclass.name == "MiqAeMethodService::MiqAeServiceModelBase"
        @service_mode_base_instance_methods = miq_server.method_missing(:class).superclass.instance_methods.map { |x| x.to_s }
      else
        $evm.log("error", "#{@method} Unexpected parent class of $evm.root['miq_server']: " \
                          "#{miq_server.method_missing(:class).superclass.name}")
        @print_methods = false
      end
    else
      $evm.log("error", "#{@method} $evm.root['miq_server'] doesn't exist")
      @print_methods = false
    end
  end
  
  print_line(0, "--- walk_association_policy details ---")
  print_line(0, "walk_association_policy = #{@walk_association_policy}")
  case @walk_association_policy
  when 'whitelist' 
    if walk_association_whitelist.nil?
      $evm.log(:error, "*** walk_association_whitelist not found, please define one as an instance attribute or a dialog variable ***")
      exit MIQ_ERROR
    else
      @walk_association_whitelist = JSON.parse(walk_association_whitelist.gsub(/\s/,'').gsub(/(?<!\\)'/, '"').gsub(/\\/,''))
      print_line(0, "walk_association_whitelist = #{walk_association_whitelist}")
    end
  when 'blacklist'
    if walk_association_blacklist.nil?
      $evm.log(:error, "*** walk_association_blacklist not found, please define one as an instance attribute or a dialog variable ***")
      exit MIQ_ERROR
    else
      @walk_association_blacklist = JSON.parse(walk_association_blacklist.gsub(/(?<!\\)'/, '"').gsub(/\\/,'').gsub(/\s/,''))
      print_line(0, "walk_association_blacklist = #{walk_association_blacklist}")
    end
  end
  #
  # Start with some $evm.current attributes
  #
  print_line(0, "--- $evm.current_* details ---")
  print_line(0, "$evm.current_namespace = #{$evm.current_namespace}   #{type($evm.current_namespace)}")
  print_line(0, "$evm.current_class = #{$evm.current_class}   #{type($evm.current_class)}")
  print_line(0, "$evm.current_instance = #{$evm.current_instance}   #{type($evm.current_instance)}")
  print_line(0, "$evm.current_method = #{$evm.current_method}   #{type($evm.current_method)}")
  print_line(0, "$evm.current_message = #{$evm.current_message}   #{type($evm.current_message)}")
  print_line(0, "$evm.current_object = #{$evm.current_object}   #{type($evm.current_object)}")
  print_line(0, "$evm.current_object.current_field_name = #{$evm.current_object.current_field_name}   " \
               "#{type($evm.current_object.current_field_name)}")
  print_line(0, "$evm.current_object.current_field_type = #{$evm.current_object.current_field_type}   " \
                "#{type($evm.current_object.current_field_type)}")

  #
  # and now print the object hierarchy...
  #
  print_line(0, "--- automation instance hierarchy ---")
  Struct.new('ServiceObject', :obj_name, :position, :children)
  # automation_object_hierarchy = Struct::ServiceObject.new(nil, nil, Array.new)
  automation_object_hierarchy = walk_automation_objects($evm.root)
  print_automation_objects(0, automation_object_hierarchy)
  #
  # then walk and print $evm.root downwards...
  #
  print_line(0, "--- walking $evm.root ---")
  print_line(0, "$evm.root = #{$evm.root}   #{type($evm.root)}")
  walk_object("$evm.root", $evm.root)
  #
  # and finally $evm.object if requested...
  #
  if @print_evm_object
    print_line(0, "--- walking $evm.object ---")
    print_line(0, "$evm.object = #{$evm.object}   #{type($evm.object)}")
    walk_object("$evm.object", $evm.object)
  end
  #
  # Exit method
  #
  $evm.log("info", "#{@method}:   Object Walker Complete")
  exit MIQ_OK
rescue JSON::ParserError  => err
  $evm.log("error", "#{@method} (object_walker) - Invalid JSON string passed as #{@walk_association_policy}")
  $evm.log("error", "#{@method} (object_walker) - Err: #{err.inspect}")
  exit MIQ_ERROR
rescue => err
  $evm.log("error", "#{@method} (object_walker) - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ERROR
end
