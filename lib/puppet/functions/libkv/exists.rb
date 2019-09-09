# Returns true if `key` exists
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::exists') do

  # @param parameters Hash of all parameters
  #
  # @return [Boolean] Whether the `key` exists in the backend
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :exists do
    param 'Hash', :parameters
  end

  # @param key The key to check
  #
  # @return [Boolean] Whether the `key` exists in the backend
  #
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :exists_v1 do
    param 'String', :key
  end

  def exists_v1(key)
    params = {}
    params['key'] = key

    exists(params)
  end

  def exists(params)
    # ensure all required parameters are present
    validate_params(params)

    # add defaults for optional parameters
    nparams = update_params(params)

    # add libkv 'extension' to the catalog instance as needed
    catalog = closure_scope.find_global_scope.catalog
    unless catalog.respond_to?(:libkv)
      lib_dir = File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}"))))
      filename = File.join(lib_dir, 'puppet_x', 'libkv', 'loader.rb')
      if File.exists?(filename)
        catalog.instance_eval(File.read(filename), filename)
      else
        raise("Internal error: libkv::exists unable to load #{filename}: File not found")
      end
    end

    # use libkv for exists operation
    retval = nil
    begin
      retval = catalog.libkv.exists(nparams['url'], nparams['auth'], nparams);
    rescue Exception => e
      if nparams['softfail']
        retval = []
      else
        raise(e)
      end
    end

    return retval;
  end

  # Add defaults for missing, optional parameters and Puppet info
  # @param input parameters (read-only)
  # @return copy of params that has been updated
  def update_params(params)
    nparams = params.dup

    # determine url and auth parameters to use
    unless nparams.key?('url')
      nparams['url'] = call_function('lookup', 'libkv::url', { 'default_value' => 'mock://' })
    end

    unless nparams.key?('auth')
      nparams['auth'] = call_function('lookup', 'libkv::auth', { 'default_value' => nil })
    end

    # add Puppet info to params
    unless nparams.key?('environment')
      nparams['environment'] = closure_scope.lookupvar('::environment')
    end

    unless nparams.key?('user')
      nparams['user'] = Puppet.settings[:user] ? Puppet.settings[:user] : 'puppet'
    end

    unless nparams.key?('group')
      nparams['group'] = Puppet.settings[:group] ? Puppet.settings[:group] : 'group'
    end

    unless nparams.key?('puppet_vardir')
      nparams['group'] = Puppet.settings[:vardir] ? Puppet.settings[:vardir] : 'vardir'
    end

    nparams
  end


  # check for required parameters
  # @param input parameters
  # @raise ArgumentError if any required parameters are missing
  def validate_params(params)
  end
end
