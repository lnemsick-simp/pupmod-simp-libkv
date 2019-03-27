function libkv::lookup(
  Variant[String, Numeric] $key,
  Hash $options,
  Puppet::LookupContext $context,
) {
  case $key {
    'lookup_options': {
      $context.not_found
    }
    'libkv::auth': {
      $context.not_found
    }
    'libkv::url': {
      $context.not_found
    }
    default: {
      if ($options['uri'] == undef) {
        $_key = "/${key}"
        $_url = undef
      } else {
        if ($options['uri'] =~ /.*:\/\/.*\/.*/) {
          $_key = "/${key}"
          $_url = $options['uri']
        } else {
          $_key = "${uri}/${key}"
          $_url = undef
        }

      }
      if (has_key($options, 'softfail')) {
        $_opts = {
          'softfail' => $options['softfail']
        }
      } else {
        $_opts = {
          'softfail' => true
        }
      }
      if (libkv::exists($_opts + { 'url' => $_url, 'key' => $_key})) {
        $ret = libkv::get($_opts + { 'url' => $_url, 'key' =>  $_key})
        if ($ret == undef) {
          $context.not_found
        } else {
          $ret
        }
      } else {
        $context.not_found
      }
    }
  }
}
