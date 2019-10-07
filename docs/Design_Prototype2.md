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
  * [libkv Configuration](#libkv-configuration)

    * [Backend Configuration Entries](#backend-configuration-entries)
    * [Backend Selection](#backend-selection)
    * [Example 1: Single libkv backend](#example-1--single-libkv-backend)
    * [Example 2: Multiple libkv backends](#example-2--multiple-libkv-backends)

  * [libkv Puppet Functions](#libkv-puppet-functions)

    * [Overview](#Overview)
    * [Common Function Options](#common-functions-options)
    * [Functions Signatures](#functions-signatures)

  * [Plugin Adapter](#plugin-adapter)
  * [Plugin API](#libkv-plugin-API)

## Terminology

* libkv - SIMP module that provides

  * a standard Puppet language API (functions) for using key/value stores
  * a configuration scheme that allows users to specify per-application use
    of different key/value store instances
  * adapter software that loads and uses store-specific interface software
    provided by the libkv module itself or other modules
  * a Ruby API for the store interface software that developers can implement
    to provide their own store interface
  * a file-based store on the local filesystem and its interface software

* backend - A specific key/value store, e.g., files on a local filesystem,
  Consul, Etcd, Zookeeper
* plugin - Ruby software that interfaces with a specific backend to
  affect the operations requested in libkv functions.

  * AKA provider.  Plugin will be used throughout this document to avoid
    confusion with Puppet types and providers.

* plugin adapter - Ruby software that loads, selects, and executes the
  appropriate plugin software for a libkv function call.

## Scope

This documents libkv requirements, roll out considerations, and a
second-iteration, prototype design to meet those requirements.

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
      is deferred to a future requirement.

* The interface must support the use of one or more backends.

  * Each function must allow the user to optionally specify the backend
    to use and its configuration options when called.
  * When the backend information is not specified, each function must
    look up the information in Hieradata when called.
  * When the backend configuration is available in both a function call
    and in Hieradata, the information must be merged in a fashion that
    the information provided in the function call takes precedence.

* Each function that uses a key or keydir parameter must automatically
  prepend the Puppet environment to that key, by default.

  * Stored information is generally isolated per Puppet environment.
  * To support storage of truly global information in a backend, the interface
    must provide a mechnism to disable this prepending.

* The interface must allow additional metadata in the form of a Hash to
  be persisted/retrieved with the key-value pair.

#### Backend Plugin Adapter

libkv must provide a backend plugin adapter that

  * loads plugin code provided by libkv and other modules with each catalog
    compile
  * instantiates plugins when needed
  * persists plugins through the lifetime of the catalog compile

    * most efficient for plugins that maintain connections with a
      key/value service

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
  plugin to be instantiated and used during the catalog compile, when the
  instances have different configuration parameters.

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

  * Plugin Ruby files can be named the same in different modules, but
    their reported plugin types must be unique.

* All plugins must allow multiple instances of the plugin to be instantiated
  and used in a single catalog compile.

  * This requirement allows the same plugin to be used for distinct
    configurations of the same backend type.

#### Configuration

* Users must be able to specify the following in Hiera:

  * global libkv options
  * any number of backend configurations
  * different configurations for the same backend type (e.g., 'file'
    backend configurations that persist files to different root directories).

* Each backend configuration in Hiera must be identified by a name.

* When configured via Hiera, libkv configuration must include a default backend
  configuration.

* Users must be able to set libkv configuration in an individual libkv Puppet
  functions call.

  * Configuration may includes global libkv options and backend configurations.
  * Configuration may select of a specific, existing, backend configuration.
  * Configuration must override any Hiera libkv configuration.

* Users must be able to self-identify with an application identifier in an
  individual libkv Puppet function call.

  * The application id will be used to lookup the appropriate backend
    configuration to use, when the function call has not already specified it.
  * The application id can be unique to a caller or shared among libkv function
    calls.

    * A shared application id tells libkv that the same backend configuration
      should be used for all libkv function calls with that id.

* When more than one backend configuration is specified, the most-specific
  configuration must be selected for a libkv Puppet function call:

  * When a specific backend is requested in a libkv Puppet function call, that
    backend will be selected.
  * Otherwise, when an application id is specified in a libkv Puppet function
    call and it matches the name of a backend configuration exactly, that
    backend will be selected.
  * Otherwise, when an application id is specified in a libkv Puppet function
    call and it starts with the name of a backend configuration, that backend
    will be selected.
  * Otherwise, when no application id has been specified in a libkv Puppet
    function call, or the provided application id does not match the name
    of any backend configuration, the default backend will be selected.

* When no libkv configuration is specified either in Hiera or in an individual
  libkv Puppet call, libkv must default to libkv configuration for a local
  key/value store.

  * This requirement supports libkv rollout.


#### libkv-Provided Plugins and Stores

* libkv must provide a file-based key/store for a local file system and its
  corresponding plugin

    * The plugin software may implement the key/store functionality.
    * For each key/value pair, the store must write to/read from a unique
      file for that pair on the local file system (i.e., file on the
      puppetserver host or the compile host).

      * The root path for files defaults to `/var/simp/libkv/file/<id>`.

        * If the user compiling Puppet manifests does not have the ability to
          access/create that directory, the default root path must be in
          Puppet's `vardir`,  a directory available to all users compiling
          manifests (e.g., the `puppetserver` and the Bolt user).  For example,
          `<Puppet vardir>/simp/libkv/file/<id>`.

      * The key specifies the path relative to the root path.
      * The store must create the directory tree, when it is absent.
      * Having each file contain a single key allows easy auditing of
        individual key creation, access, and modification.

    * The plugin must persist the value and optional metadata to file in the
      `put` operation, and then properly restore the value and metadata in the
      `get` and `list` operations.

      * The plugin must handle a value of type String that has ASCII-8BIT
        encoding (binary data).
      * The plugin (prototype only) is not required to handle ASCII-8BIT-encoded
        Strings within more complex value types (Arrays, Hashes).
        Full support of binary strings within complex data types is deferred
        to a future requirement.

    * The plugin `put`, `delete`, and `deletetree` operations must be
      multi-thread and multi-process safe on a local file system.

    * The plugin `put`, `delete`, and `deletetree` operations may be
      multi-thread and multi-process safe on shared file systems, such as NFS.

      * Getting this to work on specific shared file system types is
        deferred to a future requirement.

* libkv may provide a Consul-based plugin

### Future Requirements

This is a placeholder for miscellaneous, additional libkv requirements
to be addressed, once it moves beyond the prototype stage.

* libkv must provide a plugin for a remote key/value store, such as Consul
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
functionality in `simplib::passgen()`, the `pki` Class, and the `krb5` Class
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

However, to be completely backward compatible, libkv functions must be able
to be executed in the absence of ``libkv::options`` hieradata. This means libkv
must automatically, internally, default to using the libkv file store, when no
libkv backend is specified in hieradata or in a libkv function call.

### pki and krb5 Class conversions to libkv

Conversions of the `pki` and `krb5` Classes to use libkv entails switching
from using `File` resources with the `source` set to `File` resources with
`content` set to the output of `libkv::get(xxx)``.

* `pki` and `krb5` Classes conversions are independent.
* `krb5` keytabs are binary data which need to be handled carefully.

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

This section discusses at a high level the design to meet the second prototype
requirements.  For indepth understanding of the design, please refer to the
prototype software and is tests.

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
  `libkv::auth`, has been replace with a Hash `libkv::options` that meets
  the configuration requirements specified in [Configuration](#configuration).

* Standardized error handling

  * Each backend plugin operation corresponding to a libkv function must
    return a results Hash in lieu of raising an exception.
  * As a failsafe mechanism, the plugin adapter must catch any exceptions
    not handled by the plugin software and convert to a failed-operation
    results Hash.  This includes failure to load the plugin software (e.g.,
    if an externally-provided plugin has malformed Ruby.)
  * Each libkv Puppet function must raise an exception with the error message
    provided by the failed-operation results Hash, by default.  When
    configured to 'softfail', instead, each function must log the error
    message and return an appropriate failed value.

### libkv Configuration

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
  to use in the absence of the `backend` option.
  (See [Backend Selection](#backend-selection)).

* `backend`: Optional String. Specifies a specific backend configuration
  to use.

  * When present, must match a key in `backends` and will be used unequivocally.
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
  * Defaults to the Puppet environment for the node.

* `softfail`: Optional Boolean. Whether to ignore libkv operation failures.

  * When `true`, each libkv function will return a result object even when the
    operation failed at the backend.
  * When `false`, each libkv function will fail when the backend operation
    failed.
  * Defaults to `false`.

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

#### Example 1:  Single libkv backend

Below is an example of Hiera configuration in which a single backend
is specified.

```yaml

  libkv::options:
    # global options
    environment: "%{server_facts.environment}"
    softfail: false

    # Hash of backend configurations containing single entry
    backends:
      default:
        type: file
        id: file

        # plugin-specific configuration
        root_path: "/var/simp/libkv/file"
        lock_timeout_seconds: 30

```

#### Example 2:  Multiple libkv backends

Below is an example of Hiera configuration in which a multple backends
are specified and mapped to different application identifiers.

```yaml

  # The backend configurations here will be inserted into libkv::options
  # below via the alias function.
  libkv::backend::file:
    type: file
    id: file
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
    - "consul+ssl+verify://1.2.3.4:8501/puppet"
    - "consul+ssl+verify://1.2.3.5:8501/puppet"
    auth:
      ca_file:    "/path/to/ca.crt"
      cert_file:  "/path/to/server.crt"
      key_file:   "/path/to/server.key"

  libkv::options:
    # global options
    environment: "%{server_facts.environment}"
    softfail: false

    # Hash of backend configurations.
    # * Includes application-specific backends and the required default backend.
    # * libkv will use the appropriate backend for each libkv function call.
    backends:
      # backend for specific myapp application
      "myapp_special_snowflake": "%{alias('libkv::backend::alt_file')}"

      # backend for remaining myapp* applications
      "myapp":                   "%{alias('libkv::backend::file')}"

      # backend for all yourapp* applications
      "yourapp":                 "%{alias('libkv::backend::consul')}"

      # required default backend
      "default":                 "%{alias('libkv::backend::consul')}"

```

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
The `softfail` mode can also be set globally.  When `softfail` mode is enabled,
each function will return a result object even when the operation failed.

Each function body will affect the operation requested by doing the following:

* validate parameters beyond what is provided by Puppet
* lookup global backend configuration in Hiera
* merge the global backend configuration with specific backend configuration
  provided in options passed to the function (specific configuration takes
  priority)
* identify the plugin to use based on the merged configuration
* load and instantiate the plugin adapter, if it has not already been loaded
* delegate operations to that adapter
* return the results or raise, as appropriate

#### Common Function Options

Each libkv Puppet function will have an optional `options` Hash parameter.
This parameter can be used to specify libkv options and will be merged with
the configuration found in the `libkv::options`` Hiera entry.

The available options (all optional) are as follows:

* `app_id`: String. Specifies an application name that can be used to identify
  which backend configuration to use via fuzzy name matching, in the absence
  of the `backend` option.

  * More flexible option than `backend`.
  * Useful for grouping together libkv function calls found in different
    catalog resources.
  * See [Backend Selection](#backend-selection).

* `backend`: String.  Definitive name of the backend to use.

  * Takes precedence over `app_id`.
  * When present, must match a key in the `backends` option of the
    merged options Hash and will be used unequivocally.

    * If that backend does not exist in the `backends` option, the libkv
      function will fail.

  * When absent, the backend configuration will be selected from the set of
    entries in `backends`, using the `app_id` option if specified.
    (See [Backend Selection](#backend-selection)).

* `backends`: Hash.  Hash of backend configurations

  * Each backend configuration in the merged options Hash must be
    a Hash that has the following keys:

    * `type`:  Backend type.
    * `id`:  Unique name for the instance of the backend. (Same backend
      type can be configured differently).

   * Other keys for configuration specific to the backend may also be
     present.

* `environment`: String.  Puppet environment to prepend to keys.

  * When set to a non-empty string, it is prepended to the key used in
    the backend operation.
  * Should only be set to an empty string when the key being accessed is
    truly global.
  * Defaults to the Puppet environment for the node.

#### Function Signatures

See REFERENCE.md

### Plugin Adapter

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
but on the functionality of the plugin adapter.

The responsibilities and API of the plugin adapter are as follows:

* It must construct plugin objects and retain them through the life of
  a catalog instance.
* It must select the appropriate plugin object to use for each function call.
* It must must serialize data to be persisted into a common format, JSON
  string, and then deserialize upon retrieval.

    * Transformation done only in one place, instead of in each plugin (DRY).
    * Prevents value objects from being modified by plugin function code.
      This is especially of concern of complex Hash objects, for which
      there is no deep copy mechanism.  (`Hash.dup` does *not* deep copy!)

* It must safely handle unexpected plugin failures, including failures to
  load (e.g., malformed Ruby).

### Plugin API

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
* The plugin for each backend must support all the operations in this API.

  * Writing Puppet code is difficult otherwise!
  * Mapping of the interface to the actual backend operations is up to
    the discretion of the plugin.

The specifics of the plugin API can be found in
`lib/puppet_x/libkv/plugin_template.rb`
