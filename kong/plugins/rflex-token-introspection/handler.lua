

local utils = require "kong.tools.utils"
local cjson = require "cjson.safe"
local http = require "resty.http"
local url = require "socket.url"

local kong = kong
--local update_time  = ngx.update_time
local get_service = kong.router.get_service
local get_route = kong.router.get_route
local get_header = kong.request.get_header

local req_get_headers = ngx.req.get_headers
local set_header = ngx.req.set_header

local fmt = string.format
local ngx_log = ngx.log
local ERR = ngx.ERR
local WARN = ngx.WARN


local IntrospectionHandler = {
  VERSION = "1.0",
  PRIORITY = 1000, -- TODO : Set the right priority
}


-- runs in the 'access_by_lua_block'
function IntrospectionHandler:access(conf)
  kong.log.debug("IntrospectionHandler:access():: Executing Access method")
  kong.log.inspect(conf)

  local ok, err = do_authentication(conf)
  if not ok then
      return kong.response.exit(err.status, err.message)
  end

end

function do_authentication(conf)

  kong.log.debug("IntrospectionHandler:do_authentication():: Executing Introspection Authentication")

  -- Retrive both tokens
  local access_token = get_header("authorization")
  local internal_auth_token = get_header(conf.rflex_internal_token_header)

  kong.log.debug("IntrospectionHandler:do_authentication():: Received Rflex internal generated token ", internal_auth_token)
  kong.log.debug("IntrospectionHandler:do_authentication():: Received Rflex access_token token ", access_token)

  -- Do not do the introspection if token is not present in the request header
  if not internal_auth_token or internal_auth_token == "" then
    kong.log.debug("IntrospectionHandler:do_authentication():: Missing internal token. Check if previous internal token generator plugin executed properly.")
    return false, {
      status = 500,
      message = {
        error = "internal error",
        error_description = "Internal authorization Token is missing"
      }
    }
  end


  if not access_token or access_token == "" then
    kong.log.debug("IntrospectionHandler:do_authentication():: Missing Access Token from the request")
    return false, {
      status = 401,
      message = {
        error = "invalid_request",
        error_description = "The access token is missing"
      }
    }
  end

  local cache = kong.cache
  local cache_key = fmt("rflex_oauth2_introspection:%s", access_token)
  kong.log.debug("IntrospectionHandler:do_authentication():: cache_key = ", cache_key)

  local introspection_response, err = cache:get(cache_key,
                                      { ttl = conf.ttl_seconds },
                                      call_remote_introspection, conf,
                                      access_token, internal_auth_token)
  
  -- local introspection_response, err = call_remote_introspection(conf,access_token, internal_auth_token)

  kong.log.debug("IntrospectionHandler:do_authentication():: introspection_response = ", introspection_response)
  if err then
    kong.log.error("IntrospectionHandler:do_authentication():: Error while introspection response")
    ngx_log(ERR, err)
    return false, {status = 500, message = err}
  end



  local introspect_result = cjson.decode(introspection_response)

  kong.log.debug("IntrospectionHandler:do_authentication():: Introspection response, the supplied access token active = ", introspect_result.active)
  -- Check the introspect response for active or not
  if not introspect_result.active then
    kong.log.debug("IntrospectionHandler:do_authentication():: Invalid access token")

    return { err = {status=401,
                 message = {error = "invalid_token",
                 error_description = "The access token is invalid or has expired"},
                 headers = {["WWW-Authenticate"] = 'Bearer realm="service" error="invalid_token" error_description="The access token is invalid or has expired"'}}}
  end


  -- Set header
  kong.log.debug("IntrospectionHandler:do_authentication():: Valid access token, setting up upstream request header idp_user_id = "..introspect_result.userId..", idp_customer_id = "..introspect_result.customerId)

  set_header("idp_user_id", introspect_result.userId)
  set_header("idp_customer_id", introspect_result.customerId)
  set_header("idp_token_active", introspect_result.active)

  return true

end


function call_remote_introspection(conf, accessToken, internalToken)
  
  local introspection_url = conf.rflex_introspection_url
  kong.log.debug("IntrospectionHandler:call_remote_introspection()::calling remote introspection server :: ", introspection_url)

  local http = require "resty.http"
  local httpc = http.new()
  local res, err = httpc:request_uri(introspection_url, {
    method = "POST",
    query = {
      ["accessToken"] = accessToken
    },
    headers = {
      Accept = "application/json",
      Authorization = internalToken,
      -- Providing some additional information about the request to introspection endpoint
      ["X-Request-Http-Method"] = kong.request.get_method(),
      ["X-Request-Path"] = kong.request.get_path()
    },
    keepalive_timeout = conf.timeout_ms,
    keepalive_pool = conf.keeplive_ms
  })
  
  kong.log.debug("IntrospectionHandler:call_remote_introspection():: Introspection returned status code " .. tostring(res.status))
  kong.log.debug("IntrospectionHandler:call_remote_introspection():: Returned Introspection response ", tostring(res.body))

  local success = res.status < 400

  if not success then
    kong.log.error("IntrospectionHandler:call_remote_introspection():: Missing Access Token from the request")
    return nil, {
      status = 500,
      message = {
        error = "bad_request",
        error_description = "Failed to get introspection response"
      }
    }
  end

  return res.body, nil

end

-- return our plugin object
return IntrospectionHandler
