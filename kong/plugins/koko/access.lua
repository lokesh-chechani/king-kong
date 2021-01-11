
local cjson   = require "cjson"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"

local ngx = ngx
local kong = kong
local error = error

local _M = {}

local function call_remote(conf)
  
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

  -- arsing the Json : Fetching sample koko key from response
  local json = cjson.decode(tostring(res.body))
  kong.log.debug("remote server response key [koko] :: ", json.koko)

  local auth_token = res.headers["auth-token"] --TODO "Externalized header name in config"
  kong.log.debug("Retrived jwt token :: ", auth_token)

  return auth_token
  
end

function _M.execute(conf)
    
  kong.log.debug("Executing 'access' handler")

  kong.log.inspect(conf)   -- pretty-printed config in logs

  local client_req_header_val = ngx.req.get_headers()[conf.client_request_header]

  if(client_req_header_val == nil) then
    kong.log.debug("Missing mandatory client header ", conf.client_request_header)
    return kong.response.error(400, "Missing header " .. conf.client_request_header)
  end

  kong.log.debug("retrived custom header " .. conf.client_request_header .. " with value " .. client_req_header_val)

  --TODO Caching
  -- For simplicity - using incoming header value - email as a key
  
  local auth_token, err = kong.cache:get(client_req_header_val, {ttl = conf.ttl}, call_remote, conf)

  local c_ttl, c_err, c_value = kong.cache:probe(client_req_header_val)

  kong.log.debug("probing cache, any error ", c_err)
  kong.log.debug("probing cache, remaing ttl ", c_ttl)
  kong.log.debug("probing cache, cached value ", c_value)

  if c_err then
    kong.log.err("could not retrieve user", c_err)
    return kong.response.exit(500, "Unexpected error")
  end

  -- local response, err = call_remote(conf)

  if not auth_token then
    kong.log.debug("Error while calling remote")
    return kong.response.error(401, "Invalid request")
  end
  
  
  kong.log.debug("validating jwt auth token :: ", auth_token)
  
  -- Verifying JWT - Decode token
  local jwt, err = jwt_decoder:new(auth_token)
  if err then
      return false, { status = 401, message = "Bad token; " .. tostring(err) }
  end
  kong.log.debug("jwt verfied, auth token :: ", auth_token)

  -- Fetching a key from JWT token payload
  kong.log.debug("rerived jwt claim [name] from jwt payload :: ", jwt.claims.name)
  -- Setting auth header for downstream services
  ngx.req.set_header(conf.koko_custom_header, auth_token)
  

end

return _M


