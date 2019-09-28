# This is a sample libkv wrapper that correctly selects a default
# backend in a default hierarchy, when called from a class or define, directly.
#
# It has to be an InternalFunction in order to have access to full scope.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv_test::put_rwrapper', Puppet::Functions::InternalFunction) do

 
  # @param key The key to be set
  # @param value The value of the key
  # @param metadata Additional information to be persisted
  # @param options Hash that specifies global libkv options and/or the specific
  #   backend to use (with or without backend-specific configuration).
  #   Will be merged with `libkv::options`.
  # ... 
  #
  dispatch :put_rwrapper do
    scope_param()
    required_param 'String[1]', :key
    required_param 'NotUndef',  :value
    optional_param 'Hash',      :metadata
    optional_param 'Hash',      :options
  end

  def put_rwrapper(scope, key, value, metadata={}, options={})
    # Need to create merged libkv options while we have access
    # to the caller info.  In order to create this, we need
    # the libkv catalog 'extension'.
    call_function('libkv::add_libkv')

    # Get merged libkv config
    merged_options = nil
    begin
      calling_resource = get_calling_resource(scope)
      catalog = scope.find_global_scope.catalog
      merged_options = call_function('libkv::get_backend_config', options,
        catalog.libkv.backends, calling_resource)
    rescue ArgumentError => e
      # need to handle the config error just as libkv::put would do
      msg = "libkv Configuration Error for libkv::list with keydir='#{keydir}': #{e.message}"
      raise ArgumentError.new(msg)
    end

    #
    # Insert some application-specific work
    # 

    # delegate put operation to libkv::put
    result = call_function('libkv::put', key, value, metadata, merged_options)
  end

  # TODO Use the TBD common function in PuppetX namespace instead of copying
  # this code everywhere.
  def get_calling_resource(callers_scope)
    calling_resource = 'Class[main]'
    current_scope = callers_scope
    found = false
    while !found
      scope_s = current_scope.to_s
      if scope_s.start_with?('Scope(')
        calling_resource = scope_s.split('Scope(').last[0..-2]
        found = true
      end
      found = true if current_scope.is_topscope?
      current_scope = current_scope.parent
    end
    calling_resource
  end
end
