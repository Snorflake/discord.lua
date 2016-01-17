-- This code is licensed under the MIT Open Source License.

-- Copyright (c) 2015 Ruairidh Carmichael - ruairidhcarmichael@live.co.uk

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

-------------------------------------
-- Discord Client Class
-- @module Client

local path = (...):match('(.-)[^%.]+$')

local request = require(path .. 'wrapper')

local class = require(path .. 'class')
local json = require(path .. 'json')
local endpoints = require(path .. 'endpoints')
local util = require(path .. 'utils')

local Message = require(path .. 'message')

print('Loaded client')

local Client = class('ClientObject')
local DS = require(path .. "datastore")

--WEBSOCKET
local ev = require'ev'
local ws_client = require('websocket.client').ev()



--- Internally initialize's the Client class.
--- Please use Client:new(options) instead.
-- @param options Options table (Currently useless.)
function Client:initialize(options)

	self.isLoggedIn = false
	self.options = options
	self.token = ''
	self.email = ''
	self.user = {}

	self.headers = {}

	self.headers['authorization'] = self.token
	self.headers['Content-Type'] = 'application/json'

	self.callbacks = {}

	self.socket = nil

end

--- Logs the Client into Discord's servers.
--- This is required to use most of the Clients functions.
-- @param email E-mail Address of the account to log in.
-- @param password Password of the account to log in.
-- (WARNING: Do NOT store this password in a GitHub repo or anything of the sorts.)
-- @return True or False depending on success.
function Client:login(email, password)

	local payload = {
		email = email,
		password = password
	}

	local response = request.send(endpoints.login, 'POST', payload, self.headers)
	local success = util.responseIsSuccessful(response)

	if success then

		self.token = json.decode(response.body).token
		self.isLoggedIn = true
		self.headers['authorization'] = self.token
		self.email = email

		self.user = self:getCurrentUser()

	end

	return self.token

end

function Client:loginWithToken(token)

	self.token = token
	self.isLoggedIn = true
	self.headers['authorization'] = self.token

	self.user = self:getCurrentUser()

end

--- Logs the Client out of the Discord server.
-- @return True or False depending on success.
function Client:logout()

	if self.isLoggedIn then

		local payload = {
			token = self.token
		}

		local response = request.send(endpoints.logout, 'POST', payload, self.headers)
		local success = util.responseIsSuccessful(response)

		if success then
			self.isLoggedIn = false
			self.token = nil
		end

		return success

	else
		return false
	end

end

--- Gets the current authentication token.
--- (Only if logged in of course.)
-- @return Authentication Token
function Client:getToken()

	if self.isLoggedIn then
		return self.token
	else
		return nil
	end

end

--- Gets the current Gateway we are connected to.
--- (Only if logged in of course.)
-- @return Gateway URL
function Client:getGateway()

	if self.isLoggedIn then

		local response = request.send(endpoints.gateway, 'GET', nil, self.headers)

		if util.responseIsSuccessful(response) then
			return json.decode(response.body).url
		else
			return nil
		end

	end

end

--- Gets the current User information.
--- (Only if logged in of course.)
-- @return User Table
function Client:getCurrentUser()

	if self.isLoggedIn then

		local response = request.send(endpoints.users .. '/@me', 'GET', nil, self.headers)

		if util.responseIsSuccessful(response) then
			return json.decode(response.body)
		else
			return nil
		end

	else
		return nil
	end

end

--- Gets a table of Servers the current User is connected to.
--- (Only if logged in of course.)
-- @return Server Table
function Client:getServerList()

	if self.isLoggedIn then

		local response = request.send(endpoints.users .. '/@me/guilds', 'GET', nil, self.headers)

		if util.responseIsSuccessful(response) then
			self.user = json.decode(response.body)
			return json.decode(response.body)
		else
			return nil
		end

	else
		return nil
	end

end

--- Gets a table of Channels from the provided Server id.
--- (Only if logged in of course.)
-- @param id Server ID
-- @return Channel Table
function Client:getChannelList(id)

	if self.isLoggedIn then

		local response = request.send(endpoints.servers .. '/' .. id .. '/channels', 'GET', nil, self.headers)

		if util.responseIsSuccessful(response) then
			return json.decode(response.body)
		else
			return nil
		end

	else
		return nil
	end

end

--- Sends a Message from the Client to a Channel.
--- (Only if logged in of course.)
-- @param message Message to be sent.
-- @param id ID for Channel to send to.
-- @return Message Class
function Client:sendMessage(message, id)

	if self.isLoggedIn then

		local payload = {
			content = tostring(message)
		}

		local response = request.send(endpoints.channels .. '/' .. id .. '/messages', 'POST', payload, self.headers)

		return Message:new(json.decode(response.body), self.token)

	else
		return nil
	end

end

--- Edits a sent Message.
--- (Only if logged in of course.)
-- @param message The new message to replace the old one.
-- @param msgClass Message Class to edit.
-- @return Message Class
function Client:editMessage(message, msgClass)

	if self.isLoggedIn then

		msgClass:edit(message)

	end

end

--- Deletes a sent Message.
--- (Only if logged in of course.)
-- @param msgClass Message Class to delete.
-- @return Message Class
function Client:deleteMessage(msgClass)

	if self.isLoggedIn then

		msgClass:delete()

	end

