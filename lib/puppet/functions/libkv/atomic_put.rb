# Set `key` to `value`, but only if the key is still set to `previous`
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::atomic_put') do

  # @param parameters Hash of all parameters
  #
  # @return [Boolean] Whether the backend set operation succeeded
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :atomic_put do
    param 'Hash', :parameters
  end

  # @param key The key to be set
  # @param value The value of the key
  # @param previous Hash containing the previous value of the key
  #
  # @return [Boolean] Whether the backend set operation succeeded
  #
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :atomic_put_v1 do
    param 'String', :key
    param 'Any', :value
    param 'Hash', :previous
  end

  def atomic_put_v1(key, value, previous)
    params = {}
    params['key'] = key
    params['value'] = value
    params['previous'] = previous

    atomic_put(params)
  end

  def atomic_put(params)
    nparams = params.dup

    # retrieve/create the libkv 'extension' of the catalog instance
    catalog = closure_scope.find_global_scope.catalog
    libkv = nil
    begin
      libkv = catalog.libkv
    rescue NoMethodError
      lib_dir = File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}"))))
      filename = File.join(lib_dir, 'puppet_x', 'libkv', 'loader.rb')
      if File.exists?(filename)
        catalog.instance_eval(File.read(filename), filename)
        libkv = catalog.libkv
      else
        raise("Internal error: libkv::atomic_put unable to load #{filename}: File not found")
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

    # use libkv for atomic_put operation
    retval = nil
    if (nparams['softfail'] == true)
      begin
        retval = libkv.atomic_put(url, auth, nparams);
      rescue
        retval = {}
      end
    else
      retval = libkv.atomic_put(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
