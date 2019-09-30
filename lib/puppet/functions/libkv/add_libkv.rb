# Add libkv 'extension' to the catalog instance, if it is not present
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::add_libkv') do

  # @return [Nil]
  # @raise LoadError if libkv adapter software fails to load
  #
  dispatch :add_libkv do
  end

  def add_libkv
    catalog = closure_scope.find_global_scope.catalog
    unless catalog.respond_to?(:libkv)
      # load and instantiate libkv adapter and then add it as a
      # 'libkv' attribute to the catalog instance
      lib_dir = File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}"))))
      filename = File.join(lib_dir, 'puppet_x', 'libkv', 'loader.rb')
      if File.exists?(filename)
        begin
          catalog.instance_eval(File.read(filename), filename)
        rescue SyntaxError => e
          raise LoadError.new("libkv Internal Error: unable to load #{filename}: #{e.message}")
        end
      else
        raise LoadError.new("libkv Internal Error: unable to load #{filename}: File not found")
      end
    end
  end

end