end

function Client:acceptInvite(id)
	if self.isLoggedIn then
		print(id,endpoints.invites .. "/" .. id)
		local result = request.send(endpoints.invites .. "/" .. id, "POST", nil, self.headers)
		for k, v in pairs(result) do print(k, v) end
	
	end
end

function Client:leaveGuild(id)
	if self.isLoggedIn then
		request.send(endpoints.servers .. "/" .. id, "DELETE", nil, self.headers)
	end
end

function Client:getMessages(id, limit)
	if self.isLoggedIn then	
		--function requestWrapper.send(endpoint, method, data, headers)
		local response = nil
		if limit then
		response = request.send(endpoints.channels .. "/" .. id .. "/messages?limit=" .. limit, "GET", nil, self.headers) else
		response = request.send(endpoints.channels .. "/" .. id .. "/messages", "GET", nil, self.headers) end
		local tbl = {}
		for k, v in pairs(json.decode(response.body)) do 
			tbl[k] = Message:new(v, self.token) 
		end
		
		return tbl
	end
end



local heartbeat = -1
local wstoken = -1
local clientinstance = nil

local function keepalive()
	ws_client:send(json.encode({ op = 1, d = os.time() * 1000 }))
	--print("sent keepalive!")
end

local function handle_ready(tbl)
	heartbeat = tbl.d.heartbeat_interval / 1000
	print("Heartbeat interval: " .. heartbeat)


		ev.Timer.new(function()
				keepalive()
		end,heartbeat,heartbeat):start(ev.Loop.default)
		
		clientinstance.pms = DS.fromList(tbl.d.private_channels, 'id', 'recipient.id')
		
		clientinstance.guildChannelLookup = {}
		clientinstance.guilds = tbl.d.guilds
		for i  = 1, #clientinstance.guilds do
			local g = clientinstance.guilds[i]
			
			for i=1, #g.channels do
				clientinstance.guildChannelLookup[g.channels[i].id] = g.id
			end
			
			g.channels = DS.fromList(g.channels, "id", "name")
			g.members = DS.fromList(g.members, "user.id", "user.username")
			g.roles = DS.fromList(g.roles,"id", "name")
		end
		clientinstance.guilds = DS.fromList(clientinstance.guilds, "id", "name")

end


--I lioke the way luv-discord handles events so imma steal it
local function noop() end
local function popGuild(d)
	local guild = clientinstance.guilds[d.guild_id]
	d.guild_id = nil
	return guild
end

local events =
{
	READY = noop,
	
	MESSAGE_CREATE = function(d) if clientinstance.on_message then  clientinstance.on_message(d.channel_id, d.author.id, d.author.username, d.content) end end,
	
	PRESENCE_UPDATE = noop,
	USER_UPDATE = noop,
	GUILD_CREATE = noop,
	GUILD_DELETE = noop,
	
	CHANNEL_CREATE = function(d)
		local channels = d.is_private and clientinstance.pms or popGuild(d).channels
		DS.add(channels, d)
	end,
	CHANNEL_UPDATE = function(d)
		local channels = d.is_private and clientinstance.pms or popGuild(d).channels
		DS.update(channels, d.id, d)
	end,	
	CHANNEL_DELETE = function(d)
		local channels = d.is_private and clientinstance.pms or popGuild(d).channels
		DS.remove(channels, d.id)
	end,
	
	GUILD_MEMBER_ADD = function(d)
		local members = popGuild(d).members
		DS.add(members,d)
	end,	
	GUILD_MEMBER_UPDATE = function(d)
		local members = popGuild(d).members
		DS.add(members,d.user.id, d)
	end,	
	GUILD_MEMBER_DELETE = function(d)
		local members = popGuild(d).members
		DS.add(members,d.user.id)
	end,
	GUILD_ROLE_CREATE = function(d)
		local members = popGuild(d).roles
		DS.add(members,d.role)
	end,
	GUILD_ROLE_UPDATE = function(d)
		local members = popGuild(d).roles
		DS.update(members,d.role.id, d.role)
	end,
	GUILD_ROLE_DELETE = function(d)
		local members = popGuild(d).roles
		DS.add(members,d.role_id)
	end,
	
}


ws_client:on_message(function(ws, msg)
	local result = json.decode(msg)
	if(result.t == "READY") then handle_ready(result) end
	if result.d and events[result.t] then events[result.t](result.d) end
end)

ws_client:on_open(function()
	print("WS CONNECTED!")
	local payload = json.encode({
		op = 2,
		d = 
		{
			v = 3,
			token = wstoken,
			properties =
			{
				["$os"] = require('ffi').os,
				["$browser"] = "",
				["$device"] = "",
				["$referrer"] = "",
				["$referring_domain"] = ""
			}
		}
	})
	ws_client:send(payload)
end)


--- Starts the Client loop.
function Client:run()

	if self.isLoggedIn then
		clientinstance = self
		local gateway = self:getGateway()
		gateway = gateway:gsub("wss", "ws")
		print("Logged in as " .. self:getCurrentUser().username)
		wstoken = self.token
		ws_client:connect(gateway)
		
		
		ev.Loop.default:loop()
	else
		print("WARNING: TRIED TO EXECUTE run() WITHOUT BEING LOGGED IN")
	end

end



return Client