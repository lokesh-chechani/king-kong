local PLUGIN_NAME = "koko"


-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()

--- check the remote url correctness

  it("accepts distinct request_header and response_header", function()
    local ok, err = validate({
        client_request_header = "client_request_header",
        koko_custom_header = "Your-Response",
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)


  it("does not accept identical request_header and response_header", function()
    local ok, err = validate({
      client_request_header = "they-are-the-same",
      koko_custom_header = "they-are-the-same",
      })

    assert.is_same({
      ["config"] = {
        ["@entity"] = {
          [1] = "values of these fields must be distinct: 'client_request_header', 'koko_custom_header'"
        }
      }
    }, err)
    assert.is_falsy(ok)
  end)

end)
