ra.discord = ra.discord or {
  name = "ra_discord",
  token = "",
  discord_api = "https://discord.com/api/v9",
  window = nil,
  font_size = 12,
  last_message = 0,
  channel = "",
  wrap = true,
  current_toggle = "",
  buttons = {}, 
}

function ra.discord:create()
  if ra.discord_enabled and not self.window then
    self.window = scripts.ui.window:new(self.name, "Discord", self.wrap)
  end
  if self.window then
    self.window:set_font_size(self.font_size)
  end

  discord_data = discord_data or {}
  table.load(getMudletHomeDir() .. "/discord.lua", discord_data)

  self.token = discord_data.token
  self.channel = discord_data.channel

  ra.discord:get_last_message()

end

function ra.discord:set_token(token)
  data = {
    token = token,
    channel = self.channel
  }

  local location = getMudletHomeDir() .. "/discord.lua"
  table.save(location, data)

  echo(f"Token ustawiony na: " .. token .. "\n")

  self.token = token

  ra.discord:get_last_message()
end

function ra.discord:set_channel(channel)
  data = {
    token = self.token,
    channel = channel
  }

  local location = getMudletHomeDir() .. "/discord.lua"
  table.save(location, data)

  echo(f"Kanal ustawiony na: " .. channel .. "\n")

  self.channel = channel

  ra.discord:get_last_message()
end

function ra.discord:show_data()
  echo(f"Token: " .. self.token .. "\n")
  echo(f"Kanal: " .. self.channel .. "\n")
end

function ra.discord:send_message(message) 
  local url = self.discord_api .. "/channels/" .. self.channel .. "/messages"
  local data = { content = message }
  local header = {["Content-Type"] = "application/json", ["Authorization"] = self.token}

  -- success handling
  registerAnonymousEventHandler('sysPostHttpDone', function(event, rurl, response)
    if rurl == url then
      echo(f"Wiadomosc wyslana\n")
    else 
      return true 
    end
  end, true)

  -- error handling
  registerAnonymousEventHandler('sysPostHttpError', function(event, response, rurl)
    if rurl == url then 
      echo(f"Nie udalo sie wyslac wiadomosci\n")
    else 
      return true 
    end
  end, true)

  postHTTP(yajl.to_string(data), url, header)
end

function ra.discord:get_last_message()
  if not self.last_message or not self.channel then
    return false
  end

  local url = self.discord_api .. "/channels/" .. self.channel
  local header = {["Authorization"] = self.token}

  registerAnonymousEventHandler('sysGetHttpDone', 
    function(event, rurl, response)
      if rurl == url then 
        local channel = yajl.to_value(response)

        self.last_message = channel.last_message_id

        enableTimer("discord_timer")
      else 
        return true 
      end
    end, 
    true)

    getHTTP(url, header)

end

function reverseTable(t)
    local reversedTable = {}
    local length = #t
    for i = length, 1, -1 do
        table.insert(reversedTable, t[i])
    end
    return reversedTable
end

function ra.discord:get_messages()
  -- Set URL and headers
  local url = self.discord_api .. "/channels/" .. self.channel .. "/messages?after=".. self.last_message .."&limit=50"
  local header = {["Authorization"] = self.token}

  registerAnonymousEventHandler('sysGetHttpDone', 
    function(event, rurl, response)
      if rurl == url then 
        local messages = yajl.to_value(response)
        local last_message = 0

        messages = reverseTable(messages)

        for i,m in ipairs(messages) do
          -- Convert mentions to names
          local pattern = "<(@%d+)>"
          local message = m["content"]

          for mention in m["content"]:gmatch(pattern) do
              local id = mention:match("%d+")

              for i, men in ipairs(m["mentions"]) do
                if men["id"] == id then
                  message = string.gsub(message, "<" .. mention .. ">", "@" .. men["global_name"])
                end 
              end 
          end

          local display_name = m["author"]["global_name"]

          if type(m["author"]["global_name"]) ~= "string" then
            display_name = m["author"]["username"]
          end

          -- Display message
          cecho(self.name, "<white>"..display_name..": <green>"..message)

          -- Convert attachments to URLs
          local attachments = ""

          for i, attachment in ipairs(m["attachments"]) do
            cechoLink(self.name, "<red>[" .. attachment.content_type .. "]", function() openUrl(attachment.url) end, attachment.filename, true)
          end 

          -- Add new line
          cecho(self.name, "\n")

          -- Check last message id
          if m["id"] > self.last_message then
            self.last_message = m["id"]
          end
        end
      else 
        return true 
      end
    end, 
    true)

    getHTTP(url, header)

end

function ra.discord.refresh()
  ra.discord:get_messages()
end
