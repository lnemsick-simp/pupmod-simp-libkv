[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/libkv.svg)](https://forge.puppetlabs.com/simp/libkv)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/libkv.svg)](https://forge.puppetlabs.com/simp/libkv)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-libkv.svg)](https://travis-ci.org/simp/pupmod-simp-libkv)

#### Table of Contents

<!-- vim-markdown-toc -->

* [Overview](#overview)
* [This is a SIMP module](#this-is-a-simp-module)
* [Module Description](#module-description)
* [Setup](#setup)
  * [What libkv affects](#what-libk-affects)
* [Usage](#usage)
* [Limitations](#limitations)
* [Development](#development)
  * [Plugin Development](#plugin-development)
  * [Unit tests](#unit-tests)
  * [Acceptance tests](#acceptance-tests)

<!-- vim-markdown-toc GFM -->

2. [Usage - Configuration options and additional functionality](#usage)
3. [Plugin Development](#plugin-development)
4. [Function Reference](#function-reference)

    * [libkv::get](#get)
    * [libkv::put](#put)
    * [libkv::delete](#delete)
    * [libkv::exists](#exists)
    * [libkv::list](#list)
    * [libkv::deletetree](#deletetree)
    * [libkv::atomic_create](#atomic_create)
    * [libkv::atomic_delete](#atomic_delete)
    * [libkv::atomic_get](#atomic_get)
    * [libkv::atomic_put](#atomic_put)
    * [libkv::atomic_list](#atomic_list)
    * [libkv::empty_value](#empty_value)
    * [libkv::info](#info)
    * [libkv::supports](#supports)
    * [libkv::pop_error](#pop_error)
    * [libkv::provider](#provider)

5. [Development - Guide for contributing to the module](#development)

    * [Acceptance Tests - Beaker env variables](#acceptance-tests)

## Overview

## This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com)

If you find any issues, please submit them via [JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide] (https://simp.readthedocs.io/en/stable/contributors_guide/index.html).


## Module Description

Provides and abstract library that allows Puppet to access one or more key/value
stores.

This module provides

* a standard Puppet language API (functions) for using key/value stores

  * See [REFERENCE.md](REFERENCE.md) for more details on the available
    functions.

* a configuration scheme that allows users to specify per-application use
  of different key/value store instances
* adapter software that loads and uses store-specific interface software
  provided by the libkv module itself or other modules
* a Ruby API for the store interface software that developers can implement
  to provide their own store interface
* a file-based store on the local filesystem and its interface software.

  * Future versions of this module will provide a distributed key/value store.


## Set up

### Terminolog

* backend - A specific key/value store, e.g., Consul, Etcd, Zookeeper, local
  files
* plugin - Ruby software that interfaces with a specific backend to
  affect the operations requested in libkv functions.
* plugin adapter - Ruby software that loads, selects, and executes the
  appropriate plugin software for a libkv function call.

### Configuration

, like consul or etcd. This library implements all the basic
key/value primitives, get, put, list, delete. It also exposes any 'check and
set' functionality the underlying store supports. This allows building of safe
atomic operations, to build complex distributed systems. This library supports
loading 'provider' modules that exist in other modules, and provides a first
class api.

libkv uses lookup to store authentication information. This information can
range from ssl client certificates, access tokens, or usernames and passwords.
It is exposed as a hash named libkv::auth, and will be merged by default. The
keys in the auth token are passed as is to the provider, and can vary between
providers. Please read the documentation on configuring 'libkv::auth' for each
provider

libkv currently supports the following providers:

* `mock` - Useful for testing, as it provides a kv store that is destroyed
           after each catalog compilation
* `consul` - Allows connectivity to an existing consul service

With the intention to support the following:
* `etcd` - Allows connectivity to an existing etcd service
* `simp6-legacy` - Implements the SIMP 6 legacy file storage api.
* `file` - Implements a non-HA flat file storage api.

This module is a component of the [System Integrity Management Platform](https://simp-project.com), a
compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug
tracker](https://simp-project.atlassian.net/).

## Usage

As an example, you can use the following to store hostnames, and then read all
the known hostnames from consul and generate a hosts file:

```puppet
libkv::put("/hosts/${facts['clientcert']}", $facts['ipaddress'])

$hosts = libkv::list('/hosts')
$hosts.each |$host, $ip | {
  host { $host:
    ip => $ip,
  }
}
```

Each key specified *must* contain only the following characters:
* a-z
* A-Z
* 0-9
* The following special characters: `._:-/`

Additionally, `/./` and `/../` are disallowed in all providers as key
components. The key name also *must* begin with `/`

When any libkv function is called, it will first call `lookup()` and attempt to
find a value for libkv::url from hiera. This url specifies the provider name,
the host, the port, and the path in the underlying store. For example:

```yaml
libkv::url: 'consul://127.0.0.1:8500/puppet'
libkv::url: 'consul+ssl://1.2.3.4:8501/puppet'
libkv::url: 'file://'
libkv::url: 'etcd://127.0.0.1:2380/puppet/%{environment}/'
libkv::url: 'consul://127.0.0.1:8500/puppet/%{trusted.extensions.pp_department}/%{environment}'
```

## Testing

Manual and automated tests require a shim to kick off Consul inside of Docker,
before running.  Travis is programmed to run the shim.  To do so manually,
first ensure you have [set up Docker](https://simp.readthedocs.io/en/stable/getting_started_guide/Installation_Options/ISO/ISO_Build/Environment_Preparation.html#set-up-docker) properly.

Next, run the shim:

```bash
$ ./prep_ci.sh
```

**NOTE**: There is a bug which will not allow the containers to deploy if
selinux is enforcing.  Set to permissive or disabled.

Run the unit tests:

```bash
$ bundle exec rake spec
```

## Function reference

<h3><a id="get">libkv::get</a></h3>

Connects to the backend and retrieves the data stored at **key**

`Any $data = libkv::get(String key)`

*Returns:* Any

*Usage:*

<pre lang="ruby">
 $database_server = libkv::get("/database/${facts['fqdn']}")
 class { 'wordpress':
   db_host => $database_server,
 }
</pre>


<h3><a id="put">libkv::put</a></h3>

Sets the data at `key` to the specified `value`

`Boolean $succeeded = libkv::put(String key, Any value)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
libkv::put("/hosts/${facts['fqdn']}", "${facts['ipaddress']}")
</pre>


<h3><a id="delete">libkv::delete</a></h3>

Deletes the specified `key`. Must be a single key

`Boolean $succeeded = libkv::delete(String key)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
$response = libkv::delete("/hosts/${facts['fqdn']}")
</pre>


<h3><a id="exists">libkv::exists</a></h3>

Returns true if `key` exists

`Boolean $exists = libkv::exists(String key)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
 if libkv::exists("/hosts/${facts['fqdn']}") {
   notify { "/hosts/${facts['fqdn']} exists": }
 }
</pre>


<h3><a id="list">libkv::list</a></h3>

Lists all keys in the folder named `key`

`Hash $list = libkv::list(String key)`

*Returns:* Hash

*Usage:*

<pre lang="ruby">
 $list = libkv::list('/hosts')
 $list.each |String $host, String $ip| {
   host { $host:
     ip => $ip,
   }
 }
</pre>


<h3><a id="deletetree">libkv::deletetree</a></h3>

Deletes the whole folder named `key`. This action is inherently unsafe.

`Boolean $succeeded = libkv::deletetree(String key)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
$response = libkv::deletetree('/hosts')
</pre>


<h3><a id="atomic_create">libkv::atomic_create</a></h3>

Store `value` in `key` atomically, but only if key does not already exist

`Boolean $succeeded = libkv::atomic_create(String key, Any value)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
 $id = rand(0,2048)
 $result = libkv::atomic_create("/serverids/${facts['fqdn']}", $id)
 if ($result == false) {
   $serverid = libkv::get("/serverids/${facts['fqdn']}")
 } else {
   $serverid = $id
 }
 notify("the server id of ${serverid} is idempotent!")
</pre>


<h3><a id="atomic_delete">libkv::atomic_delete</a></h3>

Delete `key`, but only if key still matches the value of `previous`

`Boolean $succeeded = libkv::atomic_delete(String key, Hash previous)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
 $previous = libkv::atomic_get("/env/${facts['fqdn']}")
 $result = libkv::atomic_delete("/env/${facts['fqdn']}", $previous)
</pre>


<h3><a id="atomic_get">libkv::atomic_get</a></h3>

Get the value of key, but return it in a hash suitable for use with other atomic functions

`Hash $previous = libkv::atomic_get(String key)`

*Returns:* Hash

*Usage:*

<pre lang="ruby">
 $previous = libkv::atomic_get("/env/${facts['fqdn']}")
 notify { "previous value is ${previous['value']}": }
</pre>


<h3><a id="atomic_put">libkv::atomic_put</a></h3>

Set `key` to `value`, but only if the key is still set to `previous`

`Boolean $succeeded = libkv::atomic_put(String key, Any value, Hash previous)`

*Returns:* Boolean

*Usage:*

<pre lang="ruby">
 $newvalue = 'new'
 $previous = libkv::atomic_get("/env/${facts['fqdn']}")
 $result = libkv::atomic_put("/env/${facts['fqdn']}", $newvalue, $previous)
 if ($result == true) {
   $real = $newvalue
 } else {
   $real = libkv::get("/env/${facts['fqdn']}")
 }
 notify { "I updated to ${real} atomically!": }
</pre>


<h3><a id="atomic_list">libkv::atomic_list</a></h3>

List all keys in folder `key`, but return them in a format suitable for other atomic functions

`Hash $list = libkv::atomic_list(String key)`

*Returns:* Hash

*Usage:*

<pre lang="ruby">
# Add a host resource for everything under /hosts

 $list = libkv::atomic_list('/hosts')
 $list.each |String $host, Hash $data| {
   host { $host:
     ip => $data['value'],
   }
 }
</pre>


<pre lang="ruby">
# For each host in /hosts, atomically update the value to 'newip'

 $list = libkv::atomic_list('/hosts')
 $list.each |String $host, Hash $data| {
   libkv::atomic_put("/hosts/${host}", 'newip', $data)
 }
</pre>


<h3><a id="empty_value">libkv::empty_value</a></h3>

Return an hash suitable for other atomic functions, that represents an empty value

`Hash $empty_value = libkv::empty_value()`

*Returns:* Hash

*Usage:*

<pre lang="ruby">
 $empty = libkv::empty()
 $result = libkv::atomic_get('/some/key')
 if ($result == $empty) {
   notify { "/some/key doesn't exist": }
 }
</pre>


<h3><a id="info">libkv::info</a></h3>

Return a hash of informtion on the underlying provider. Provider specific

`Hash $provider_information = libkv::info()`

*Returns:* Hash

*Usage:*

<pre lang="ruby">
 $info = libkv::info()
 notify { "libkv connection is: ${info}": }
</pre>


<h3><a id="supports">libkv::supports</a></h3>

Return an array of all supported functions

`Array $supported_functions = libkv::supports()`

*Returns:* Array

*Usage:*

<pre lang="ruby">
 $supports = libkv::supports()
 if ($supports in 'atomic_get') {
   libkv::atomic_get('/some/key')
 } else {
   libkv::get('/some/key')
 }
</pre>


<h3><a id="pop_error">libkv::pop_error</a></h3>

Return the error message for the last call

`String $error_string = libkv::pop_error()`

*Returns:* String

*Usage:*

<pre lang="ruby">
 unless libkv::put("/hosts/${facts['fqdn']}", "${facts['ipaddress']}") {
   $put_err_msg = libkv::pop_error()
   notify { "Setting /hosts/${facts['fqdn']} failed: ${put_err_msg}": }
 }
</pre>


<h3><a id="provider">libkv::provider</a></h3>

Return the name of the current provider

`String $provider_name = libkv::provider()`

*Returns:* String

*Usage:*

<pre lang="ruby">
 $provider = libkv::provider()
 notify { "libkv connection is: ${provider}": }
</pre>


#####################




## Module Description

Provides a Hiera-friendly interface to GRUB configuration activities.

Currently supports setting administrative GRUB passwords on both GRUB 2 and
legacy GRUB systems.

See [REFERENCE.md](REFERENCE.md) for more details.

## Setup

### What simp_grub affects

`simp_grub` helps manage the GRUB configuration on your systems.

## Usage

Simply ``include simp_grub`` and set the ``simp_grub::password`` parameter to
password protect GRUB.

Password entries that do not start with `$1$`, `$5$`, or `$6$` will be encrypted
for you.

### GRUB2

If your system supports GRUB2, you can also set up the administrative username.

Example: Set the admin username:

```yaml
---
simp_grub::admin: my_admin_username
```

## Limitations

SIMP Puppet modules are generally intended to be used on a Red Hat Enterprise
Linux-compatible distribution such as EL6 and EL7.

## Development

Please read our [Contribution Guide] (https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Unit tests

Unit tests, written in ``rspec-puppet`` can be run by calling:

```shell
bundle exec rake spec
```

### Acceptance tests

To run the system tests, you need [Vagrant](https://www.vagrantup.com/) installed. Then, run:

```shell
bundle exec rake beaker:suites
```

Some environment variables may be useful:

```shell
BEAKER_debug=true
BEAKER_provision=no
BEAKER_destroy=no
BEAKER_use_fixtures_dir_for_modules=yes
```

* `BEAKER_debug`: show the commands being run on the STU and their output.
* `BEAKER_destroy=no`: prevent the machine destruction after the tests finish so you can inspect the state.
* `BEAKER_provision=no`: prevent the machine from being recreated. This can save a lot of time while you're writing the tests.
* `BEAKER_use_fixtures_dir_for_modules=yes`: cause all module dependencies to be loaded from the `spec/fixtures/modules` directory, based on the contents of `.fixtures.yml`.  The contents of this directory are usually populated by `bundle exec rake spec_prep`.  This can be used to run acceptance tests to run on isolated networks.

