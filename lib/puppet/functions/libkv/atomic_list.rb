# List all keys in folder `key`, but return them in a format suitable for other atomic functions
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::atomic_list') do

  # @param parameters Hash of all parameters
  #
  # @return [Hash] Hash of key/value pairs
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :atomic_list do
    param 'Hash', :parameters
  end

  # @param key The folder to list
  #
  # @return [Hash] Hash of key/value pairs
  #
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :atomic_list_v1 do
    param 'String', :key
  end

  def atomic_list_v1(key)
    params = {}
    params['key'] = key

    atomic_list(params)
  end

  def atomic_list(params)
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
        raise("Internal error: libkv::atomic_list unable to load #{filename}: File not found")
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

    # use libkv for atomic_list operation
    retval = nil
    if (nparams['softfail'] == true)
      begin
        retval = libkv.atomic_list(url, auth, nparams);
      rescue
        retval = {}
      end
    else
      retval = libkv.atomic_list(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
