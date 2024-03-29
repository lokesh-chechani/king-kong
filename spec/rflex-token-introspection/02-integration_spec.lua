local helpers = require "spec.helpers"


local PLUGIN_NAME = "rflex-token-introspection"


for _, strategy in helpers.each_strategy() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client
    local db_strategy = strategy ~= "off" and strategy or nil

    lazy_setup(function()

      local bp = helpers.get_db_utils(db_strategy, nil, { PLUGIN_NAME })

      -- Inject a test route. No need to create a service, there is a default
      -- service which will echo the request.
      local route1 = bp.routes:insert({
        hosts = { "test1.com" },
      })
      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {},
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = db_strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
      
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    describe("request", function()
      it("gets 200 and auth token header on sucess remote call", function()
        local r = client:get("/request", {
          headers = {
            host = "test1.com",
            Authorization = "randomAccessToken",
            ["x-rflex-internal-token"] = "randomInternaltoken"
          }
        })
        -- validate that request processed and remote call succeeded -> response status 200
        assert.response(r).has.status(200)
        -- now check the request to have the header
        local idp_user_id_header_value = assert.request(r).has.header("idp_user_id")
        -- -- validate the value of that header
        assert.is_not_nil(idp_user_id_header_value)
        local idp_customer_id_header_value = assert.request(r).has.header("idp_customer_id")
        -- -- validate the value of that header
        assert.is_not_nil(idp_customer_id_header_value)
      end)
    end)
    
    -- describe("request", function()
    --   it("gets 400 on missing custom client request header", function()
    --     local r = client:get("/request", {
    --       headers = {
    --         host = "test1.com"
    --       }
    --     })
    --     -- validate that request processed and remote call succeeded -> response status 200
    --     assert.response(r).has.status(400)
    --   end)
    -- end)

    -- describe("request", function()
    --   it("gets 401 on invalid value in custom client request header", function()
    --     local r = client:get("/request", {
    --       headers = {
    --         host = "test1.com",
    --         ["x-koko-req"] = "iam@unauthorized.com"
    --       }
    --     })
    --     -- validate that request processed and remote call succeeded -> response status 200
    --     assert.response(r).has.status(401)
    --   end)
    -- end)

  end)
end