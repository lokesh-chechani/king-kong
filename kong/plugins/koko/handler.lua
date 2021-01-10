
local access = require "kong.plugins.koko.access"


local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1",
}



-- runs in the 'access_by_lua_block'
function plugin:access(conf)
  access.execute(conf)
end

-- return our plugin object
return plugin
