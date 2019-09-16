# Loading this file via 'my_object.instance_eval()' does the following:
# - Adds read and write accessors for a 'libkv' attribute to 'my_object'.
# - Loads libkv.rb in a fashion that the anonymous libkv adapter class it
#   contains is accessible in the scope of this file.
# - Sets the new libkv attribute of 'my_object' to a new libkv adapter
#   instance created from the anonymous class.
#
# This code is intended to be loaded by a Puppet catalog instance, so that
# the libkv adapter can be accessed by all libkv API functions.  The benefits
# of this circuitous way of accessing the libkv adapter are:
# - It prevents cross-environment contamination of PuppetX Ruby code
# - It allows new libkv provider code to be dynamically loaded without
#   a puppetserver reload.
#
################################################################################

# Define attribute accessors

# Get libkv adapter
# @return libkv adapter object
def libkv
  @libkv
end

# Set libkv adapter
# @param value libkv wrapper object
def libkv=(value)
  @libkv = value
end

# Load libkv.rb.  The code evaluated will set this local scope variable
# 'simp_libkv_adapter_class' to an anonymous Class object for the libkv adapter
# contained in the file.
# NOTE:  'simp_libkv_adapter_class' **MUST** be defined prior to the eval
#        in order to be in scope
simp_libkv_adapter_class = nil
self.instance_eval(
  File.read(File.join(File.dirname(__FILE__), 'libkv.rb')),
  File.join(File.dirname(__FILE__), 'libkv.rb')
)

# Set libkv attribute of the object loading this file to a new libkv
# adapter instance
self.libkv = simp_libkv_adapter_class.new
