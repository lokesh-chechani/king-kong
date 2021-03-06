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
          { client_request_header = typedefs.header_name {
              required = true,
              default = "x-koko-req" } },
          { remote_url = typedefs.url { -- by typedef url - inferring url symantic validation
            required = true,
            default = "http://6eg44.mocklab.io/thing/koko" } },
          { koko_remote_header = typedefs.header_name {
            required = true,
            default = "x-koko-remote" } },
          { koko_custom_header = typedefs.header_name {
            required = true,
            default = "x-koko-custom" } },
          { ttl = { -- self defined field
              type = "integer",
              default = 3600,
              required = true,
              gt = 0, }}, -- adding a constraint for the value
        },
        entity_checks = {
          -- We specify that both header-names cannot be the same
          { distinct = { "client_request_header", "koko_custom_header"} },
        },
      },
    },
  },
}

return schema
