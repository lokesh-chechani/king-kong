-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")
local req_get_headers = ngx.req.get_headers
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

  kong.log.debug("Koko says hi from the 'access' handler")

  -- your custom code here
  kong.log.inspect(plugin_conf)   -- check the logs for a pretty-printed config!

  local x_koko_req_header = ngx.req.get_headers()[plugin_conf.koko_req_header]

  kong.log.debug("retrived custom header " .. plugin_conf.koko_req_header .. " with value " .. ngx.req.get_headers()[plugin_conf.koko_req_header])

  kong.log.debug("calling remote server :: ", plugin_conf.remote_url)
  local http = require "resty.http"
  local httpc = http.new()
  local res, err = httpc:request_uri(plugin_conf.remote_url, {
    method = "GET",
    headers = {
      ["accept"] = "application/json"
    },
    keepalive_timeout = 60000,
    keepalive_pool = 10
  })
  
  kong.log.debug(" returned status code " .. tostring(res.status))
  local success = res.status < 400

  for k,v in pairs(res.headers) do
    kong.log.debug("Remote server response header " .. k .. ":" .. v)
  end
  
  if success then 
    ngx.req.set_header(plugin_conf.request_header, "this is on a request")
  else
    kong.log.debug(" Unsucessful handling  ")
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

-- runs in the 'header_filter_by_lua_block'
function plugin:header_filter(plugin_conf)

  kong.log.debug("Koko says hi from the 'header_filter' handler")


  -- your custom code here, for example;
  ngx.header[plugin_conf.response_header] = "this is on the response"

end --]]


-- runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)

  -- your custom code here
  kong.log.debug("koko says hi from the 'log' handler")

end --]]


-- return our plugin object
return plugin
