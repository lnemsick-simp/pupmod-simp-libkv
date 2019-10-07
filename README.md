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
* [Terminology](#terminology)
* [Usage](#usage)
  * [Single Backend Example](#single-backend-example)
  * [Multiple Backends Example](#multiple-backends-example)
  * [Binary Value Example](#binary-value-example)
  * [Auto-Default Backend](#auto-default-backend)
  * [libkv Configuration Reference](#libkv-configuration-reference)
* [File Store and Plugin](#file-store-and-plugin)
* [Limitations](#limitations)
* [Plugin Development](#plugin-development)
  * [Plugin Loading](#plugin-loading)
  * [Implementing the Store Interface API](#implementing-the-store-interface-api)
* [libkv Development](#libkv-development)
  * [Unit tests](#unit-tests)
  * [Acceptance tests](#acceptance-tests)

<!-- vim-markdown-toc GFM -->

## Overview

## This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, please submit them via [JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

## Module Description

Provides an abstract library that allows Puppet to access one or more key/value
stores.

This module provides

* a standard Puppet language API (functions) for using key/value stores

  * The API is modeled after https://github.com/docker/libkv#interface.
  * See [REFERENCE.md](REFERENCE.md) for more details on the available
    functions.

* a configuration scheme that allows users to specify per-application use
  of different key/value store instances
* adapter software that loads and uses store-specific interface software
  provided by the libkv module itself and other modules
* a Ruby API for the store interface software that developers can implement
  to provide their own store interface
* a file-based store on the local filesystem and its interface software.

  * Future versions of this module will provide a distributed key/value store.

If you find any issues, they may be submitted to our
[bug tracker](https://simp-project.atlassian.net/).

## Terminology

The following terminology will be used throughout this document:

* backend - A specific key/value store, e.g., files on a local filesystem,
  Consul, Etcd, Zookeeper
* plugin - Ruby software that interfaces with a specific backend to
  affect the operations requested in libkv Puppet functions.
* plugin instance - Instance of the plugin that handles a unique backend
  configuration.
* plugin adapter - Ruby software that loads, selects, and executes the
  appropriate plugin software for a libkv function call.

## Usage

Using `libkv` is simple:

* Use `libkv` functions to store and retrieve key/value pairs in your Puppet
  code.
* Configure the backend(s) to use in Hieradata.
* Reconfigure the backend(s) in Hieradata, as your needs change.  No changes
  to your Puppet code will be required.

The backend configuration of `libkv` can be as simple as you want (one backend)
or complex (multiple backends servicing different applications).  Examples of
both scenarios will be shown in this section, along with a configuration
reference.

### Single Backend Example

This example will store and retrieve host information using libkv function
signatures that assume the default backend and hieradata that only configures
the default backend.

To store a node's hostname and IP address:

```puppet
libkv::put("hosts/${facts['clientcert']}", $facts['ipaddress'])
```

To create a hosts file using the list of stored host information:

```puppet
$hosts = libkv::list('hosts')
$hosts.each |$host, $info | {
  host { $host:
    ip => $info['value'],
  }
}
```

In hieradata, configure the default backend in the ``libkv::options`` Hash.  This
example, will configure libkv's file backend.

```yaml
libkv::options:

  # Hash of backend configurations.
  # - We have only the required 'default' entry which will apply to
  #   all libkv calls.
  backends:
    default:
      # This is the advertised type for libkv's file plugin.
      type: file
      # This is a unique id for this configuration of the 'file' plugin.
      id: file

      # plugin-specific configuration
      root_path: "/var/simp/libkv/file"
      lock_timeout_seconds: 30
```

### Multiple Backends Example

This example will store and retrieve host information using libkv function
signatures that request a backend based on an application id and multi-backend
hieradata that supports the request.  The function signatures and hieradata are
a little more complicated, but still relatively straightforward to understand.

To store a node's hostname and IP address using the backend servicing `myapp1`:

```puppet
$libkv_options = { 'app_id' => 'myapp1' }
$empty_metadata = {}
libkv::put("hosts/${facts['clientcert']}", $facts['ipaddress'], $empty_metadata, $libkv_options)
```

To create a hosts file using the list of stored host information using the
backend servicing `myapp1`:

```puppet
$libkv_options = { 'app_id' => 'myapp1' }
$hosts = libkv::list('hosts', $libkv_options)
$hosts.each |$host, $info | {
  host { $host:
    ip => $info['value'],
  }
}
```

In hieradata, configure multiple backends in the ``libkv::options`` Hash.
This example will configure multiple instances of libkv's file backend.

```yaml
# The backend configurations here will be inserted into libkv::options
# below via the alias function.

libkv::backend::file_default:
  type: file
  id: default
  root_path: "/var/simp/libkv/file"

libkv::backend::file_myapp:
  type: file
  id: myapp
  root_path: "/path/to/myapp"

libkv::backend::file_yourapp:
  type: file
  id: yourapp
  root_path: "/path/to/yourapp"


libkv::options:
  # Hash of backend configurations.
  # * Includes application-specific backends and the required default backend.
  # * libkv will use the appropriate backend for each libkv function call.
  backends:
    # backend for specific myapp application
    "myapp_special_snowflake": "%{alias('libkv::backend::file_default')}"

    # backend for remaining myapp* applications, including myapp1
    "myapp":                   "%{alias('libkv::backend::file_myapp')}"

    # backend for all yourapp* applications
    "yourapp":                 "%{alias('libkv::backend::file_yourapp')}"

    # required default backend
    "default":                 "%{alias('libkv::backend::file_default')}"
```

In this example, we are setting the application identifier to `myapp1` in
our libkv function calls.  libkv selects `myapp` as the backend to use for
`myapp1` using the following simple search algorithm:

* First, it looks for a backend named for the application id.
* Next, it looks for the longest backend name matching the start of the
  application id.
* Finally, if no match is found, it defaults to a backend named `default`.

### Binary Value Example

libkv is able to store and retrieve binary values, provided the Puppet code
uses the appropriate configuration and functions/types for binary data.

  * **IMPORTANT**:  In Puppet 5, be sure to turn on `--rich_data` for both the
    master and agent in order to ensure correct serialization/deserialization
    of the `Binary` Puppet type.

Below is an example of using libkv for a binary value.

To store the content of a generated keytab file:

```puppet
# Load in the binary content from a file.  Returns a Binary Puppet type.
$original_binary_content = binary_file('/path/to/keytabs/app.keytab')

# Set a key/value pair with the binary content
libkv::put('app/keytab', $original_binary_content)
```

To retrieve the keytab binary content and use it in a `file` resource:

```puppet
# Retrieve a binary value from a key/value store and set a Binary variable
$retrieved_result = libkv::get('app/keytab')
$retrieved_binary_content = Binary.new($retrieved_result['value'], '%r')

# Persist binary data to another file
file { '/different/path/to/keytabs/app.keytab':
  content => $retrieved_binary_content
}

```

### Auto-Default Backend

libkv is intended to be configured via ``libkv::options`` and any
application-specific configuration passed to the libkv Puppet functions.
However, to facilitate rollout of libkv capabilities, (specifically
use of libkv internally in ``simplib::passgen``), when ``libkv::options``
is not set in hieradata, libkv will automatically use the libkv file store with
the configuration that is equivalent to the following hieradata:

```yaml
libkv::options:
  environment: "%{server_facts.environment}"
  softfail: false
  backend: default
  backends:
    default:
      type: file
      id: auto_default
```

### libkv Configuration Reference

The libkv configuration used for each libkv function call is comprised of
a merge of a function-provided options Hash, Hiera configuration specified
by the `libkv::options` Hash, and global configuration defaults.  The merge
is executed in a fashion to ensure the function-provided options take
precedence over the `libkv::options` Hiera values.

The merged libkv configuration contains global and backend-specific
configurations, along with an optional application identifier. The primary
keys in this Hash are as follows:

* `app_id`: Optional String in libkv function calls, only. Specifies an
  application name that can be used to identify which backend configuration
  to use via fuzzy name matching, in the absence of the `backend` option.
  (See [Backend Selection](#backend-selection)).

  * More flexible option than `backend`.
  * Useful for grouping together libkv function calls found in different
    catalog resources.

* `backend`: Optional String. Specifies a definitive backend configuration
  to use.

  * Takes precedence over `app_id`.
  * When present, must match a key in `backends` and will be used unequivocally.

    * If that backend does not exist in `backends`, the libkv function will fail.

  * When absent, the backend configuration will be selected from the set of
    entries in `backends`, using the `app_id` option if specified.
    (See [Backend Selection](#backend-selection)).

* `backends`: Required Hash. Specifies backend configurations.  Each key
  is the name of a backend configuration and its value contains the
  corresponding configuration Hash.

  * Each key is a String.
  * Must include a 'default' key.
  * More than one key can use the same backend configuration.
  * See [Backend Configuration Entries](#backend-configuration-entries)
    for more details about a backend configuration Hash.

* `environment`: Optional String.  Puppet environment to prepend to keys.

  * When set to a non-empty string, it is prepended to the key or key folder
    used in a backend operation.
  * Should only be set to an empty string when the key being accessed is truly
    global.
  * Defaults to the Puppet environment for the node when absent.

* `softfail`: Optional Boolean. Whether to ignore libkv operation failures.

  * When `true`, each libkv function will return a result object even when the
    operation failed at the backend.
  * When `false`, each libkv function will fail when the backend operation
    failed.
  * Defaults to `false` when absent.

#### Backend Configuration Entries

Each backend configuration entry in `backends` is a Hash.  The Hash must
contain `type` and `id` keys, where the (`type`,`id`) pair defines a unique
configuration.

* `type` must be unique across all backend plugins, including those
  provided by other modules.
* `id` must be unique for a each distinct configuration for a `type`.
* Other keys for configuration specific to the backend may also be present.

#### Backend Selection

The backend to use for a libkv Puppet function call will be determined from
the merged libkv options Hash as follows:

* If a specific backend is requested via the `backend` key in the merged libkv
  options Hash, that backend will be selected.

  * If that backend does not exist in `backends`, the libkv function will fail.

* Otherwise, if an `app_id` option is specified in the merged libkv options
  Hash and it matches a key in the `backends` Hash, exactly, that backend will
  be selected.
* Otherwise, if an `app_id` option is specified in the merged libkv options
  Hash and it starts with the key in the `backends` Hash, that backend will be
  selected.

  * When multiple backends satisfy the 'start with' match, the backend with the
    most matching characters is selected.

* Otherwise, if the `app_id` option does not match any key in in the `backends`
  Hash or is not present, the `default` backend will be selected.

## File Store and Plugin

libkv provides a file-based key/value store and its plugin.  This file store
maintains individual key files on a local filesystem, has a backend type `file`,
and supports the following plugin-specific configuration parameters.

* `root_path`: Root directory path for the key files

  * Defaults to `/var/simp/libkv/file/<id>` when that directory can be created
    or '<Puppet[:vardir]>/simp/libkv/<name>' otherwise.

* `lock_timeout_seconds`: Maximum number of seconds to wait for an exclusive
  file lock on a file modifying operation before failing the operation.

  * Defaults to 5 seconds.

## Limitations

* SIMP Puppet modules are generally intended to be used on a Red Hat Enterprise
  Linux-compatible distribution such as EL6 and EL7.

* libkv's file plugin is only guaranteed to work on local filesystems.  It may not
  work on shared filesystems, such as NFS.

* `libkv` only supports the use of binary data for the value when that data is
   a Puppet `Binary`. It does not support binary data which is a sub-element of
   a more complex value type (e.g.  `Array[Binary]` or `Hash` that has a key or
   value that is a `Binary`).

## Plugin Development

### Plugin Loading

Each plugin (store interface) is written in pure Ruby and, to prevent
cross-environment contamination, is implemented as an anonymous class
that is automatically loaded by the libkv adapter with each Puppet compile.
You do not have to do anything special to have your plugin loaded, provided
you follow the instructions in the next section.

### Implementing the Store Interface API

To create your own plugin

* Create a `lib/puppet_x/libkv` directory within your store plugin module.
* Copy `lib/puppet_x/libkv/plugin_template.rb` from the libkv module into that
  directory with a name `<your plugin name>_plugin.rb`.  For example,
  `nfs_file_plugin.rb`.
* **READ** all the documentation in your plugin skeleton, paying close attention
  the `IMPORTANT NOTES` discussion.
* Implement the body of each method as identified by a `FIXME`. Be sure to
  conform to the API for the method.
* Write unit tests for your plugin, using the unit tests for libkv's file
  plugin, `spec/unit/puppet_x/libkv/file_plugin_spec.rb` as an example.  That
  test shows you how to instantiate an object of your plugin for testing
  purposes.
* Write acceptance tests for your plugin, using the acceptance tests for
  libkv's file plugin, `spec/acceptances/suites/default/file_plugin_spec.rb`,
  as an example.  That test uses a test module, `spec/support/libkv_test` to
  exercise the the libkv API and verify its operation.
* Document your plugin's type and configuration parameters in the README.md for
  your store plugin module.

## libkv Development

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

