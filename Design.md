#### Table of Contents

* [Terminology](#terminology)
* [Scope]
* [libkv Requirements](#libkv-requirements)

  * [Minimum Requirements](#minimum-requirements)

    * [libkv Puppet-Function Interface](#libkv-puppet-function-interface)
    * [libkv Backend Interface](#libkv-backend-interface)
    * [libkv Configuration](#libkv-configuration)
    * [libkv-Provided Plugins](#libkv-configuration)

  * [Future Requirements](#future-requirements)

* [libkv Rollout Plan](#libkv-rollout-plan)

* [libkv Function API](#libkv-function-api)

  * [Overview](#FIXME)
  * [Functions](#FIXME)

* [libkv Plugin API](#libkv-plugin-API)
  * Overview
    * libkv adapter responsibilities
    * libkv plugin responsibilities

## Terminology

* libkv - Module that provides an interface to one or more key/value stores
  and a file-based key/value store.  The interface is comprised of

  * Puppet functions implemented in Ruby function API.
  * Adapter software that provides a mechanism for loading and executing
    key/value store interface software.

* backend - A specific key/value store, e.g., Consul, Etcd, Zookeeper.
* plugin - Pure Ruby software that interfaces with a specific backend to
  affect the operations requested in libkv functions.

  * AKA provider.  Plugin will be used throughout this document to avoid
    confusion with Puppet types and providers.

* plugin adapter - Pure Ruby software that loads, selects, and executes
  the appropriate plugin software for a libkv function at runtime.

## Scope

This document describes design information for the second libkv prototype
(version 0.7.0).  Major design/API changes since version 0.6.x are as follows:

* Simplified the libkv function API to be more appropriate for end users.

  * Atomic functions and their helpers have been removed.  The software
    communicating with a specific key/value store is assumed to affect atomic
    operations in a manner appropriate for that backend.
  * Each function that had a '_v1' signature (dispatch) has been rewritten to
    combine the single Hash parameter signature and the '_v1' signature.  The
    new signature has all required parameters plus an optional Hash.  This
    change makes the required parameters explicit to the end user (e.g.,
    a `put` operation requires a `key` and a `value`) and leverages parameter
    validation provided natively by Puppet.

* Redesigned global Hiera configuration to support more complex libkv deployment
  scenarios.  The limited libkv Hiera configuration, `libkv::url` and
  `libkv::auth`, has been replace with a Hash `libkv::options`, that allows
  users to specify the following:

  * global libkv options
  * any number of backends along with configuration specific to each
  * which backend is to be used by default
  * which backend to use for specific catalog resources (e.g., specific
    Classes, all Defines of a specific type, specific Defines).

* Standardized error handling

  * Each backend plugin operation corresponding to a libkv function must
    return a results Hash in lieu of raising an exception.
  * The plugin adapter must catch any exceptions not handled by the plugin
    software and convert to a failed-operation results Hash.  This includes
    failure to load the plugin software (e.g., if an externally-provided
    plugin has malformed Ruby.)
  * Each libkv function must raise an exception with the error message
    provided by the failed-operation results Hash, by default.  When
    configured to 'softfail', instead, each function must log the error
    message and return an appropriate failed value.


## libkv Requirements

### Minimum Requirements

#### libkv Puppet-Function Interface

libkv must provide a Puppet-function interface that Puppet code can use to access
a key/value store.

* The interface must provide basic key/value operations (e.g., `put`, `get`,
  `list`, `delete`).

  * Each operation must be a unique function in the `libkv` namespace.
  * Keys must be `Strings` that can be used for directory paths.

  * A key must contain only the following characters:
      * a-z
      * A-Z
      * 0-9
      * The following special characters: `._:-/`
    * A key must not contain '/./' or '/../' sequences.

  * Values must be any type that is not `Undef` (`nil`).

* The interface must support the use of one or more backends.

  * Each function must allow the user to optionally specify the backend
    to use and its configuration options at runtime.
  * When the backend information is not specified, each function must
    look up the information in Hieradata at runtime.

* The plugin for each backend must support all the operations in this
  interface.

  * Writing Puppet code is difficult otherwise!
  * Mapping of the interface to the actual backend operations is up to
    the discretion of the plugin.

* The interface must automatically prepend the Puppet environment to each key,
  by default, but provide a mechanism to disable this operation via libkv
  configuration.

  Example: `libkv::put('mykey', 'some value')` in the `production`
  environment would transform `'mykey'` to `'production/mykey'`,
  before sending the request to the appropriate backend plugin.

* The interface must allow additional metadata in the form of a Hash to
  be persisted/retrieved with the key-value pair.

#### libkv Backend Interface

libkv must provide a backend interface (plugin) API, a mechanism for
loading plugin code, a mechanism for instantiating plugin objects and
persisting them through the lifetime of a catalog instance, and a mechanism
to use these objects to implement the Puppet-function interface.

FIXME: plugin adapter discussion looks like a mix of design and requirements
* The plugin adapter is responsible for managing and using plugin code.

  * It must be be written in pure Ruby.
  * It must be loaded and constructed in a way that prevents
    cross-environment contamination.
  * It must load plugin software in a way that prevents cross-environment
    contamination.
  * An instance of it must be maintained over the lifetime of a catalog instance.
  * It must construct plugin objects and retain them through the life of
    a catalog instance.
  * It must select the appropriate plugin object to use for each function call.
  * It must serialize data to be persisted into a common format and
    then deserialize upon retrieval.

    * Transformation done only in one place, instead of in each plugin (DRY).
    * Prevents value objects from being modified by plugin function code.
      This is especially of concern of complex Hash objects, for which
      there is no deep copy mechanism.  (`Hash.dup` does *not* deep copy!)

  * It must safely handle unexpected plugin failures, including failures to
    load (e.g., malformed Ruby).

* Any module may provide a libkv plugin.
* All plugins must be written in pure Ruby.

  * This allows stateful objects with a lifetime corresponding to that of
    a catalog instance to be created. For plugins that maintain a connection
    with a key/value service, this is more efficient.

* All plugin code must be able to be loaded in a fashion that prevents
  cross-environment code contamination, when loaded in the puppetserver.

  * This requires dynamically loaded classes that are either anonymous or
    that contain generated class names.  Both options result in necessarily
    fugly code.

* All plugins must conform to the plugin API.
* All plugins must be uniquely named.
* The plugin API must provide:

  * Details on the code structure required for prevention of cross-environment
    contamination-free
  * Description of any universal plugin options that must be supported
  * Ability to specify plugin-specific options
  * Public API method signatures, including the constructor
  * Explicit policy on error handling (how to report errors, what information
    the messages should contain for plugin proper identification, whether
    exceptions are allowed)
  * Documentation requirements
  * Testing requirements

#### libkv Configuration

* Users must be able to specify the following in Hiera (see example):

  * global libkv options
  * any number of backends along with configuration specific to each
  * which backend is to be used by default
  * which backend to use for specific catalog resources (e.g., specific
    Classes, all Defines of a specific type, specific Defines).

* Users must be able to specify the backend to use and some or all of its
  configuration with options specified in individual libkv Puppet function
  calls.
* The libkv options in individual libkv Puppet function calls take precedence
  over those specified in Hiera.


Example libkv Hiera configuration:

```yaml

  libkv::backend::consul:
    # id is a required key and must be unique across all backend configurations
    id: consul

    # plugin is a required key and must be unique across all backend plugins.
    # However, the same plugin may be used for multiple backend configurations.
    plugin: consul

    request_timeout_seconds: 15
    num_retries: 1
    uris:
    - 'consul+ssl+verify://1.2.3.4:8501/puppet'
    - 'consul+ssl+verify://1.2.3.5:8501/puppet'
    auth:
      ca_file:    "/path/to/ca.crt"
      cert_file:  "/path/to/server.crt"
      key_file:   "/path/to/server.key"

  libkv::backend::file:
     id: file
     plugin: file
     root_path: "/var/simp/libkv/file"

  libkv::backend::alt_file:
     id: alt_file
     plugin: file
     root_path: "/some/other/path"

  # Hash of backend configuration to be used to lookup the appropriate backend
  # to use in libkv functions.  Each function has an optional options Hash
  # parameter that will be deep merged with this Hash.  If the merged Hash
  # contains the key 'backend', it will specify which backend to use in the
  # 'backends' sub-Hash below.  If the merged Hash does not contain the
  # 'backend' key, the libkv function  will look for a backend whose name
  # matches the calling Class, specific Define, or Define type.  If no
  # match is found, it will use the 'default' backend.
  libkv::options:
    # global options
    environment: "%{server_facts.environment}"
    softfail: false

    # Hash of backend configurations.
    # ***Must contain a default entry***
    backends:
      default:                        "%{alias('libkv::backend::file')}"

      #  pki Class resource
      'default.Class[Pki]':           "%{alias('libkv::backend::consul')}"

      # all mydefine Define resources not fully specified
      'default.Mydefine':             "%{alias('libkv::backend::alt_file')}"

      # 'myinstance' mydefine Define resource
      'default.Mydefine[Myinstance]': "%{alias('libkv::backend::consul')}"

      consul:                         "%{alias('libkv::backend::consul')}"
      file:                           "%{alias('libkv::backend::file')}"
      alt_file:                       "%{alias('libkv::backend::alt_file')}"

```


#### libkv-Provided Plugins

* libkv must provide a String-only, file-based plugin that can be used for
  `simplib::passgen()` passwords currently stored in the puppetserver cache
  directory, PKI secrets currently stored in `/var/simp/environments`, and
  Kerberos secrets stored in `/var/simp/environments`.

    * This plugin is sometimes referred to as a legacy plugin.
    * For each key/value pair, the plugin must write to/read from a unique
      file for that pair on the local file system (i.e., file on the
      puppetserver host).

      * The root path for files defaults to `/var/simp/libkv/file_string_only`.
      * The key specifies the path relative to the root path.
      * The plugin must create the directory tree, when it is absent.
      * *External* code must make sure the puppet user has appropriate access
        to root path.
      * Having each file contain a single key allows easy auditing of
        creation, access, and modification to individual keys.

    * The plugin must write a String value exactly as is to file in the `put`
      operation, and then properly restore it in the `get` and `list`
      operations.

      * The plugin must handle string values with binary content.
      * Any metadata specified in the `put` request will be discarded and
        not available in a `get` or `list` request.

    * For plugin `put`, `get`, and `list` operations for any values that are
      not of type String the plugin behavior is unspecified.

      * The user should use a different plugin if they want to store generic
        objects.

    * The plugin `put`, `delete`, and `deletetree` operations must be
      multi-process safe on a local file system.

    * The plugin `put`, `delete`, and `deletetree` operations may be
      multi-process safe on shared file systems, such as NFS.

      * Getting this to work on specific shared filesystem types is
        deferred to future requirements.

* libkv must provide a generic file-based plugin

    * For each key/value pair, the plugin must write to/read from a unique
      file for that pair on the local file system (i.e., file on the puppetserver
      host).

      * The root path for files defaults to `/var/simp/libkv/file`.
      * The key specifies the path relative to the root path.
      * The plugin must create the directory tree, when it is absent.
      * *External* code must make sure the puppet user has appropriate access
        to root path.
      * Having each file contain a single key allows easy auditing of
        creation, access, and modification to individual keys.

    * The plugin must write a JSON representation of the value and optional
      metadata to file in the `put` operation, and then properly restore the
      value and metadata in the `get` and `list` operations.

      * The plugin must handle string values with binary content.
      * This *ASSUMES* all the types within Puppet are built upon primitives for
        which a meaningful `.to_json` method exists.
      * Although JSON is not a compact/efficient representation, it is
        universally parsable.

    * The plugin `put`, `delete`, and `deletetree` operations must be
      multi-process safe on a local file system.

    * The plugin `put`, `delete`, and `deletetree` operations may be
      multi-process safe on shared file systems, such as NFS.

      * Getting this to work on specific shared filesystem types is
        deferred to future requirements.

### Future Requirements

This is a placeholder for additional libkv requirements which will be
addressed, once it moves beyond the prototype stage.

* libkv must support audit operations on the key/value store

  * Auditing information to be provided must include:

    * when the key was created
    * last time the key was accessed
    * last time a value was modified

  * Auditing information to be provided may include the full history
    of changes to a key/value pair, including deleted keys.

  * Auditor must be restricted to view auditing metadata, only.

    * Auditor must never have access to secrets stored in the key/value store.

* libkv should provide a mechanism to detect and purge stale keys.
* libkv should provide a script to import existing
  `simplib::passgen()` passwords stored in the puppetserver cache
  directory, PKI secrets stored in `/var/simp/environments`, and Kerberos secrets
  stored in `/var/simp/environments` to the libkv local file backend.
* libkv local file backend must encrypt each file it maintains.
* libkv local file backend must ensure multi-process-safe `put`,
  `delete`, and `deletetree` operations on a <insert shared filesystem
   du jour> file system.

## libkv Rollout Plan

Understanding how the libkv functionality will be rolled out to
replace functionality in `simplib::passgen()``, the `pki`
Class, and the `krb5` Class informs the design.  To that end, this
section describes the expected rollout for each replacement.

### simplib::passgen() conversion to libkv

The key/value store operation of `simplib::passgen()` is completely
internal to that function and can be rewritten to use libkv with minimal
user impact.

* Existing password files (including their backup files), need to be imported
  from the puppetserver cache directory into the appropriate backend.

  * May want to provide a migration script that is run automatically upon
    install of an appropriate SIMP RPM.
  * May want to provide an internal auto-migration capability (i.e., built
    into `simplib::passgen()`) that keeps track of keys that have been migrated
    and imports any stragglers that may appear if a user manually creates
    old-style files for them.

* `simp passgen` must be changed to use the libkv Puppet code for its
  operation.

  * May want to simply execute `puppet apply` and parse the results.  This
    will be signficantly easier than trying to use the anonymous or
    environment-namespaced classes of the plugins and mimicking Hiera
    lookups!

### pki and krb5 Class conversions to libkv

Conversions of the `pki` and `krb5` Classes to use libkv entails switching
from using `File` resources with the `source` set to `File` resources with
`content` set to the output of `libkv::get(xxx)``.

* `krb5` keytabs are binary data which may require use of Puppet Binary()
  operations.

  * TODO Understand how get binary data persisted in a `File` resource.
    `Binary` and `binary_file` are supposed to facilitate that, but
    they have bugs and the fixes may not be in Puppet 5.  See regression
    discussion and the end of tickets.puppetlabs.com/browse/PUP-3600.
    and tickets.pupopetlabs.com/browse/PUP-9110

* It may make sense to allow users to opt into these changes with a new
  `libkv` class parameter.
* It may be worthwhile to have a `simp_options::libkv` parameter to enable
  use of libkv wherever it is used in SIMP modules.
* May want to provide a migration script that users can run to import existing
  secrets into the key/value store prior to enabling this option.

## libkv Function API

### Overview

libkv Puppet functions provide access to a key/value store from an end-user
perspective.  This means the API provides simple operations and does not
expose the complexities of concurrency.  So, a manifest simply calls functions
which, by default, either work or fail. No complex logic needs to be built into
a manifest.

For cases in which it may be appropriate for a manifest to handle error cases,
itself, instead of failing a catalog compilation, the libkv Puppet function API
does allow each function to be executed in a `softfail` mode.  The `softfail`
mode can also be set globally for a specific backend.  When `softfail` mode is
enabled, each function will return a result object that indicates whether the
operation succeeded, and, for retrieval operations, an appropriate null/empty
value.

This simple API only works if the complexity of key/value modifying operations
is pushed to the backend plugins.

  * The plugins are expected to provide atomic key-modifying operations
    automatically, wherever possible, using backend-specific lock/or
    atomic operations mechanisms.
  * A plugin may choose to cache data for key quering operations, keeping
    in mind each plugin instance only remains active for the duration of the
    catalog instance (compile).
  * Each plugin may choose to offer a retry option, to minimize failed catalog
    compiles when connectivity to its remote backend is spotty.

### libkv Options Configuration

Each libkv Puppet function will have an optional `options` Hash parameter.
This parameter can be used to specify global libkv options and/or the specific
backend to use (with or without backend-specific configuration).  This Hash
will be merged with the configuration found in the `libkv::options`` Hiera
entry.

The standard options available are as follows:

* `softfail`: Boolean.  When set to `true`, each function will return a results
  oject that indicates whether the operation succeeded, and, for retrieval
  operations, an appropriate null/empty object in lieu of failing.  The default
  is `false`.
* `environment`: String. When set to a non-empty string, the value is prepended
  to the `key` parameter.  Should only be set to an empty string when the key
  being accessed is truly global.  Defaults to the Puppet environment for the
  agent.
* `backend`: String.  Name of the backend in the 'backends' sub-Hash of
  the merged options Hash.  When absent, the libkv function will look for
  a backend whose name matches the calling Class, specific Define, or Define
  type.  If no match is found, it will use the 'default' backend.

TODO:  examples using the configuration example in
[libkv Configuration](#libkv-configuration)

* In `myclass` class manifest:

  ```ruby

    result = libkv::get('key', { 'softfail' => true })

  ```

  The function call will use the  backend configuration from
  `libkb::options['backends']['default']`.  This is resolves to
  `libkv::backend::file`.

* In `pki` class manifest:

  ```ruby

    result = libkv::get('key')
  ```

  The function call will use the  backend configuration from
  `libkb::options['backends']['default.Class[Pki]']`.  This is resolves to
  `libkv::backend::consul`.

* TODO Define examples

### Functions

* libkv::put: Sets the data at `key` to a `value` in the configured backend.
* libkv::get: Retrieves the data stored at `key` from the configured backend.
* libkv::delete: Deletes a `key` from the configured backend.
* libkv::exists: Returns whether the `key` exists in the configured backend.
* libkv::list: Returns a list of all keys in a folder.
* libkv::deletetree: Deletes the whole folder named `key` from the configured
  backend.


## libkv Plugins

Overview
* The plugin adapter is responsible for managing and using plugin code.
  It must

  * Load plugins
  * Serialize data to be persisted into a common format and then deserialize
    upon retrieval.
  * Safely handle unexpected plugin failures.

-------------------------------------------------------------------
ORIGINAL README CONTENT

libkv is an abstract library that allows puppet to access a distributed key
value store, like consul or etcd. This library implements all the basic
key/value primitives, get, put, list, delete. It also exposes any 'check and
set' functionality the underlying store supports. 
This library supports
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


`Any $data = libkv::get(String key)`

*Returns:* Any

*Usage:*

<pre lang="ruby">
 $database_server = libkv::get("/database/${facts['fqdn']}")
 class { 'wordpress':
   db_host => $database_server,
 }
</pre>


<h3><a id="delete">libkv::delete</a></h3>

