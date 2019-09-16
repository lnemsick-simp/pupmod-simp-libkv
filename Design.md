#### Table of Contents

* [Terminology](#terminology)
* [Scope](#scope)
* [Requirements](#requirements)

  * [Minimum Requirements](#minimum-requirements)

    * [Puppet Function API](#puppet-function-api)
    * [Backend Plugin Adapter](#backend-plugin-adapter)
    * [Backend Plugin API](#backend-plugin-api)
    * [Configuration](#configuration)
    * [libkv-Provided Plugins and Stores](#libkv-provided-plugins-and-stores)

  * [Future Requirements](#future-requirements)

* [Rollout Considerations](#rollout-considerations)
* [Design](#design)

  * [Changes from Version 0.6.X](#changes-from-version-0.6.x)
  * [libkv Puppet Functions](#libkv-puppet-functions)

    * [Overview](#Overview)
    * [Common Function Options](#common-functions-options)
    * [Functions Signatures](#functions-signatures)

  * [Plugin AAPI](#libkv-plugin-API)
  * [Plugin API](#libkv-plugin-API)
  * Overview
    * libkv adapter responsibilities
    * libkv plugin responsibilities

## Terminology

* libkv - SIMP module that provides

  * a standard Puppet language API (functions) for using key/value stores
  * adapter software that loads and uses store-specific interface software
  * a Ruby API for the store interface software
  * interface software to a few specific stores (file-based store to start)
  * a file-based store

* backend - A specific key/value store, e.g., Consul, Etcd, Zookeeper, local
  files
* plugin - Ruby software that interfaces with a specific backend to
  affect the operations requested in libkv functions.

  * AKA provider.  Plugin will be used throughout this document to avoid
    confusion with Puppet types and providers.

* plugin adapter - Ruby software that loads, selects, and executes the
  appropriate plugin software for a libkv function call.

## Scope

This documents libkv requirements, roll out considerations, and a
second-iteration, protoype design to meet those requirements.

## Requirements

### Minimum Requirements

#### Puppet Function API

libkv must provide a Puppet function API that Puppet code can use to access
a key/value store.

* The API must provide basic key/value operations via Puppet functions

  * The operations required are

    * `put`
    * `get`
    * `delete`
    * `list`
    * `deletetree`

  * Each operation must be fully supported by each backend.
  * Each key-modifying operation is assumed to be implemented atomically
    via each plugin backend.

    * Complexity of atomic operations has been pushed to each backend plugin
      because that is where the complexity belongs, not in Puppet code.  Each
      backend plugin will use the appropriate mechanisms provided natively by
      its backend (e.g., locking, atomic methods), thereby optimizing
      performance.

  * Each operation must be a unique function in the `libkv` namespace.
  * Keys must be `Strings` that can be used for directory paths.

    * A key must contain only the following characters:

        * a-z
        * A-Z
        * 0-9
        * The following special characters: `._:-/`

    * A key must not contain '/./' or '/../' sequences.

  * Values must be any type that is not `Undef` (`nil`) subject to the
    following constraints:

    * All values of type String must contain valid UTF-8 or have an encoding
      of ASCII-8BIT (i.e., be a Binary Puppet type).

    * All String objects contained within a complex value type (e.g., Hash,
      Array), must be valid UTF-8. Complete support of binary String content
      is deferred.

* The interface must support the use of one or more backends.

  * Each function must allow the user to optionally specify the backend
    to use and its configuration options when called.
  * When the backend information is not specified, each function must
    look up the information in Hieradata when called.

* Each function that uses a key parameter for an individual key/value pair
  must automatically prepend the Puppet environment to that key, by default.

  * Stored information is generally isolated per Puppet environment.
  * To support storage of truly global information in a backend, the interface
    must provide a mechnism to disable this prepending.
  * Prepending will not apply to `list` or `deletetree` operations.

* The interface must allow additional metadata in the form of a Hash to
  be persisted/retrieved with the key-value pair.

#### Backend Plugin Adapter

libkv must provide a backend plugin adapter that

  * loads plugin code provided by libkv and other modules with each catalog
    compile
  * instantiates plugins when needed
  * persists plugins through the lifetime of the catalog compile

    * Most efficient for plugins that maintain connections with a
      key/value service.

  * selects and uses the appropriate plugin for each libkv Puppet function call
    during the catalog compile.

* The plugin adapter must be available to all functions in the Puppet
  function API.
* The plugin adapter must be loaded and constructed in a way that prevents
  cross-environment contamination, when loaded in a puppetserver.
* The plugin adapter must load plugin software in a way that prevents
  cross-environment contamination, when loaded in a puppetserver.
* The plugin adapter must be fault tolerant against any malformed plugin
  software.

  * It must continue to operate with valid plugins, when a malformed plugin
    fails to load.

* The plugin adapter must allow multiple instances of an individual
  plugin to be instantiated and used during the catalog compile.

#### Backend Plugin API

libkv must supply a backend plugin API that provides

  * Public API method signatures, including the constructor and a
    method that reports the plugin type (typically backend it supports)
  * Description of any universal plugin options that must be supported
  * Ability to specify plugin-specific options
  * Explicit policy on error handling (how to report errors, what information
    the messages should contain for plugin proper identification, whether
    exceptions are allowed)
  * Details on the code structure required for prevention of cross-environment
    contamination
  * Documentation requirements
  * Testing requirements

Each plugin must conform to the plugin API and satisfy the following
general requirements:

* All plugins must be unique.

  * Files can be named the same in different modules, but their reported
    plugin types must be unique.

* All plugins must allow multiple instances of the plugin to
  be instantiated and used in a single catalog compile.

  * This requirement allows the same plugin to be used for distinct
    configurations to the same type of backend.

#### Configuration

* Users must be able to specify the following in Hiera:

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

  libkv::backend::file:
    # id is a required key and must be unique for all configurations
    # for a specific type of backend
    id: file

    # type is a required key and must be unique across all backend plugins.
    # However, the same type may be used for multiple backend configurations.
    type: file

    # plugin-specific configuration
    root_path: "/var/simp/libkv/file"

  libkv::backend::alt_file:
    id: alt_file
    type: file
    root_path: "/some/other/path"

  libkv::backend::consul:
    id: consul
    type: consul

    request_timeout_seconds: 15
    num_retries: 1
    uris:
    - 'consul+ssl+verify://1.2.3.4:8501/puppet'
    - 'consul+ssl+verify://1.2.3.5:8501/puppet'
    auth:
      ca_file:    "/path/to/ca.crt"
      cert_file:  "/path/to/server.crt"
      key_file:   "/path/to/server.key"

  # Hash of backend configuration to be used to lookup the appropriate backend
  # to use in libkv functions.
  #
  # Each function has an optional backend_options Hash parameter that will be
  # deep merged with this Hash.
  # *  If the merged Hash contains the key 'backend', it will specify which
  #    backend to use in the 'backends' sub-Hash below.
  # *  If the merged Hash does not contain the 'backend' key, the libkv function
  #    will look for a backend whose name matches the calling Class, specific
  #    Define, or Define type.
  # *  If no Class/Define match is found, it will use the 'default' backend.
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

      # specific 'myinstance' mydefine Define resource
      'default.Mydefine[Myinstance]': "%{alias('libkv::backend::consul')}"

      # all other (not fully specified) mydefine Define resources
      'default.Mydefine':             "%{alias('libkv::backend::alt_file')}"

      consul:                         "%{alias('libkv::backend::consul')}"
      file:                           "%{alias('libkv::backend::file')}"
      alt_file:                       "%{alias('libkv::backend::alt_file')}"

```


#### libkv-Provided Plugins and Stores

* libkv must provide a file-based key/store for a local file system and its
  corresponding plugin

    * The plugin software may implement the key/store functionality.
    * For each key/value pair, the store must write to/read from a unique
      file for that pair on the local file system (i.e., file on the
      puppetserver host).

      * The root path for files defaults to `/var/simp/libkv/file`.
      * The key specifies the path relative to the root path.
      * The store must create the directory tree, when it is absent.
      * *External* code must make sure the puppet user has appropriate access
        to root path.
      * Having each file contain a single key allows easy auditing of
        individual key creation, access, and modification.

    * The plugin must persist the value and optional metadata to file in the
      `put` operation, and then properly restore the value and metadata in the
       `get` and `list` operations.

      * The plugin must handle a value of type String that has ASCII-8BIT
        encoding (binary data).
      * The plugin (prototype only) is not required to handle ASCII-8BIT-encoded
        Strings within more complex value types (Arrays, Hashes).

    * The plugin `put`, `delete`, and `deletetree` operations must be
      multi-process safe on a local file system.

    * The plugin `put`, `delete`, and `deletetree` operations may be
      multi-process safe on shared file systems, such as NFS.

      * Getting this to work on specific shared file system types is
        deferred to future requirements.

* libkv may provide a Consul-based plugin

### Future Requirements

This is a placeholder for miscellaneous, additional libkv requirements
to be addressed, once it moves beyond the prototype stage.

* libkv must support audit operations on a key/value store

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
  stored in `/var/simp/environments` to a backend.
* libkv local file backend must encrypt each file it maintains.
* libkv local file backend must ensure multi-process-safe `put`,
  `delete`, and `deletetree` operations on a <insert shared file system
   du jour> file system.

* libkv must handle Binary objects (Strings with ASCII-8BIT encoding) that
  are embedded in complex Puppet data types such as Arrays and Hashes.

  * This includes Binary objects in the value and/or metadata of any
    given key.

## Rollout Considerations

Understanding how the libkv functionality will be rolled out to replace
functionality in `simplib::passgen()``, the `pki` Class, and the `krb5` Class
informs the libkv requirements and design.  To that end, this section describes
the expected rollout for each replacement.

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

* `pki` and `krb5` Classes conversions are independent.
* `krb5` keytabs are binary data which may be a problem in Puppet 5.

  * See discussions in tickets.puppetlabs.com/browse/PUP-9110,
    tickets.puppetlabs.com/browse/PUP-3600, and
    tickets.puppetlabs.com/browse/SERVER-1082.

* It may make sense to allow users to opt into these changes via a new
  `libkv` class parameter.

  * Class code would contain both ways of managing File content.
  * User could fall back to non-libkv mechanisms if any unexpected problems
    were encountered.

* It may be worthwhile to have a `simp_options::libkv` parameter to enable
  use of libkv wherever it is used in SIMP modules.
* May want to provide a migration script that users can run to import existing
  secrets into the key/value store prior to enabling this option.

## Design

### Changes from Version 0.6.X

Major design/API changes since version 0.6.X are as follows:

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

### libkv Puppet Functions

#### Overview

libkv Puppet functions provide access to a key/value store from an end-user
perspective.  This means the API provides simple operations and does not
expose the complexities of concurrency.  So, Puppet code simply calls functions
which, by default, either work or fail. No complex logic needs to be built into
that code.

For cases in which it may be appropriate for Puppet code to handle error
cases itself, instead of failing a catalog compilation, the libkv Puppet
function API does allow each function to be executed in a `softfail` mode.
The `softfail` mode can also be set globally for a specific backend.  When
`softfail` mode is enabled, each function will return a result object even
when the operation failed.

Each function body will affect the operation requested by doing the following:

* validate parameters beyond what is provided by Puppet
* lookup global backend configuration in Hiera
* merge the global backend configuration with specific backend configuration
  provided in options passed to the function (specific configuration takes
  priority)
* load and instantiate the plugin adapter, if it has not already been loaded
* delegate operations to that adapter
* return the results or raise, as appropriate

#### Common Function Options

Each libkv Puppet function will have an optional `backend_options` Hash parameter.
This parameter can be used to specify global libkv options and/or the specific
backend to use (with or without backend-specific configuration).  This Hash
will be merged with the configuration found in the `libkv::options`` Hiera
entry.

The standard options available are as follows:

* `softfail`: Boolean.  When set to `true`, each function will return results,
  even when the operation has failed.  When the operation that failed
  was a retrieval operation (e.g., `get`), the returned value will be an
  appropriate empty/null object.  Defaults to `false`.
* `environment`: String. When set to a non-empty string, the value is prepended
  to the `key` parameter in individual key/value operations (i.e., all but
  `list` or `deletetree`).  Should only be set to an empty string when the key
  being accessed is truly global.  Defaults to the Puppet environment for the
  node.
* `backend`: String.  Name of the backend to use.  Must be a key in the
  'backends' sub-Hash of the merged options Hash.  When absent, the libkv
   function will look for a backend whose name matches the calling Class,
   specific Define, or Define type.  If no match is found, it will use the
   'default' backend.

### Function Signatures

* libkv::put: Sets the data at `key` to a `value` in the configured backend.
  Optionally sets metadata along with the `value`.

  * `Boolean libkv::put(String key, NotUndef value, Hash metadata={}, Hash backend_options={})`
  * Raises upon backend failure, unless `options['softfail']` is `true`
  * Returns `true` when backend operation succeeds
  * Returns `false` when backend operation fails and `options['softfail']`
    is `true`

* libkv::get: Retrieves the value and any metadata stored at `key` from the
  configured backend.

  * `Enum[Hash,Undef] libkv::get(String key, Hash backend_options={})`
  * Raises upon backend failure, unless `options['softfail']` is `true`
  * Returns a Hash when the backend operation succeeds

    * Hash will have a 'value' key containing the retrieved value of type
      `Any`
    * Hash may have a 'metadata' key containing a Hash with any metadata
      for the key

  * Returns `nil` , when the backend operation fails and `options['softfail']`
    is `true`

* libkv::delete: Deletes a `key` from the configured backend.

  * `Boolean libkv::delete(String key, Hash backend_options={})`
  * Raises upon backend failure, unless `options['softfail']` is `true`
  * Returns `true` when backend operation succeeds
  * Returns `false` when backend operation fails and `options['softfail']`
    is `true`

* libkv::exists: Returns whether the `key` exists in the configured backend.

  * `Enum[Boolean,Undef] libkv::exists(String key, Hash backend_options={})`
  * Raises upon backend failure, unless `options['softfail']` is `true`
  * Returns key status (`true` or `false`), when the backend operation succeeds
  * Returns `nil`, when the backend operation fails and `options['softfail']`
    is `true`

* libkv::list: Returns a list of all keys in a folder.

  * `Enum[Hash,Undef] libkv::list(String keydir, Hash backend_options={})`
  * Raises upon backend failure, unless `options['softfail']` is `true`
  * Returns a Hash when the backend operation succeeds

    * Each key in the returned Hash will be a key (`String`) in the backend
    * Each value in the returned Hash will be a Hash that itself contains a
      'value' key with the value (`Any`) and a 'meta' key with any metadata
      for the key (`Hash`)
    * Example

      ```ruby

        { 'key1' => {'value' => 'hello', meta => { ... } },
          'key2' => {'value' => 'Bob', meta => { ... } } }

      ```
  * Returns `nil`, when the backend operation fails and `options['softfail']`
    is `true`

* libkv::deletetree: Deletes a whole folder from the configured backend.

  * `Boolean libkv::deletetree(String keydir, Hash backend_options={})`
  * Raises upon backend failure, unless `options['softfail']` is `true`
  * Returns `true` when backend operation succeeds
  * Returns `false` when backend operation fails and `options['softfail']`
    is `true`

### libkv plugin adapter

An instance of the plugin adapter must be maintained over the lifetime of
a catalog compile. Puppet does not provide a mechanism to create such an
object.  So, we will create the object in pure Ruby and attach it to the
catalog object for use by all libkv Puppet functions. This must be done
in a fashion that prevents cross-environment contamination when Ruby code
is loaded into the puppetserver....a requirement that necessarily adds
complexity to both the plugin adapter and the plugins it loads.

There are two mechanisms for creating environment-contained adapter and 
plugin code:

* Create anonymous classes accessible by predefined local variables upon
  in an `instance_eval()`
* `load` classes that start anonymous but then set their name to a
  constant that includes the environment.
  (See https://www.onyxpoint.com/fixing-the-client-side-of-multi-tenancy-in-the-puppet-server/)

In either case the plugin adapter and plugin code must be written in pure
Ruby and reside in the 'libkv/lib/puppet_x/libkv' directory.

The documentation here will not focus on the specific method to be used,
but on the design:  the responsibilities and API of the plugin adapter.


  * It must construct plugin objects and retain them through the life of
    a catalog instance.
  * It must select the appropriate plugin object to use for each function call.

* The plugin adapter must serialize data to be persisted into a common
  format and then deserialize upon retrieval.
    * Transformation done only in one place, instead of in each plugin (DRY).
    * Prevents value objects from being modified by plugin function code.
      This is especially of concern of complex Hash objects, for which
      there is no deep copy mechanism.  (`Hash.dup` does *not* deep copy!)

  * It must safely handle unexpected plugin failures, including failures to
    load (e.g., malformed Ruby).

* The plugin adapter must serialize data to be persisted into a common
  format and then deserialize upon retrieval.
    * Transformation done only in one place, instead of in each plugin (DRY).
    * Prevents value objects from being modified by plugin function code.
      This is especially of concern of complex Hash objects, for which
      there is no deep copy mechanism.  (`Hash.dup` does *not* deep copy!)

  * It must safely handle unexpected plugin failures, including failures to
    load (e.g., malformed Ruby).

## Plugin API

The simple libkv function API has relegated the complexity of atomic key/value
modifying operations to the backend plugins.

* The plugins are expected to provide atomic key-modifying operations
  automatically, wherever possible, using backend-specific lock/or
  atomic operations mechanisms.
* A plugin may choose to cache data for key quering operations, keeping
  in mind each plugin instance only remains active for the duration of the
  catalog instance (compile).
* Each plugin may choose to offer a retry option, to minimize failed catalog
  compiles when connectivity to its remote backend is spotty.

As described in []#() All plugins must be written in pure Ruby.


* All plugin code must be able to be loaded in a fashion that prevents
  cross-environment code contamination, when loaded in the puppetserver.

  * This requires dynamically loaded classes that are either anonymous or
    that contain generated class names.  Both options result in necessarily
    fugly code.
* The plugin for each backend must support all the operations in this API.

  * Writing Puppet code is difficult otherwise!
  * Mapping of the interface to the actual backend operations is up to
    the discretion of the plugin.

Overview
* The plugin adapter is responsible for managing and using plugin code.
  It must

  * Load plugins
  * Serialize data to be persisted into a common format and then deserialize
    upon retrieval.
  * Safely handle unexpected plugin failures.

* persisted in JSON
      * This *ASSUMES* all the types within Puppet are built upon primitives for
        which a meaningful `.to_json` method exists.
      * Although JSON is not a compact/efficient representation, it is
        universally parsable.

libkv file key/value store
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



*Returns:* Any

*Usage:*

<pre lang="ruby">
 $database_server = libkv::get("/database/${facts['fqdn']}")
 class { 'wordpress':
   db_host => $database_server,
 }
</pre>


<h3><a id="delete">libkv::delete</a></h3>

