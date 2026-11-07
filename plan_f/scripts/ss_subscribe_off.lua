------------------------------------------------
-- This file is part of the luci-app-ssr-plus subscribe.lua
-- @author William Chan <root@williamchan.me>
-- 2020/03/15 by chongshengB
-- 2021/05/13 by zusterben
------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
local tinsert = table.insert
local ssub, slen, schar, sbyte, sformat, sgsub = string.sub, string.len, string.char, string.byte, string.format, string.gsub
local jsonParse, jsonStringify = cjson.decode, cjson.encode
local b64decode = nixio.bin.b64decode
local b64encode = nixio.bin.b64encode
local URL = require "ss_url"
local cache = {}
local nodeResult = setmetatable({}, {__index = cache}) -- update result
local i = 1
-- base64
local function base64Decode(text)
	local raw = text
	if not text or text == "" then return "" end
	text = text:gsub("%z", "")
	text = text:gsub("%s+", "")
	text = text:gsub("_", "/")
	text = text:gsub("-", "+")
	local mod4 = #text % 4
	if mod4 > 0 then
		text = text .. string.sub("====", mod4 + 1)
	end
	local result = b64decode(text)
	if not result or result == "" then
		local resultt = io.popen('echo -n "' .. text .. '" | base64 -d 2>/dev/null')
		if resultt then
			result = resultt:read("*a")
			resultt:close()
		end
	end
	if result and result ~= "" then
		return result:gsub("%z", "")
	else
		return raw
	end
end
local ssrindext = io.popen('dbus list ssconf_basic_json_ | cut -d "=" -f1 | cut -d "_" -f4 | sort -rn|head -n1')
local ssrindex = ssrindext:read("*a")
if #ssrindex == 0 then
	ssrindex = 1
else
	ssrindex = tonumber(ssrindex) + 1
end
local ssrmodet = io.popen('dbus get ssconf_subscribe_mode')
local ssrmode = tonumber(ssrmodet:read("*a"))
local tfilter_words = io.popen("dbus get ssconf_basic_exclude")
local filter_words = tfilter_words:read("*a"):gsub("\n", "")
local tsave_words = io.popen("dbus get ssconf_basic_include")
local save_words = tsave_words:read("*a"):gsub("\n", "")
local traw = io.popen("dbus get ssconf_base64_links")

local log = function(...)
	print(os.date("%Y-%m-%d %H:%M:%S ") .. table.concat({...}, " "))
end
local encrypt_methods_ss = {
	-- plain
	"none",
	"plain",
	-- aead
	"aes-128-gcm",
	"aes-192-gcm",
	"aes-256-gcm",
	"chacha20-ietf-poly1305",
	"xchacha20-ietf-poly1305",
	-- aead 2022
	"2022-blake3-aes-128-gcm",
	"2022-blake3-aes-256-gcm",
	"2022-blake3-chacha20-poly1305"
	--[[ stream
	"table",
	"rc4",
	"rc4-md5",
	"aes-128-cfb",
	"aes-192-cfb",
	"aes-256-cfb",
	"aes-128-ctr",
	"aes-192-ctr",
	"aes-256-ctr",
	"bf-cfb",
	"camellia-128-cfb",
	"camellia-192-cfb",
	"camellia-256-cfb",
	"salsa20",
	"chacha20",
	"chacha20-ietf" ]]
}
-- 分割字符串
local function split(full, sep)
	full = full:gsub("%z", "") -- 这里不是很清楚 有时候结尾带个\0
	local off, result = 1, {}
	while true do
		local nStart, nEnd = full:find(sep, off)
		if not nEnd then
			local res = ssub(full, off, slen(full))
			if #res > 0 then -- 过滤掉 \0
				tinsert(result, res)
			end
			break
		else
			tinsert(result, ssub(full, off, nStart - 1))
			off = nEnd + 1
		end
	end
	return result
end
-- urlencode
local function get_urlencode(c)
	return sformat("%%%02X", sbyte(c))
end

local function urlEncode(szText)
	local str = szText:gsub("([^0-9a-zA-Z ])", get_urlencode)
	str = str:gsub(" ", "+")
	return str
end

local function get_urldecode(h)
	return schar(tonumber(h, 16))
end
local function UrlDecode(szText)
	return szText:gsub("+", " "):gsub("%%(%x%x)", get_urldecode)
end

-- trim
local function trim(text)
	if not text or text == "" then
		return ""
	end
	return (sgsub(text, "^%s*(.-)%s*$", "%1"))
