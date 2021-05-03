# Bad simpkv plugin with malformed Ruby code

# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
plugin_class = Class.new do

# OOPS....missing 'end'
