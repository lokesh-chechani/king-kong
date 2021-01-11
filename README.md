Sample Kong Auth Plugin
=======================

This repository contains sample auth kong plugin with following capability.

- Callling dummy remote Auth server, if Auth server return 200 and then grabing JWT token from remote server response and send it to downstream services
- Capability to externalize configs - like various header, remote server url, ttl etc..
- Capability to JWT validation and decode it
- Capability to JSON response tokenization

This Plugin has written using Lua scripting and using [`lua-nginx-module`](https://github.com/openresty/lua-nginx-module) & using Lua OpenResty Ngx API ['openresty-ngx-api'](https://openresty-reference.readthedocs.io/en/latest/Lua_Nginx_API/?q=assert&check_keywords=yes&area=default)

The base template for this plugin is [`kong-plugin`](https://github.com/Kong/kong-plugin)

This plugin was designed to work with the
[`kong-pongo`](https://github.com/Kong/kong-pongo)

