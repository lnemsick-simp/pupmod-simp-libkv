# vim: set expandtab ts=2 sw=2:
def libkv()
  @libkv
end
def libkv=(value)
  @libkv = value
end

# Libkv global wrapper.
# it's job is to contain all libkv code
# and data for the lifetime of the catalog,
# and allow mappings of urls to object instances,
# and provider classes.
#
# This is anonymous to allow for code updating.


# Use the adapter pattern to inject an anonymous
# module into the catalog, so we get a libkv
# attribute, and then assign an anonymous class
# to libkv.
#
# Basically, there is no constants assigned to any
# libkv code, so there is no risk of environment or catalog
# poisoning if the underlying module is updated.
libkv = Object.new()
libkv.instance_eval(File.read(File.dirname(__FILE__) + "/libkv.rb"), File.dirname(__FILE__) + "/libkv.rb")

self.libkv = libkv

