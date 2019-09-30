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
  * [Function Examples](#function-examples)
  * [Configuration](#configuration)
    * [Single backend configuration](#single-backend-configuration)
    * [Default hiearchy backend configuration](#default-hiearchy-backend-configuration)
    * [File plugin configuration](#file-plugin-configuration)
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
  provided by the libkv module itself and other modules
* a Ruby API for the store interface software that developers can implement
  to provide their own store interface
* a file-based store on the local filesystem and its interface software.

  * Future versions of this module will provide a distributed key/value store.


If you find any issues, they may be submitted to our
[bug tracker](https://simp-project.atlassian.net/).

## Terminology

The following terminology will be used throughout this document:

* backend - A specific key/value store, e.g., Consul, Etcd, Zookeeper, local
  files
* plugin - Ruby software that interfaces with a specific backend to
  affect the operations requested in libkv functions.
* plugin instance - Instance of the plugin that handles a unique backend
  configuration.
* plugin adapter - Ruby software that loads, selects, and executes the
  appropriate plugin software for a libkv function call.

## Usage

Using `libkv` is simple:

* Use `libkv` functions to store and retrieve key/value pairs in your
  Puppet code.
* Configure the backend(s) to use in Hieradata.
* Reconfigure the backend(s) in Hieradata, as your needs change.  No changes
  to your Puppet code will be required.

### Function Examples

Here are a few examples of using the `libkv` functions.

Example: Store and retrieve host information

Store a node's hostname and IP address:

```puppet
libkv::put("hosts/${facts['clientcert']}", $facts['ipaddress'])
```

Create a hosts file using the list of stored host information:

```puppet
$hosts = libkv::list('hosts')
$hosts.each |$host, $ip | {
  host { $host:
    ip => $ip,
  }
}
```

### Configuration

The backend configuration of `libkv` can be as simple as you want (one backend)
or complex (multiple backends with defaults for specific classes, defined type
instances or defined types).  Let's start with the simple configuration to
illustrate key configuration.

#### Single backend configuration

For this example, we are going to illustrate use of only one backend configuration
with libkv's file plugin:


#### Default hierachy backend configuration

#### File plugin configuration

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
automatically loaded by the libkv adapter with each Puppet compile.

### Implementing the Store Interface API

To create your own plugin

* Create a `lib/puppet_x/libkv` directory within your store plugin module.
* Copy `lib/puppet_x/libkv/plugin_template.rb` from the libkv modules into that
  directory with a name `<your plugin name>_plugin.rb`.  For example,
  `nfs_file_plugin.rb`.
* **READ** all the documentation in your plugin skeleton, paying close attention
  the `IMPORTANT NOTES` discussion.
* Implement the body of each method as identified by a `FIXME`. Be sure to conform
  to the API for the method.
* Write unit tests for your plugin, using the unit tests for libkv's
  file plugin, `spec/unit/puppet_x/libkv/file_plugin_spec.rb` as an example.
  That test shows you how to instantiate an object of your plugin for
  testing purpose.
* Write acceptance tests for your plugin, using the acceptance tests
  for libkv's file plugin, `spec/acceptances/suites/default/file_plugin_spec.rb`,
  as an example.  That test uses a test module, `spec/support/libkv_test` that
  exercises the the libkv API.

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

