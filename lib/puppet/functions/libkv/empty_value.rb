# Return an hash suitable for other atomic functions, that represents an empty value
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::empty_value') do

  # @param parameters Hash of all parameters
  #
  # @return [Hash] Empty hash representing an empty value
  #
  # @raise [RuntimeError] if Ruby files needed for libkv operation
  # cannot be found
  dispatch :empty_value do
    param 'Hash', :parameters
  end

  # @return [Hash] Empty hash representing an empty value
  #
  dispatch :empty_value_empty do
  end

  def empty_value_empty
     self.empty_value({})
  end

  def empty_value(params)
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
        raise("Internal error: libkv::empty_value unable to load #{filename}: File not found")
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

    # use libkv for empty_value operation
    retval = nil
    if (nparams['softfail'] == true)
      begin
        retval = libkv.empty_value(url, auth, nparams);
      rescue
        retval = nil
      end
    else
      retval = libkv.empty_value(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
