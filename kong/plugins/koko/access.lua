
local cjson   = require "cjson"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"

local ngx = ngx
local kong = kong
local error = error

local _M = {}

local function call_remote(conf)

  kong.log.debug("say hi form remote1")
  kong.log.debug("calling remote auth server :: ", conf.remote_url)
  local http = require "resty.http"
  local httpc = http.new()
  local res, err = httpc:request_uri(conf.remote_url, {
    method = "GET",
    headers = {
      ["accept"] = "application/json",
      ["".. conf.koko_remote_header .. ""] = ngx.req.get_headers()[conf.client_request_header]
    },
    keepalive_timeout = 60000,
    keepalive_pool = 10
  })
  
  kong.log.debug(" returned status code " .. tostring(res.status))
  local success = res.status < 400
  
  if not success then
    kong.log.debug("Unsucessful remote call")
    return nil, err
  end
 
  -- Retrive response and decode the json body
  -- local response_body = res.body
  kong.log.debug("Sucessful remote call")
  kong.log.debug("returned response ", tostring(res.body))

  return res
  
end

function _M.execute(conf)
    
  kong.log.debug("Executing 'access' handler")

  kong.log.inspect(conf)   -- check the logs for a pretty-printed config!

  local client_req_header_val = ngx.req.get_headers()[conf.client_request_header]

  if(client_req_header_val == nil) then
    kong.log.debug("Missing mandatory client header ", conf.client_request_header)
    return kong.response.error(400, "Missing header - " .. conf.client_request_header)
  end

  kong.log.debug("retrived custom header " .. conf.client_request_header .. " with value " .. client_req_header_val)

  local response, err = call_remote(conf)

  if not response then
    kong.log.debug("Error while calling remote")
    return kong.response.error(401, "Invalid request")
  end
  
  local auth_token = response.headers["auth-token"] --TODO "Externalized header name in config"
  kong.log.debug("jwt verfied, auth token :: ", auth_token)
  
  -- Verifying JWT - Decode token
  local jwt, err = jwt_decoder:new(auth_token)
  if err then
      return false, { status = 401, message = "Bad token; " .. tostring(err) }
  end
  kong.log.debug("jwt verfied, auth token :: ", auth_token)

  -- Fetching a key from JWT token payload
  kong.log.debug("rerived jwt claim [name] from jwt payload :: ", jwt.claims.name)

  --Parsing the Json : Fetching sample koko key from response
  local json = cjson.decode(tostring(response.body))
  kong.log.debug("remote server response key [koko] :: ", json.koko)

  -- Setting auth header for downstream services
  ngx.req.set_header(conf.koko_custom_header, auth_token)
  

end

return _M


