local typedefs = require "kong.db.schema.typedefs"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local schema = {
  name = plugin_name,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {
          -- a standard defined field (typedef), with some customizations
          { rflex_internal_token_request_header = typedefs.header_name {
              required = true,
              default = "x-rflex-internal-token" } },
          { rflex_introspection_url = typedefs.url {
            required = true,
            default = "http://6eg44.mocklab.io/thing/koko" } }, -- TODO - Change the default accordingly
          { timeout_ms = { 
            type = "integer",
            required = true,
            default = 60000,
            gt = 0 } },
          { keeplive_ms = { 
            type = "integer",
            required = true,
            default = 10000,
            gt = 0 } },
          { ttl_seconds = { 
            type = "number", 
            default = 300 } },
        },
      },
    },
  },
}

return schema