end
-- md5
local function md5(content)
	local stdout = io.popen("echo -n '" .. urlEncode(content) .. "'|md5sum|cut -d ' ' -f1")
	local stdout2 = stdout:read("*a")
	-- assert(nixio.errno() == 0)
	return trim(stdout2)
end
-- 检查数组(table)中是否存在某个字符值
-- https://www.04007.cn/article/135.html
local function checkTabValue(tab)
	local revtab = {}
	for k,v in pairs(tab) do
		revtab[v] = true
	end
	return revtab
end
-- 处理数据
local function processData(szType, content)
	local result = {type = szType, local_port = 3333, kcp_param = '--nocomp'}
	if szType == 'ssr' then
		local dat = split(content, "/%?")
		local hostInfo = split(dat[1], ':')
		result.type = "v2ray"
		result.v2ray_protocol = "shadowsocksr"
		result.server = hostInfo[1]
		result.server_port = hostInfo[2]
		result.protocol = hostInfo[3]
		result.encrypt_method = hostInfo[4]
		result.obfs = hostInfo[5]
		result.password = base64Decode(hostInfo[6])
		local params = {}
		for _, v in pairs(split(dat[2], '&')) do
			local t = split(v, '=')
			params[t[1]] = t[2]
		end
		result.obfs_param = base64Decode(params.obfsparam)
		result.protocol_param = base64Decode(params.protoparam)
		local group = base64Decode(params.group)
		if group then
			result.alias = "[" .. group .. "] "
		end
		result.alias = result.alias .. base64Decode(params.remarks)
	elseif szType == 'vmess' then
		local info = jsonParse(content)
		result.type = 'v2ray'
		result.v2ray_protocol = 'vmess'
		result.server = info.add
		result.server_port = info.port
		result.transport = info.net
		result.alter_id = info.aid or "0"
		result.vmess_id = info.id
		result.alias = info.ps
		-- result.mux = 1
		-- result.concurrency = 8
		if info.net == 'ws' then
			result.ws_host = info.host
			result.ws_path = info.path
		end
		if info.net == 'h2' then
			result.h2_host = info.host
			result.h2_path = info.path
		end
		if info.net == 'tcp' then
			if info.type and info.type ~= "http" then
				info.type = "none"
			end
			result.tcp_guise = info.type
			result.http_host = info.host
			result.http_path = info.path
		end
		if info.net == 'kcp' then
			result.kcp_guise = info.type
			result.mtu = 1350
			result.tti = 50
			result.uplink_capacity = 5
			result.downlink_capacity = 20
			result.read_buffer_size = 2
			result.write_buffer_size = 2
		end
		if info.net == 'grpc' then
			if info.path then
				result.serviceName = info.path
			elseif info.serviceName then
				result.serviceName = info.serviceName
			end
		end
		if info.net == 'quic' then
			result.quic_guise = info.type
			result.quic_key = info.key
			result.quic_security = info.securty
		end
		if info.security then
			result.security = info.security
		end
		if info.tls == "tls" or info.tls == "1" then
			result.tls = "1"
			if info.sni and info.sni ~= "" then
				result.tls_host = info.sni
			elseif info.host then
				result.tls_host = info.host
			end
			result.insecure = 1
		else
			result.tls = "0"
		end
	elseif szType == "ss" then
		local idx_sp = 0
		local alias = ""
		if content:find("#") then
			idx_sp = content:find("#")
			alias = content:sub(idx_sp + 1, -1)
		end
		local info = content:sub(1, idx_sp - 1)
		local hostInfo = split(base64Decode(info), "@")
		local hostInfoLen = #hostInfo
		local host = nil
		local userinfo = nil
		if hostInfoLen > 2 then
			host = split(hostInfo[hostInfoLen], ":")
			userinfo = {}
			for i = 1, hostInfoLen - 1 do
				tinsert(userinfo, hostInfo[i])
			end
			userinfo = table.concat(userinfo, '@')
		else
			host = split(hostInfo[2], ":")
			userinfo = base64Decode(hostInfo[1])
		end
		if userinfo:find("ss://") then --这个就是垃圾机场
			local userinfo2 = userinfo:sub(userinfo:find(":") + 3, #userinfo)
			userinfo = base64Decode(userinfo2)
		end
		local method = userinfo:sub(1, userinfo:find(":") - 1)
		local password = userinfo:sub(userinfo:find(":") + 1, #userinfo)
		result.alias = UrlDecode(alias)
		result.type = "v2ray"
		result.v2ray_protocol = "shadowsocks"
		result.encrypt_method_ss = method
		result.password = password
		result.server = host[1]
		if host[2]:find("/%?") then
			local query = split(host[2], "/%?")
			result.server_port = query[1]
			local params = {}
			for _, v in pairs(split(query[2], '&')) do
				local t = split(v, '=')
				params[t[1]] = t[2]
			end
			if params.plugin then
				local plugin_info = UrlDecode(params.plugin)
				local idx_pn = plugin_info:find(";")
				if idx_pn then
					result.plugin = plugin_info:sub(1, idx_pn - 1)
					result.plugin_opts = plugin_info:sub(idx_pn + 1, #plugin_info)
				else
					result.plugin = plugin_info
				end
				-- 部分机场下发的插件名为 simple-obfs，这里应该改为 obfs-local
				if result.plugin == "simple-obfs" then
					result.plugin = "obfs-local"
				end
			end
		else
			result.server_port = host[2]:gsub("/","")
		end
		if checkTabValue(encrypt_methods_ss)[method] then
			result.encrypt_method_ss = method
			result.password = password
		else
			-- 1202 年了还不支持 SS AEAD 的屑机场
			--result = nil
			result.encrypt_method_ss = method
			result.password = password
		end
	elseif szType == "sip008" then
		result.type = "ss"
		result.v2ray_protocol = "shadowsocks"
		result.server = content.server
		result.server_port = content.server_port
		result.password = content.password
		result.encrypt_method_ss = content.method
		result.plugin = content.plugin
		result.plugin_opts = content.plugin_opts
		result.alias = content.remarks
		if not checkTabValue(encrypt_methods_ss)[content.method] then
			result.server = nil
		end
	elseif szType == "ssd" then
		result.type = "ss"
		result.v2ray_protocol = "shadowsocks"
		result.server = content.server
		result.server_port = content.port
		result.password = content.password
		result.encrypt_method_ss = content.method
		result.plugin_opts = content.plugin_options
		result.alias = "[" .. content.airport .. "] " .. content.remarks
		if content.plugin == "simple-obfs" then
			result.plugin = "obfs-local"
		else
			result.plugin = content.plugin
		end
		if not checkTabValue(encrypt_methods_ss)[content.encryption] then
			result.server = nil
		end
	elseif szType == "trojan" then
		local idx_sp = 0
		local alias = ""
		if content:find("#") then
			idx_sp = content:find("#")
			alias = content:sub(idx_sp + 1, -1)
		end
		local info = content:sub(1, idx_sp - 1)
		local hostInfo = split(info, "@")
		local host = split(hostInfo[2], ":")
		local userinfo = hostInfo[1]
		local password = userinfo
		result.alias = UrlDecode(alias)
		result.type = "v2ray"
		result.v2ray_protocol = "trojan"
		result.server = host[1]
		-- 按照官方的建议 默认验证ssl证书
		result.insecure = "0"
		result.tls = "1"
		if host[2]:find("?") then
			local query = split(host[2], "?")
			result.server_port = query[1]
			local params = {}
			for _, v in pairs(split(query[2], '&')) do
				local t = split(v, '=')
				params[t[1]] = t[2]
			end
			if params.sni then
				-- 未指定peer（sni）默认使用remote addr
				result.tls_host = params.sni
			end
		else
			result.server_port = host[2]
		end
		result.password = password
	elseif szType == "vless" then
		local url = URL.parse("http://" .. content)
		local params = url.query

		result.alias = url.fragment and UrlDecode(url.fragment) or nil
		result.type = "v2ray"
		result.v2ray_protocol = "vless"
		result.server = url.host
		result.server_port = url.port
		result.vmess_id = url.user
		result.vless_encryption = params.encryption or "none"
		result.transport = params.type or "tcp"
		result.reality = (params.security == "reality") and "1" or "0"
		if result.reality == "1" then
			result.tls = "0"
		else
			result.tls = (params.security == "tls" or params.security == "xtls") and "1" or "0"
		end
		result.tls_host = params.sni or params.peer or nil
		result.tls_flow = (params.security == "tls" or params.security == "xtls" or params.security == "reality") and params.flow or nil
		result.fingerprint = params.fp or "disable"
		result.reality_publickey = params.pbk and UrlDecode(params.pbk) or nil
		result.reality_shortid = params.sid
		result.reality_spiderx = params.spx and UrlDecode(params.spx) or nil
		if result.transport == "ws" then
			result.ws_host = (result.tls ~= "1") and (params.host and UrlDecode(params.host)) or nil
			result.ws_path = params.path and UrlDecode(params.path) or "/"
		-- make it compatible with bullshit, "h2" transport is non-existent at all
		elseif result.transport == "http" or result.transport == "h2" then
			result.transport = "h2"
			result.h2_host = params.host and UrlDecode(params.host) or nil
			result.h2_path = params.path and UrlDecode(params.path) or nil
		elseif result.transport == "kcp" then
			result.kcp_guise = params.headerType or "none"
			result.seed = params.seed
			result.mtu = 1350
			result.tti = 50
			result.uplink_capacity = 5
			result.downlink_capacity = 20
			result.read_buffer_size = 2
			result.write_buffer_size = 2
		elseif result.transport == "quic" then
			result.quic_guise = params.headerType or "none"
			result.quic_security = params.quicSecurity or "none"
			result.quic_key = params.key
		elseif result.transport == "grpc" then
			result.serviceName = params.serviceName
			result.grpc_mode = params.mode or "gun"
		elseif result.transport == "tcp" then
			result.tcp_guise = (result.reality == "1" or (result.tls_flow and result.tls_flow:find("xtls"))) and "none" or (params.headerType or "none")
			if result.tcp_guise == "http" then
				result.tcp_host = params.host and UrlDecode(params.host) or nil
				result.tcp_path = params.path and UrlDecode(params.path) or nil
			end
		end
	elseif szType == 'hysteria' or szType == 'hysteria2' or szType == 'hy2' then
		local alias = ""
		if content:find("#") then
			local idx_sp = content:find("#")
			alias = content:sub(idx_sp + 1, -1)
			content = content:sub(1, idx_sp - 1)
		end
		result.alias = UrlDecode(alias)
		result.type = "hysteria"
		result.v2ray_protocol = "hysteria"
		local main_part = content
		local query_part = ""
		if content:find("%?") then
			local idx_q = content:find("%?")
			main_part = content:sub(1, idx_q - 1)
			query_part = content:sub(idx_q + 1, -1)
		end
		main_part = main_part:gsub("/+$", "")
		local auth = ""
		local host_port = main_part
		if main_part:find("@") then
			local idx_at = main_part:find("@")
			auth = main_part:sub(1, idx_at - 1)
			host_port = main_part:sub(idx_at + 1, -1)
		end
		local host, port
		if host_port:find(":") then
			local hp = split(host_port, ":")
			host = hp[1]
			port = hp[2]
		else
			host = host_port
			port = "443"
		end
		result.server = host
		result.server_port = port
		local params = {}
		if query_part ~= "" then
			for _, v in pairs(split(query_part, "&")) do
				local t = split(v, "=")
				if #t >= 2 then
					params[t[1]] = UrlDecode(t[2])
				elseif #t == 1 then
					params[t[1]] = ""
				end
			end
		end
		local hy2_auth = (auth ~= "") and auth or (params.auth or "")
		result.hy2_auth = hy2_auth
		result.password = hy2_auth
		result.tls_host = params.sni or params.peer or host
		result.insecure = (params.insecure == "1" or params["allow-insecure"] == "1" or params["insecure"] == "true") and "1" or "0"
		local obfs_param = params["obfs-password"] or params.obfs_password or params.obfsParam or ""
		if obfs_param ~= "" or (params.obfs and params.obfs ~= "" and params.obfs ~= "none") then
			result.flag_obfs = "1"
			result.salamander = obfs_param
		else
			result.flag_obfs = "0"
		end
		result.uplink_capacity = params.up or params.upmbps or 5
		result.downlink_capacity = params.down or params.downmbps or 20
		result.fast_open = (params.fastopen == "1" or params.fast_open == "1") and 1 or 0
	elseif szType == 'tuic' then
		local alias = ""
		if content:find("#") then
			local idx_sp = content:find("#")
			alias = content:sub(idx_sp + 1, -1)
			content = content:sub(1, idx_sp - 1)
		end
		result.alias = UrlDecode(alias)
		result.type = "tuic"
		result.v2ray_protocol = "tuic"
		local main_part = content
		local query_part = ""
		if content:find("%?") then
			local idx_q = content:find("%?")
			main_part = content:sub(1, idx_q - 1)
			query_part = content:sub(idx_q + 1, -1)
		end
		main_part = main_part:gsub("/+$", "")
		if not main_part:find(":") or not main_part:find("@") then
			local decoded = base64Decode(main_part)
			if decoded:find(":") then
				main_part = decoded
			end
		end
		local userinfo = ""
		local host_port = main_part
		if main_part:find("@") then
			local idx_at = main_part:find("@")
			userinfo = main_part:sub(1, idx_at - 1)
			host_port = main_part:sub(idx_at + 1, -1)
		end
		local uuid, pass = "", ""
		if userinfo:find(":") then
			local idx_c = userinfo:find(":")
			uuid = userinfo:sub(1, idx_c - 1)
			pass = userinfo:sub(idx_c + 1, -1)
		else
			uuid = userinfo
		end
		local host, port
		if host_port:find(":") then
			local idx_p = host_port:match(".*():")
			host = host_port:sub(1, idx_p - 1)
			port = host_port:sub(idx_p + 1, -1):match("%d+")
		else
			host = host_port
			port = "443"
		end
		result.server = host and trim(host):gsub("%s+", "") or nil
		result.server_port = port and tostring(port):match("%d+") or "443"
		local params = {}
		if query_part ~= "" then
			for _, v in pairs(split(query_part, "&")) do
				local t = split(v, "=")
				if #t >= 2 then
					params[t[1]] = UrlDecode(t[2])
				elseif #t == 1 then
					params[t[1]] = ""
				end
			end
		end
		result.tuic_uuid = uuid
		result.vmess_id = uuid
		result.tuic_passwd = (pass ~= "") and pass or (params.password or "")
		result.password = result.tuic_passwd
		result.congestion_control = params.congestion_control or params["congestion-controller"] or "bbr"
		result.udp_relay_mode = params.udp_relay_mode or params["udp-relay-mode"] or "native"
		result.tls_alpn = params.alpn or "h3"
		result.tls_host = params.sni or host
		result.insecure = (params.allow_insecure == "1" or params.insecure == "1" or params["skip-cert-verify"] == "1" or params["skip-cert-verify"] == "true") and "1" or "0"
		result.disable_sni = (params.disable_sni == "1") and "1" or "0"
	elseif szType == 'socks' or szType == 'socks5' then
		local alias = ""
		if content:find("#") then
			local idx_sp = content:find("#")
			alias = content:sub(idx_sp + 1, -1)
			content = content:sub(1, idx_sp - 1)
		end
		result.alias = UrlDecode(alias)
		result.type = "v2ray"
		result.v2ray_protocol = "socks"
		local main_part = content
		if main_part:find("%?") then
			local idx_q = main_part:find("%?")
			main_part = main_part:sub(1, idx_q - 1)
		end
		main_part = main_part:gsub("/+$", "")
		if not main_part:find(":") or not main_part:find("@") then
			local decoded = base64Decode(main_part)
			if decoded:find(":") then
				main_part = decoded
			end
		end
		local userinfo = ""
		local host_port = main_part
		if main_part:find("@") then
			local idx_at = main_part:find("@")
			userinfo = main_part:sub(1, idx_at - 1)
			host_port = main_part:sub(idx_at + 1, -1)
		end
		local username, pass = "", ""
		if userinfo ~= "" then
			if not userinfo:find(":") then
				local decoded = base64Decode(userinfo)
				if decoded:find(":") then
					userinfo = decoded
				end
			end
			if userinfo:find(":") then
				local idx_c = userinfo:find(":")
				username = userinfo:sub(1, idx_c - 1)
				pass = userinfo:sub(idx_c + 1, -1)
			else
				username = userinfo
			end
		end
		local host, port
		if host_port:find(":") then
			local idx_p = host_port:match(".*():")
			host = host_port:sub(1, idx_p - 1)
			port = host_port:sub(idx_p + 1, -1):match("%d+")
		else
			host = host_port
			port = "1080"
		end
		result.server = host and trim(host):gsub("%s+", "") or nil
		result.server_port = port and tostring(port):match("%d+") or "1080"
		if username ~= "" or pass ~= "" then
			result.auth_enable = "1"
			result.username = username
			result.password = pass
		else
			result.auth_enable = "0"
		end
	elseif szType == 'http' or szType == 'https' then
		local alias = ""
		if content:find("#") then
			local idx_sp = content:find("#")
			alias = content:sub(idx_sp + 1, -1)
			content = content:sub(1, idx_sp - 1)
		end
		result.alias = UrlDecode(alias)
		result.type = "v2ray"
		result.v2ray_protocol = "http"
		local main_part = content
		if main_part:find("%?") then
			local idx_q = main_part:find("%?")
			main_part = main_part:sub(1, idx_q - 1)
		end
		main_part = main_part:gsub("/+$", "")
		if not main_part:find(":") or not main_part:find("@") then
			local decoded = base64Decode(main_part)
			if decoded:find(":") then
				main_part = decoded
			end
		end
		local userinfo = ""
		local host_port = main_part
		if main_part:find("@") then
			local idx_at = main_part:find("@")
			userinfo = main_part:sub(1, idx_at - 1)
			host_port = main_part:sub(idx_at + 1, -1)
		end
		local username, pass = "", ""
		if userinfo ~= "" then
			if not userinfo:find(":") then
				local decoded = base64Decode(userinfo)
				if decoded:find(":") then
					userinfo = decoded
				end
			end
			if userinfo:find(":") then
				local idx_c = userinfo:find(":")
				username = userinfo:sub(1, idx_c - 1)
				pass = userinfo:sub(idx_c + 1, -1)
			else
				username = userinfo
			end
		end
		local host, port
		if host_port:find(":") then
			local idx_p = host_port:match(".*():")
			host = host_port:sub(1, idx_p - 1)
			port = host_port:sub(idx_p + 1, -1):match("%d+")
		else
			host = host_port
			port = (szType == "https") and "443" or "80"
		end
		result.server = host and trim(host):gsub("%s+", "") or nil
		result.server_port = port and tostring(port):match("%d+") or ((szType == "https") and "443" or "80")
		if szType == "https" then
			result.tls = "1"
			result.tls_host = host
		else
			result.tls = "0"
		end
		if username ~= "" or pass ~= "" then
			result.auth_enable = "1"
			result.username = username
			result.password = pass
		else
			result.auth_enable = "0"
		end
	else
		-- 不支持的协议
		result.v2ray_protocol = szType
	end
	if not result.alias then
		if result.server and result.server_port then
			result.alias = result.server .. ':' .. result.server_port
		else
			result.alias = "NULL"
		end
	end
	-- alias 不参与 hashkey 计算
	local alias = result.alias
	result.alias = nil
	local switch_enable = result.switch_enable
	result.switch_enable = nil
	result.hashkey = md5(jsonStringify(result))
	result.alias = alias
	result.switch_enable = switch_enable
	return result
end

local function check_filer(result)
	do
		-- 过滤的关键词列表
		local filter_word = split(filter_words, ",")
		-- 保留的关键词列表
		local check_save = false
		if save_words ~= nil and save_words ~= "" and save_words ~= "NULL" and save_words ~= "\n" then
			check_save = true
		end
		local save_word = split(save_words, ",")
		-- 检查结果
		local filter_result = false
		local save_result = true

		-- 检查是否存在过滤关键词
		for i, v in pairs(filter_word) do
			if tostring(result.alias):find(v, nil, true) then
				filter_result = true
			end
		end
		-- 检查是否打开了保留关键词检查，并且进行过滤
		if check_save == true then
			for i, v in pairs(save_word) do
				if tostring(result.alias):find(v, nil, true) then
					save_result = false
				end
			end
		else
			save_result = false
		end
		-- 不等时返回
		if filter_result == true or save_result == true then
			return true
		else
			return false
		end
	end
end

local function parseClashYaml(text)
	local proxies = {}
	local in_proxies = false
	local current = nil
	for line in text:gmatch("[^\r\n]+") do
		local trimmed = trim(line)
		if trimmed:match("^proxies%s*:") then
			in_proxies = true
		elseif in_proxies and trimmed:match("^%-%s*") then
			if current and current.server and current.port then tinsert(proxies, current) end
			current = {}
			local inline_content = trimmed:match("^%-%s*(.*)$")
			if inline_content and inline_content:find(":") then
				for k, v in inline_content:gmatch("([%w_%-]+)%s*:%s*([^,}]+)") do
					v = trim(v):gsub('^["\']', ''):gsub('["\']$', '')
					if v:match("^%[(.-)%]$") then v = v:match("^%[(.-)%]") end
					current[trim(k)] = trim(v)
				end
			end
		elseif in_proxies and current and trimmed:match("^[%w_%-]+%s*:") then
			local k, v = trimmed:match("^([%w_%-]+)%s*:%s*(.*)$")
			if k and v then
				v = trim(v):gsub('^["\']', ''):gsub('["\']$', '')
				if v:match("^%[(.-)%]$") then v = v:match("^%[(.-)%]") end
				current[trim(k)] = trim(v)
			end
		elseif in_proxies and not line:match("^%s") and trimmed ~= "" and not trimmed:match("^#") then
			if current and current.server and current.port then tinsert(proxies, current) end
			current = nil
			in_proxies = false
		end
	end
	if current and current.server and current.port then tinsert(proxies, current) end
	return proxies
end

local function clashProxyToUrl(p)
	local ptype = (p.type or ""):lower()
	local name = p.name or (p.server .. ":" .. (p.port or ""))
	local server = p.server
	local port = p.port
	if not server or not port then return nil end
	if ptype == "hysteria2" or ptype == "hy2" then
		local auth = p.password or p.auth or ""
		local sni = p.sni or server
		local insecure = (p["skip-cert-verify"] == "true" or p["skip-cert-verify"] == true) and "1" or "0"
		local obfs = p.obfs or ""
		local obfs_pass = p["obfs-password"] or ""
		local q = "sni=" .. sni .. "&insecure=" .. insecure
		if obfs ~= "" then q = q .. "&obfs=" .. obfs .. "&obfs-password=" .. obfs_pass end
		return "hysteria2://" .. auth .. "@" .. server .. ":" .. port .. "/?" .. q .. "#" .. urlEncode(name)
	elseif ptype == "tuic" then
		local uuid = p.uuid or ""
		local pass = p.password or ""
		local cc = p["congestion-controller"] or p.congestion_control or "bbr"
		local udp_mode = p["udp-relay-mode"] or "native"
		local alpn = p.alpn or "h3"
		local sni = p.sni or server
		local q = "congestion_control=" .. cc .. "&udp_relay_mode=" .. udp_mode .. "&alpn=" .. alpn .. "&sni=" .. sni
		return "tuic://" .. uuid .. ":" .. pass .. "@" .. server .. ":" .. port .. "/?" .. q .. "#" .. urlEncode(name)
	elseif ptype == "socks5" or ptype == "socks" then
		local u = (p.username and p.username ~= "") and (p.username .. ":" .. (p.password or "") .. "@") or ""
		return "socks5://" .. u .. server .. ":" .. port .. "#" .. urlEncode(name)
	elseif ptype == "http" then
		local proto = (p.tls == "true" or p.tls == true) and "https" or "http"
		local u = (p.username and p.username ~= "") and (p.username .. ":" .. (p.password or "") .. "@") or ""
		return proto .. "://" .. u .. server .. ":" .. port .. "#" .. urlEncode(name)
	elseif ptype == "trojan" then
		local pass = p.password or ""
		local sni = p.sni or server
		return "trojan://" .. pass .. "@" .. server .. ":" .. port .. "?sni=" .. sni .. "#" .. urlEncode(name)
	elseif ptype == "ss" then
		local cipher = p.cipher or ""
		local pass = p.password or ""
		local userinfo = b64encode(cipher .. ":" .. pass)
		return "ss://" .. userinfo .. "@" .. server .. ":" .. port .. "#" .. urlEncode(name)
	elseif ptype == "vless" then
		local uuid = p.uuid or ""
		local is_reality = (p["reality-opts"] or p.reality or p.pbk or p["public-key"]) and true or false
		local security = is_reality and "reality" or ((p.tls == "true" or p.tls == true) and "tls" or "none")
		local sni = p.servername or p.sni or server
		local flow = p.flow or ""
		local q = "security=" .. security .. "&sni=" .. sni
		if flow ~= "" then q = q .. "&flow=" .. flow end
		if is_reality then
			local ropts = (type(p["reality-opts"]) == "table") and p["reality-opts"] or {}
			local pbk = p.pbk or p["public-key"] or ropts["public-key"] or ropts.pbk or ""
			local sid = p.sid or p["short-id"] or ropts["short-id"] or ropts.sid or ""
			local spx = p.spx or p.spiderx or ropts.spiderx or ""
			if pbk ~= "" then q = q .. "&pbk=" .. urlEncode(pbk) end
			if sid ~= "" then q = q .. "&sid=" .. urlEncode(sid) end
			if spx ~= "" then q = q .. "&spx=" .. urlEncode(spx) end
		end
		return "vless://" .. uuid .. "@" .. server .. ":" .. port .. "?" .. q .. "#" .. urlEncode(name)
	elseif ptype == "vmess" then
		local vdata = {
			v = "2",
			ps = name,
			add = server,
			port = port,
			id = p.uuid or "",
			aid = p.alterId or "0",
			scy = p.cipher or "auto",
			net = p.network or "tcp",
			type = "none",
			host = (type(p["ws-opts"]) == "table" and type(p["ws-opts"].headers) == "table") and p["ws-opts"].headers.Host or (p.servername or ""),
			path = (type(p["ws-opts"]) == "table") and (p["ws-opts"].path or "/") or "/",
			tls = (p.tls == "true" or p.tls == true) and "tls" or "none",
			sni = p.servername or p.sni or ""
		}
		return "vmess://" .. b64encode(jsonStringify(vdata))
	end
	return nil
end

--local execute = function()
	-- exec
	do
		local raw = traw:read("*a"):gsub("\n", "")
		if #raw > 0 then
			local nodes, szType
			local groupHash = md5(raw)
			cache[groupHash] = {}
			tinsert(nodeResult, {})
			local index = #nodeResult
			-- SSD 似乎是这种格式 ssd:// 开头的
			if raw:find('ssd://') then
				szType = 'ssd'
				local nEnd = select(2, raw:find('ssd://'))
				nodes = base64Decode(raw:sub(nEnd + 1, #raw))
				nodes = jsonParse(nodes)
				local extra = {airport = nodes.airport, port = nodes.port, encryption = nodes.encryption, password = nodes.password}
				local servers = {}
				-- SS里面包着 干脆直接这样
				for _, server in ipairs(nodes.servers) do
					tinsert(servers, setmetatable(server, {__index = extra}))
				end
				nodes = servers
			-- SS SIP008 直接使用 Json 格式
			elseif raw:find('{"configs"') then
				nodes = jsonParse(raw).servers or jsonParse(raw)
				if nodes[1].server and nodes[1].method then
					szType = 'sip008'
				end
			elseif raw:find('proxies%s*:') or base64Decode(raw):find('proxies%s*:') then
				local yaml_text = raw:find('proxies%s*:') and raw or base64Decode(raw)
				local clash_proxies = parseClashYaml(yaml_text)
				nodes = {}
				for _, cp in ipairs(clash_proxies) do
					local uri = clashProxyToUrl(cp)
					if uri then
						tinsert(nodes, uri)
					end
				end
			else
				-- ssd 外的格式
				local decoded_raw = base64Decode(raw)
				if decoded_raw:find('://') then
					nodes = split(decoded_raw:gsub("\r\n", "\n"), "\n")
				elseif raw:find('://') then
					nodes = split(raw:gsub("\r\n", "\n"), "\n")
				else
					nodes = split(decoded_raw:gsub(" ", "_"):gsub("\r\n", "\n"), "\n")
				end
			end
				for _, v in ipairs(nodes) do
				if v then
					local result
					if szType then
						result = processData(szType, v)
					elseif not szType then
						local node = trim(v)
						local dat = split(node, "://")
						if dat and dat[1] and dat[2] then
							local dat3 = ""
							if dat[3] then
								dat3 = "://" .. dat[3]
							end
							local proto_lower = dat[1]:lower()
							local plain_proto = {
								ss = true,
								trojan = true,
								vless = true,
								hysteria = true,
								hysteria2 = true,
								hy2 = true,
								tuic = true,
								socks = true,
								socks5 = true,
								http = true,
								https = true
							}
							if plain_proto[proto_lower] then
								result = processData(proto_lower, dat[2] .. dat3)
							else
								result = processData(proto_lower, base64Decode(dat[2]))
							end
						end
					else
						log('跳过未知类型: ' .. szType)
					end
					-- log(result)
					if result then
						-- 中文做地址的 也没有人拿中文域名搞，就算中文域也有Puny Code SB 机场
						if not result.server or not result.server_port or result.alias == "NULL" or check_filer(result) or result.server:match("[^0-9a-zA-Z%-_%.%s]") or cache[groupHash][result.hashkey] then
							log('丢弃无效节点: ' .. result.v2ray_protocol .. ' 节点, ' .. result.alias)
						else
							log('成功解析: ' .. result.v2ray_protocol ..' 节点, ' .. result.alias)
							result.grouphashkey = groupHash
							tinsert(nodeResult[index], result)
							cache[groupHash][result.hashkey] = nodeResult[index][#nodeResult[index]]
						end
					end
				end
				end
			log('成功解析节点数量: ' .. #nodes)
		else
			log(url .. ': 获取内容为空')
		end
	end
	-- diff
	do
		if next(nodeResult) == nil then
			log("更新失败，没有可用的节点信息")
			return
		end
		local add, del = 0, 0
		for k, v in ipairs(nodeResult) do
			for kk, vv in ipairs(v) do
				if not vv._ignore then
					os.execute("dbus set ssconf_basic_json_" .. ssrindex .. "=" .. b64encode(jsonStringify(vv)))
					os.execute("dbus set ssconf_basic_jsontype_" .. ssrindex .. "=" .. "1")
					os.execute("dbus set ssconf_basic_mode_" .. ssrindex .. "=" .. ssrmode)
					ssrindex = ssrindex +1
					add = add + 1
				end
			end
		end
		log('新增节点数量: ' .. add, '删除节点数量: ' .. del)
		log('订阅更新成功')
	end
--end
