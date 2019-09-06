# Connects to the backend and retrieves the data stored at **key**
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::get') do

  # @param parameters Hash of all parameters
  #
  # @return [Any] The value in the underlying backing store
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :get do
    param 'Hash', :parameters
  end

  # @param key The key to get
  #
  # @return [Any] The value in the underlying backing store
  #
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :get_v1 do
    param 'String', :key
  end

  def get_v1(key)
    params = {}
    params['key'] = key

    get(params)
  end

  def get(params)
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
        raise("Internal error: libkv::get unable to load #{filename}: File not found")
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

    # use libkv for get operation
    retval = nil
    if (nparams['softfail'] == true)
      begin
        retval = libkv.get(url, auth, nparams);
      rescue
        retval = nil
      end
    else
      retval = libkv.get(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
