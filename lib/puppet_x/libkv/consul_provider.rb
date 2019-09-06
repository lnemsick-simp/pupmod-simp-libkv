# vim: set expandtab ts=2 sw=2:
provider_class = Class.new do
  require 'net/http'
  require 'uri'
  require 'base64'

  def self.name
    'consul'
  end

  def initialize(url, auth)
    @uri = URI.parse(url)
    @resturi = URI.parse(url)
    scheme_split = @uri.scheme.split("+")
    # defaults
    @resturi.scheme = "http"
    @verifyssl = true
    scheme_split.each do |modifier|
      case modifier
      when "ssl"
        @resturi.scheme = "https"
      when "nossl"
        @resturi.scheme = "http"
      when "verify"
        @verifyssl = true
      when "noverify"
        @verifyssl = false
      end
    end
    @auth = auth
    @basepath = @uri.path.chomp("/")
    # XXX: Todo: break out the rest client into a mixin
    #
    #    self.extend($LIBKV.restclient);
    #

  end

  # Begin REST Client

  def rest_request(params = {})
    unless params.key?(:method)
      params[:method] = 'GET'
    end
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = @resturi.scheme == 'https'
    if (@resturi.scheme == 'https')
      if (@auth != nil)
        if (@auth.key?("ca_file"))
          http.ca_file = @auth["ca_file"]
        end
        if (@auth.key?("cert_file"))
          http.cert = OpenSSL::X509::Certificate.new(File.read(@auth["cert_file"]))
        end
        if (@auth.key?("key_file"))
          http.key = OpenSSL::PKey::RSA.new(File.read(@auth["key_file"]))
        end
      end
      if (@verifyssl == true)
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end
    case params[:method]
    when 'GET'
      request = Net::HTTP::Get.new(params[:path])
    when 'DELETE'
      request = Net::HTTP::Delete.new(params[:path])
    when 'PUT'
      request = Net::HTTP::Put.new(params[:path])
      request.body = params[:body].to_s
    end
    if (params.key?("headers"))
      params["headers"].each do |key, value|
        request[key] = value
      end
    end
    response = http.request(request)
  end

  # End REST Client
  def consul_request(params)
    headers = {}
    if (@auth != nil)
      headers['X-Consul-Token'] = @auth["token"]
    end
    params["headers"] = headers
    rest_request(params)
  end
  def supports(params)
    [
      "delete",
      "deletetree",
      'get',
      'put',
      'exists',
      'list',

      'atomic_create',
      'atomic_delete',
      'atomic_get',
      'atomic_put',
      'atomic_list',

      'empty_value',
      'info',
      'provider',
      'supports',
    ]
  end
  def provider(params)
    "consul"
  end
  def get(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    begin
      response = consul_request(path: "/v1/kv" + @basepath + key)
      if (response.class == Net::HTTPOK)
        json = response.body
        parsed = JSON.parse(json)[0];
        value = Base64.decode64(parsed['Value']);
      elsif (response.class == Net::HTTPNotFound)
        self.empty_value({})['value']
      else
      end
    rescue
      nil
    end
  end

  def put(params)
    retval = {}
    debug = params['debug']
    key = params['key']
    value = params['value']

    if (key == nil)
      raise "Put requires 'key' to be specified"
    end

    if (value == nil)
      raise "Put requires 'value' to be specified"
    end
    response = consul_request(path: "/v1/kv" + @basepath + key, method: 'PUT', body: value)
    if (debug == true)
      retval["response_class"] = response.class
      retval["response_body"] = response.body
    end
    if (response.class == Net::HTTPOK)
      if (response.body == "true\n")
        retval["result"] = true
      else
        retval["result"] = false
      end
    else
      retval["result"] = false
    end
    unless (params["debug"] == true)
      retval = retval["result"]
    end
    return retval
  end

  def atomic_get(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    begin
      response = consul_request(path: "/v1/kv" + @basepath + key)
      if (response.class == Net::HTTPOK)
        json = response.body
        parsed = JSON.parse(json)[0];
        parsed['value'] = Base64.decode64(parsed['Value']);
        parsed
      elsif (response.class == Net::HTTPNotFound)
        self.empty_value({})
      else
        throw Exception
      end
    rescue
      throw Exception
    end
  end
  def atomic_create(params)
    empty = empty_value()
    atomic_put(params.merge({ 'previous' => empty}))
  end
  def atomic_put(params)
    key = params['key']
    value = params['value']
    previous = params['previous']

    if (key == nil)
      throw Exception
    end

    if (value == nil)
      throw Exception
    end
    if (previous == nil)
      throw Exception
    end
    previndex=previous["ModifyIndex"]
    path = "/v1/kv" + @basepath + key + "?cas=" + previndex.to_s
    response = consul_request(path: path, method: 'PUT', body: value)
    if (response.class == Net::HTTPOK)
      if (response.body =~ /true/)
        true
      else
        false
      end
    elsif(response.class == Net::HTTPInternalServerError)
      false
    else
      false
    end
  end
  def atomic_delete(params)
    key = params['key']
    previous = params['previous']

    if (key == nil)
      throw Exception
    end
    if (previous == nil)
      throw Exception
    end
    previndex=previous["ModifyIndex"]
    response = consul_request(path: "/v1/kv" + @basepath + key + "?cas=" + previndex.to_s, method: 'DELETE')
    if (response.class == Net::HTTPOK)
      if (response.body =~ /true/)
        true
      else
        false
      end
    else
      false
    end
  end
  def delete(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    # Get the value of key first. This is the only way to tell if we try to delete a key
    response = consul_request(path: "/v1/kv" + @basepath + key, method: 'DELETE')
    if (response.class == Net::HTTPOK)
      if (response.body =~ /true/)
        true
      else
        false
      end
    else
      false
    end
  end
  def deletetree(params)
  end
  def info(params)
  end
  def atomic_list(params)
    key = params['key']
    last_char = key.slice(key.size - 1,1)
    if (last_char != "/")
      key = key + "/"
    end
    if (key == nil)
      throw Exception
    end
    retval = {}
    begin
      response = consul_request(path: "/v1/kv" + @basepath + key + "?recurse")
      if (response.class == Net::HTTPOK)
        json = response.body
        value = JSON.parse(json)
      else
        return retval
      end
    rescue
      return retval
    end

    last_char = key.slice(key.size - 1,1)
    if (last_char != "/")
      key = key + "/"
    end
    reg = Regexp.new("^" + @basepath.gsub(/^\//, "") + key)
    unless (value == nil)
      value.each do |entry|
        nkey = entry["Key"].gsub(reg,"")
        retval[nkey] = entry
        unless (entry["Value"] == nil)
          retval[nkey]["value"] = Base64.decode64(entry["Value"])
        else
          retval[nkey]["value"] = nil
        end
        retval[nkey].delete("Value")
        retval[nkey].delete("Key")
      end
    end
    retval
  end
  def list(params)
    list = atomic_list(params)
    retval = {}
    unless (list == nil)
      list.each do |key, entry|
        retval[key] = entry["value"]
      end
    end
    retval
  end
  def exists(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    # Get the value of key first. This is the only way to tell if we try to delete a key
    response = consul_request(path: "/v1/kv" + @basepath + key + "?keys", method: 'GET')
    if (response.class == Net::HTTPOK)
      true
    elsif(response.class == Net::HTTPNotFound)
      false
    else
      false
    end

  end
  def empty_value(params = {})
    {
      "ModifyIndex" => 0,
      "value" => nil
    }
  end
end
