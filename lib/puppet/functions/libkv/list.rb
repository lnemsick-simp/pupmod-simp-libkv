# Returns a list of all keys in a folder.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::list') do

  dispatch :list do
    required_param 'String[1]', :keydir
    optional_param 'Hash',      :backend_options
  end

  def list(keydir, backend_options={})
#FIXME
  end
end
