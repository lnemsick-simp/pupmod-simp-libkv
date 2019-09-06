# Store `value` in `key` atomically, but only if key does not already exist
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::atomic_create') do

  # @param parameters Hash of all parameters
  #
  # @return [Boolean] Whether the backend create operation succeeded
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :atomic_create do
    param 'Hash', :parameters
  end

  # @param key The key to be created
  # @param value The value of the key
  #
  # @return [Boolean] Whether the backend create operation succeeded
  #
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :atomic_create_v1 do
    param 'String', :key
    param 'Any', :value
  end

  def atomic_create_v1(key, value)
    params = {}
    params['key'] = key
    params['value'] = value

    atomic_create(params)
  end

  def atomic_create(params)
    nparams = params.dup

    # retrieve/create the libkv 'extension' of the catalog instance
    catalog = closure_scope.find_global_scope.catalog
    libkv = nil
    begin
      libkv = catalog.libkv
    rescue NoMethodError
      lib_dir = File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}"))))
      filename = File.join(lib_dir, 'puppet_x', 'libkv', 'libkv.rb')
      if File.exists?(filename)
        catalog.instance_eval(File.read(filename), filename)
        libkv = catalog.libkv
      else
        raise("Internal error: libkv::atomic_create unable to load #{filename}: File not found")
      end
    end

    # determine url and auth parameters to use
    if nparams.key?('url')
      url = nparams['url']
    else
      url = call_function('lookup', 'libkv::url', { 'default_value' => 'mock://' })
    end
    nparams['url'] = url

    if nparams.key?('auth')
      auth = nparams['auth']
    else
      auth = call_function('lookup', 'libkv::auth', { 'default_value' => nil })
    end
    nparams['auth'] = auth

    # use libkv for atomic_create operation
    retval = nil
    if (nparams['softfail'] == true)
      begin
        retval = libkv.atomic_create(url, auth, nparams);
      rescue
        retval = {}
      end
    else
      retval = libkv.atomic_create(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
