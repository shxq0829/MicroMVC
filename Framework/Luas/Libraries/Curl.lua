--[[
-- http curl封装类，类似 Curl.php 的功能
-- 使用方法:
local Curl = require "Curl"
local request_header = {"host" = "example.com"}
curl_obj = Curl:new(request_header)
curl_obj:timeOut(10,10,10) --可选
curl_obj:setAction('test', url):get('test', query)

body = curl_obj:body() -- 返回结果
httpcode = curl_obj:httpCode() --返回code码

@version 1.0 简单功能
@author  huaqing1
--]]

local str_find = string.find
local ngx_encode_args = ngx.encode_args
local xpcall = xpcall
local http = require "resty.http"

local Curl = Class:new('Curl');
--私有变量
 Curl._httpc  = ''		-- 不能是nil
 Curl._params = {}
 Curl._timeouts = {}
 Curl._header  = ''
 Curl._body    = ''
 Curl._url     = {}
 Curl._res     = ''   -- curl返回数据
 Curl._err 	   = ''	--错误信息

--初始化，支持传header参数
function Curl:new( request_header )
	if ( empty(request_header) or type(request_header) ~= 'table') then
		request_header = {}
	end
	request_header ['User-Agent'] = 'Mozilla/5.0 (Windows; U; Windows NT 6.0; zh-CN; rv:1.8.1.20) Gecko/20081217 Firefox/2.0.0.20'
	self:init(request_header)
	return self
end

-- http 实例
function Curl:init( request_header )
	if (self._httpc) then
		self._httpc = ''
	end
	self._httpc = http:new()
	self:setHeader(request_header)
	self:timeOut(200, 2000, 2000)
end

function Curl:setHeader( request_header )
	if (request_header and type(request_header) =='table') then
		self._params ['headers'] = request_header
	end
end


-- 私有方法
local function _setResponseData( res )
	if not empty(res) then
		Curl._body 		= res.body
		Curl._header	= res.headers
	else
		Curl._body      = ''
		Curl._header    = ''
	end
	return Curl
end
local function _request( url, params )
	Curl._httpc:set_timeouts(Curl._timeouts ['connect_timeout'], Curl._timeouts ['send_timeout'], Curl._timeouts ['read_timeout']);
	local res,err
	xpcall( 
		function () 
			res,err = Curl._httpc:request_uri(url, params)
		end,
		function ( err )
			Curl._res = ''
			Curl._err = err
		end
	)
	Curl._res = res or ''
	Curl._err = err or ''
	_setResponseData(res)
	return Curl
end

--设置超时时间，根据需要设置，默认200，2000，20000 ms
function Curl:timeOut( connect_timeout, send_timeout, read_timeout )
	if (connect_timeout > 0) then
		self._timeouts ['connect_timeout'] = connect_timeout
	end
	if (send_timeout > 0) then
		self._timeouts ['send_timeout'] = send_timeout
	end
	if (read_timeout > 0) then
		self._timeouts ['read_timeout'] = read_timeout
	end
	return self
end

--设置请求url
function Curl:setAction( action, url )
	self._url [action] = url
	return self
end

--ssl 是否认证,针对https
function Curl:ssl( ssl_verify )
	self._params ['ssl_verify'] = ssl_verify
	return self
end

--设置连接池,默认是设置的，如果不需要设置，keepalive=false, https不会设置
function Curl:setKeepalive( keepalive, keepalive_timeout, keepalive_pool )
	if (keepalive) then
		self._params ['keepalive'] 			= true
		self._params ['keepalive_timeout']	= keepalive_timeout
		self._params ['keepalive_pool']		= keepalive_pool
	else
		self._params ['keepalive'] 			= false
	end
	return self
end



 -- get 请求
function  Curl:get( action, query )
	if ( empty(self._url [action])) then
		return false
	end
	local url = self._url [action]
	if ( not str_find (url, '?')) then
		url = url .. '?'
	end
	if (not empty(query)) then
		if (type(query) == 'table') then
			url = url .. ngx_encode_args(query)
		elseif(type(query) == 'string') then
			url = url .. query
		end
	end
	self._params ['method'] = 'GET'
	_request(url, self._params)
	return self
end

 -- post 请求
function  Curl:post( action, query )
	if ( empty(self._url [action])) then
		return false
	end
	local url = self._url [action]
	if (not empty(query)) then
		if (type(query) == 'table') then
			self._params ['body'] = ngx_encode_args(query)
		elseif(type(query) == 'string') then
			self._params ['body'] = query
		end
	end
	self._params ['method'] = 'POST'
	_request(url, self._params)
	return self
end

-- 返回body信息
function Curl:body()
	return self._body
end

-- 返回header信息
function Curl:header()
	return self._header
end

-- 返回httpstatus
function Curl:httpCode(  )
	--var_dump(Curl)
	if (not empty(self._err)) then
		return 500		-- 有报错
	end
	return self._res.status
end

-- 返回报错信息
function Curl:geterr()
	return self._err
end

-- 返回设置的url
function Curl:getUrl( action )
	return self._url [action]
end

--返回最近一次请求的get_reused_times
function Curl:getReusedTimes( )
	return self._httpc:get_reused_times()
end

return Curl