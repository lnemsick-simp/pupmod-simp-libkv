#!/opt/puppetlabs/puppet/bin/ruby

require 'rubygems'
require 'net/ldap'

$debug = true

def debug(x)
  puts x if $debug
end

def print_pairs(ldap, treebase)
  attrs = ['simpkvKey', 'simpkvJsonValue' ]
  ldap.search(:base => treebase, :attributes => attrs) do |entry|
    key = nil
    value = nil
    entry.each do |attribute, values|
      if attribute == :simpkvkey
        key = values.first
      elsif attribute == :simpkvjsonvalue
        value = values.first
      end
    end

    puts "DN: #{entry.dn}"
    puts "  < #{key}, #{value} >"
  end
end

Net::LDAP.open(
  {
    :host => '10.255.144.55',
    :port => 388,
    :auth => {
      :method => :simple,
      :username => "cn=Directory_Manager",
      :password => "P@ssw0rdP@ssw0rd"
    }
  }

) do |ldap|

  # Under the hood the open first does a bind.  If that bind fails,
  # can't do anything else
  bind_result = ldap.get_operation_result
  if (bind_result.code == 0)
    debug('Bind succeeded')
  else
    raise "Bind failed with code #{bind_result.code}: #{bind_result.message}"
  end

#filter = Net::LDAP::Filter.eq("cn", "George*")
  treebase = "ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp"

  dnbase = 'ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp'

  dn1 = "simpkvKey=newkey2,#{dnbase}"
  attr1 = {
    :objectclass     => ['top', 'simpkvEntry'],
    :simpkvkey       => 'newkey2',
    :simpkvjsonvalue => 'newkey2 value',
  }

  ldap.add(:dn => dn1, :attributes => attr1)
  puts '#'*80
  puts ldap.get_operation_result
  print_pairs(ldap,treebase)

  dn2 = "simpkvKey=NEWKEY2,#{dnbase}"
  attr2 = {
    :objectclass     => ['top', 'simpkvEntry'],
    :simpkvkey       => 'NEWKEY2',
    :simpkvjsonvalue => 'NEWKEY2 value',
  }

  puts
  puts '#'*80
  ldap.add(:dn => dn2, :attributes => attr2)
  puts ldap.get_operation_result
  print_pairs(ldap,treebase)
end

