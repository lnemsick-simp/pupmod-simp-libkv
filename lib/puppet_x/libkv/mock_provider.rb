# vim: set expandtab ts=2 sw=2:

provider_class = Class.new do
  def self.name
    'mock'
  end

  def initialize(url, auth)
puts "mock constructed"
    @root = {};
    @mutex = Mutex.new();
    @sequence = 1;
  end
  def get(params)
    retval = {}
    if (params.key?('key') == false)
        raise "key must be specified"
    end
puts "mock::get with key=#{params['key'].inspect}"
    key = params['key'];
    value = @root[key];
    if value.class == Hash
      retval["result"] = value['value'];
    else
      retval["result"] = nil
    end
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end

  def atomic_get(params)
    retval = {}
    key = params['key'];
    if (key == nil)
      throw Exception
    end
puts "mock::get with key=#{params['key'].inspect}"
    if (@root.key?(key))
      retval["result"] = @root[key];
    else
      retval["result"] = self.empty_value()
    end
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def put(params)
    retval = {}
    key = params['key'];
    if (key == nil)
      throw Exception
    end
    value = params['value'];
    if (value == nil)
      throw Exception
    end
puts "mock::put with key=#{params['key'].inspect} value=#{params['value'].inspect}"
    @mutex.synchronize do
      @sequence += 1;
      @root[key] = {
        'sequence' => @sequence,
        'key' => key,
        'value' => value.to_s,
      }
    end
    retval["result"] = true
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def atomic_put(params)
    retval = {}
    key = params['key'];
    if (key == nil)
      throw Exception
    end
puts "mock::atomic_put with key=#{params['key'].inspect} value=#{params['value'].inspect}"
    value = params['value'];
    previous = params['previous'];
    @mutex.synchronize do
      previous_entry = atomic_get({'key' => key})
      if (previous_entry['sequence'] == previous['sequence'])
        @sequence += 1;
        @root[key] = {
          'sequence' => @sequence,
          'key' => key,
          'value' => value.to_s,
        }
        retval["result"] = true
      else
        retval["result"] = false
      end
    end
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def atomic_create(params)
puts "mock::atomic_create with key=#{params['key'].inspect} value=#{params['value'].inspect}"
    empty = empty_value()
    atomic_put(params.merge({ 'previous' => empty}))
  end

  def delete(params)
    retval = {}
    unless(params.key?('key'))
      throw Exception
    end
    key = params['key']
puts "mock::delete with key=#{params['key'].inspect}"
    @mutex.synchronize do
      @sequence += 1;
      if (@root.key?(key))
        @root.delete(key)
        retval["result"] = true
      else
        retval["result"] = true
      end
    end
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def atomic_delete(params)
    retval = {}
    key = params['key'];
    if (key == nil)
      throw Exception
    end
    unless (params.key?('previous'))
      throw Exception
    end
    previous = params['previous']
puts "mock::atomic_delete with key=#{params['key'].inspect} previous=#{params['previous'].inspect}"
    # if previous == nil
    #  previous = empty_value()
    # end
    @mutex.synchronize do
      previous_entry = atomic_get({'key' => key})
      if (previous_entry['sequence'] == previous['sequence'])
        unless (previous_entry['sequence'] == -1)
          @sequence += 1;
          @root.delete(key);
          retval["result"] = true
        else
          retval["result"] = true
        end
      else
        retval["result"] = false
      end
    end
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def exists(params)
    retval = {}
    unless(params.key?('key'))
      throw Exception
    end
    key = params['key']
puts "mock::exists with key=#{params['key'].inspect}"
    @mutex.synchronize do
      retval["result"] = @root.key?(key)
    end
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def list(params)
    retval = {}
    unless(params.key?('key'))
      raise "'key' must be specified"
    end
    key = params['key']
puts "mock::exists with key=#{params['key'].inspect}"
    hash = @root.select do |k, v|
      if (k =~ Regexp.new(key + '/'))
        true
      else
        false
      end
    end
    nlist = {}
    hash.each do |k, v|
      reg = Regexp.new("^" + key + "/")
      rkey = k.gsub(reg,"")
      nlist[rkey] = v['value']
    end
    retval["result"] = nlist
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def atomic_list(params)
    retval = {}
    unless(params.key?('key'))
      raise "'key' must be specified"
    end
    key = params['key']
puts "mock::atomic_list with key=#{params['key'].inspect}"
    hash = @root.select do |k, v|
      if (k =~ Regexp.new(key + '/'))
        true
      else
        false
      end
    end
    nlist = {}
    hash.each do |k, v|
      reg = Regexp.new("^" + key + "/")
      rkey = k.gsub(reg,"")
      nlist[rkey] = v
    end
    retval["result"] = nlist
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def deletetree(params)
puts "mock::deletetree params=#{params}"
    retval = {}
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def empty_value(params = {})
    retval = {}
    retval["result"] = {
      "sequence" => -1,
      "value" => nil
    }
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
  def provider(params = {})
puts "mock::provider params=#{params}"
    retval = {}
    retval["result"] = "mock"
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end

  def info(params = {})
puts "mock::provider params=#{params}"
    retval = {}
    retval["result"] = { "sequence" => @sequence }
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end

  def supports(params = {})
puts "mock::supports params=#{params}"
    retval = {}
    retval["result"] = [
      "delete",
      "deletetree",
      "get",
      "put",
      "exists",
      "list",

      "atomic_create",
      "atomic_delete",
      "atomic_get",
      "atomic_put",
      "atomic_list",

      "empty_value",
      "info",
      "provider",
      "supports",
    ]
    if (params['debug'] == true)
      retval
    else
      retval["result"]
    end
  end
end
