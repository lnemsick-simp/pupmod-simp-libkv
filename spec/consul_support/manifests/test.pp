class libkv::test(
$url = 'mock://'
) {
  $supports = libkv::supports({'url' => $url})
  notify { "supports = ${supports}": }
  $provider = libkv::provider({'url' => $url})
  notify { "provider = ${provider}": }
  $loopvar = {
    '/meats/pork'    => 'test1',
    '/meats/chicken' => 'test4',
    '/meats/turkey'  => 'test5',
    '/meats/beef'    => 'test2',
    '/fruits/apple'  => 'test3',
    '/fruits/banana' => 'test4',
  }.each |$key, $value| {
          libkv::put({ 'url' => $url, 'key' => $key, 'value' => $value});
    $get = libkv::get({'url' => $url, 'key'       => $key});
          notify { "${key} get = ${get}": }
    $atomic_get = libkv::atomic_get({'url' => $url, 'key' => $key});
          notify { "${key} atomic_get = ${atomic_get}": }
    libkv::atomic_put({'url'            => $url, 'key' => $key, 'value' => 'testzor', 'previous' => $atomic_get});
    $atomic_put = libkv::atomic_get({'url' =>  $url, 'key'       => $key});
          notify { "${key} atomic_put = ${atomic_put}": }
      $info = libkv::info({'url' => $url})
    notify { "${key} info = ${info}": }
  }
  $list = libkv::list({ 'url' => $url, 'key' => '/meats' })
  notify { "first list = ${list}": }
        libkv::delete({'url'  => $url, 'key' => '/meats/pork'})
  $listm = libkv::list({'url' => $url, 'key'       => '/meats' })
  notify { "second list = ${listm}": }
  libkv::put({ 'url' => $url, 'key' => "/hosts/${trusted[certname]}/ipaddress", 'value' => $::ipaddress})
}
