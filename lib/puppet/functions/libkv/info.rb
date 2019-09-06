# Return a hash of informtion on the underlying provider. Provider specific
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::info') do

  # @param parameters Hash of all parameters
  #
  # @return [Hash] Provider information hash
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :info do
    param 'Hash', :parameters
  end

  # @return [Hash] Provider information hash
  #
  dispatch :info_empty do
  end

  def info_empty
     self.info({})
  end

  def info(params)
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
        raise("Internal error: libkv::info unable to load #{filename}: File not found")
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

    # use libkv for info operation
    retval = nil
    if (nparams['softfail'] == true)
      begin
        retval = libkv.info(url, auth, nparams);
      rescue
        retval = {}
      end
    else
      retval = libkv.info(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
