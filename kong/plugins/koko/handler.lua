-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")
local req_get_headers = ngx.req.get_headers
local cjson   = require "cjson"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
--local helpers = require "spec.helpers"
--local HTTP_TIMEOUT = 5000

local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1",
}



-- do initialization here, any module level code runs in the 'init_by_lua_block',
-- before worker processes are forked. So anything you add here will run once,
-- but be available in all workers.



-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()

  -- your custom code here
  kong.log.debug("Koko says hi from the 'init_worker' handler")

end --]]


-- runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)

  kong.log.debug("Executing 'access' handler")

  kong.log.inspect(plugin_conf)   -- check the logs for a pretty-printed config!

  local client_req_header_val = ngx.req.get_headers()[plugin_conf.client_request_header]

  if(client_req_header_val == nil) then
    kong.log.debug("Missing mandatory client header ", plugin_conf.client_request_header)
    return kong.response.error(400, "Missing header - " .. plugin_conf.client_request_header)
  end

  kong.log.debug("retrived custom header " .. plugin_conf.client_request_header .. " with value " .. client_req_header_val)

  kong.log.debug("calling remote auth server :: ", plugin_conf.remote_url)
  local http = require "resty.http"
  local httpc = http.new()
  local res, err = httpc:request_uri(plugin_conf.remote_url, {
    method = "GET",
    headers = {
      ["accept"] = "application/json",
      ["".. plugin_conf.koko_remote_header .. ""] = tostring(client_req_header_val)
    },
    keepalive_timeout = 60000,
    keepalive_pool = 10
  })
  
  kong.log.debug(" returned status code " .. tostring(res.status))
  local success = res.status < 400


  
  if success then
    -- Retrive response and decode the json body
   -- local response_body = res.body
    kong.log.debug("Sucessful remote call")
    kong.log.debug(" returned response ", tostring(res.body))
    
    local json = cjson.decode(tostring(res.body))
    local auth_token = res.headers["auth-token"]
    
    -- Verifying JWT - Decode token
    local jwt, err = jwt_decoder:new(auth_token)
    if err then
      return false, { status = 401, message = "Bad token; " .. tostring(err) }
    end

    kong.log.debug("jwt verfied, auth token :: ", auth_token)
    kong.log.debug("rerived jwt claim [name] from jwt payload :: ", jwt.claims.name)
    kong.log.debug("remote server response key [koko] :: ", json.koko)

    ngx.req.set_header(plugin_conf.koko_custom_header, auth_token)

  else
    kong.log.debug("Unsucessful remote call")
    return kong.response.error(401, "Invalid request")
  end

end --]]

local function call_remote(conf)
  local remote_client = helpers.proxy_client();

  local res = assert(remote_client:send {
    method = "GET",
    path = "/header/x-custom-header",
    headers = {
      ["Host"] = "http://mockbin.org",
      ["Content-Type"] = "application/json"
    },
  })


  kong.log.debug("READING Response body")
  assert.response(res).has.status(200)
  assert.response(res).True(true)
  
  local response_body = res:read_body()
  local success = res.status < 400

  kong.log.debug(" returned status code " .. tostring(res.status) .. " and body " .. response_body)

  

  remote_client:close()

  return success
end

local function call_remote1(plugin_conf)

  kong.log.debug("call_remote1 1")
  local http = require "resty.http"
  kong.log.debug("call_remote1 2")
  local httpc = http.new()
  kong.log.debug("call_remote1 3")

  local res, err = httpc:request_uri("http://httpbin.org/uuid", {
    method = "GET",
    headers = {
      ["accept"] = "application/json"
    },
    keepalive_timeout = 60000,
    keepalive_pool = 10
  })

  kong.log.debug("call_remote1 4")

  kong.log.debug("call_remote1 5")
  --local response_body = res:read_body()
  local success = res.status < 400

  kong.log.debug("call_remote1 6")
  kong.log.debug(" returned status code " .. tostring(res.status))

  kong.log.debug("call_remote1 7")
  for k,v in pairs(res.headers) do
    kong.log.debug("Remote server response header ", k)
  end

  return success

end

-- return our plugin object
return plugin
