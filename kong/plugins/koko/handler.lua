-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")
local req_get_headers = ngx.req.get_headers

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

  kong.log.debug("this is fun ", ngx.req.get_headers()[plugin_conf.koko_req_header])

  --TODO safe gaurd with nil value check

  ngx.req.set_header(plugin_conf.request_header, "this is on a request")



end --]]


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
