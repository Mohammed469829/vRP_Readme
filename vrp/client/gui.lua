
-- pause
AddEventHandler("vRP:pauseChange", function(paused)
  SendNUIMessage({act="pause_change", paused=paused})
end)

-- MENU

function tvRP.openMenuData(menudata)
  SendNUIMessage({act="open_menu", menudata = menudata})
end

function tvRP.closeMenu()
  SendNUIMessage({act="close_menu"})
end

-- PROMPT

function tvRP.prompt(title,default_text)
  SendNUIMessage({act="prompt",title=title,text=tostring(default_text)})
  SetNuiFocus(true)
end

-- REQUEST

function tvRP.request(id,text,time)
  SendNUIMessage({act="request",id=id,text=tostring(text),time = time})
  tvRP.playSound("HUD_MINI_GAME_SOUNDSET","5_SEC_WARNING")
end

-- gui menu events
RegisterNUICallback("menu",function(data,cb)
  if data.act == "close" then
    vRPserver._closeMenu(data.id)
  elseif data.act == "valid" then
    vRPserver._validMenuChoice(data.id,data.choice,data.mod)
  end
end)

-- gui prompt event
RegisterNUICallback("prompt",function(data,cb)
  if data.act == "close" then
    SetNuiFocus(false)
    SetNuiFocus(false)
    vRPserver._promptResult(data.result)
  end
end)

-- gui request event
RegisterNUICallback("request",function(data,cb)
  if data.act == "response" then
    vRPserver._requestResult(data.id,data.ok)
  end
end)

-- ANNOUNCE

-- add an announce to the queue
-- background: image url (800x150)
-- content: announce html content
function tvRP.announce(background,content)
  SendNUIMessage({act="announce",background=background,content=content})
end

-- cfg
RegisterNUICallback("cfg",function(data,cb) -- if NUI loaded after
  SendNUIMessage({act="cfg",cfg=cfg.gui})
end)
SendNUIMessage({act="cfg",cfg=cfg.gui}) -- if NUI loaded before

-- try to fix missing cfg issue (cf: https://github.com/ImagicTheCat/vRP/issues/89)
for i=1,5 do
  SetTimeout(5000*i, function() SendNUIMessage({act="cfg",cfg=cfg.gui}) end)
end

-- PROGRESS BAR

-- create/update a progress bar
function tvRP.setProgressBar(name,anchor,text,r,g,b,value)
  local pbar = {name=name,anchor=anchor,text=text,r=r,g=g,b=b,value=value}

  -- default values
  if pbar.value == nil then pbar.value = 0 end

  SendNUIMessage({act="set_pbar",pbar = pbar})
end

-- set progress bar value in percent
function tvRP.setProgressBarValue(name,value)
  SendNUIMessage({act="set_pbar_val", name = name, value = value})
end

-- set progress bar text
function tvRP.setProgressBarText(name,text)
  SendNUIMessage({act="set_pbar_text", name = name, text = text})
end

-- remove a progress bar
function tvRP.removeProgressBar(name)
  SendNUIMessage({act="remove_pbar", name = name})
end

-- DIV

-- set a div
-- css: plain global css, the div class is "div_name"
-- content: html content of the div
function tvRP.setDiv(name,css,content)
  SendNUIMessage({act="set_div", name = name, css = css, content = content})
end

-- set the div css
function tvRP.setDivCss(name,css)
  SendNUIMessage({act="set_div_css", name = name, css = css})
end

-- set the div content
function tvRP.setDivContent(name,content)
  SendNUIMessage({act="set_div_content", name = name, content = content})
end

-- execute js for the div
-- js variables: this is the div
function tvRP.divExecuteJS(name,js)
  SendNUIMessage({act="div_execjs", name = name, js = js})
end

-- remove the div
function tvRP.removeDiv(name)
  SendNUIMessage({act="remove_div", name = name})
end

-- AUDIO

-- play audio source (once)
--- url: valid audio HTML url (ex: .ogg/.wav/direct ogg-stream url)
--- volume: 0-1 
--- x,y,z: position (omit for unspatialized)
--- max_dist  (omit for unspatialized)
function tvRP.playAudioSource(url, volume, x, y, z, max_dist)
  SendNUIMessage({act="play_audio_source", url = url, x = x, y = y, z = z, volume = volume, max_dist = max_dist})
end

-- set named audio source (looping)
--- name: source name
--- url: valid audio HTML url (ex: .ogg/.wav/direct ogg-stream url)
--- volume: 0-1 
--- x,y,z: position (omit for unspatialized)
--- max_dist  (omit for unspatialized)
function tvRP.setAudioSource(name, url, volume, x, y, z, max_dist)
  SendNUIMessage({act="set_audio_source", name = name, url = url, x = x, y = y, z = z, volume = volume, max_dist = max_dist})
end

-- remove named audio source
function tvRP.removeAudioSource(name)
  SendNUIMessage({act="remove_audio_source", name = name})
end

local listener_wait = math.ceil(1/cfg.audio_listener_rate)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(listener_wait)

    local x,y,z = table.unpack(GetGameplayCamCoord())
    local fx,fy,fz = tvRP.getCamDirection()
    SendNUIMessage({act="audio_listener", x = x, y = y, z = z, fx = fx, fy = fy, fz = fz})
  end
end)

-- VoIP

local channel_callbacks = {}
local voice_channels = {}

-- request connection to another player for a specific channel
function tvRP.connectVoice(channel, player)
  SendNUIMessage({act="connect_voice", channel=channel, player=player})
end

-- disconnect from another player for a specific channel
function tvRP.disconnectVoice(channel, player)
  SendNUIMessage({act="disconnect_voice", channel=channel, player=player})
end

-- register callbacks for a specific channel
--- on_offer(player): should return true to accept the connection
--- on_connect(player, is_origin): is_origin is true if it's the local peer (not an answer)
--- on_disconnect(player)
function tvRP.registerVoiceCallbacks(channel, on_offer, on_connect, on_disconnect)
  channel_callbacks[channel] = {on_request, on_connect, on_disconnect}
end

-- check if there is an active connection
function tvRP.isVoiceConnected(channel, player)
  local channel = voice_channels[channel]
  if channel then
    return channel[player]
  end
end

-- return connections (map of channel => map of player => true)
function tvRP.getVoiceChannels()
  return voice_channels
end

-- enable/disable speaking
--- player: nil to affect all channel peers
--- active: true/false 
function tvRP.setVoiceState(channel, player, active)
  SendNUIMessage({act="set_voice_state", channel=channel, player=player, active=active})
end

-- configure channel connections
--- config:
---- effect: nil/"radio"
---- spatialized: true/false
function tvRP.configureVoice(channel, config)
  SendNUIMessage({act="configure_voice", channel=channel, config=config})
end

RegisterNUICallback("audio",function(data,cb)
  if data.act == "voice_connected" then
    -- register channel/player
    local channel = voice_channels[data.channel]
    if not channel then
      channel = {}
      voice_channels[data.channel] = channel
    end
    channel[data.player] = true

    -- callback
    local cbs = channel_callbacks[data.channel]
    if cbs then
      local cb = cbs[2]
      if cb then cb(data.player, data.origin) end
    end
  elseif data.act == "voice_disconnected" then
    -- unregister channel/player
    local channel = voice_channels[data.channel]
    if channel then
      channel[data.player] = nil
    end

    -- callback
    local cbs = channel_callbacks[data.channel]
    if cbs then
      local cb = cbs[3]
      if cb then cb(data.player) end
    end
  elseif data.act == "voice_peer_signal" then
    vRPserver._signalVoicePeer(data.player, data.data)
  end
end)

function tvRP.signalVoicePeer(player, data)
  if data.sdp_offer then -- check offer
    local cbs = channel_callbacks[data.channel]
    if cbs then
      local cb = cbs[1]
      if cb and cb(data.player) then
        SendNUIMessage({act="voice_peer_signal", player=player, data=data})
      end
    end
  else -- other signal
    SendNUIMessage({act="voice_peer_signal", player=player, data=data})
  end
end

--test
SetTimeout(5000, function()
  tvRP.registerVoiceCallbacks("test", function(player)
    print("(vRPvoice) requested by "..player)
    return true
  end,
  function(player, is_origin)
    print("(vRPvoice) connected to "..player)
    if is_origin then
      SetTimeout(10000, function() 
        tvRP.disconnectVoice("test", player)
      end)
    end
  end,
  function(player)
    print("(vRPvoice) disconnected from "..player)
  end)

  tvRP.connectVoice("test", GetPlayerServerId(PlayerId()))
end)

-- CONTROLS/GUI

local paused = false

function tvRP.isPaused()
  return paused
end

-- gui controls (from cellphone)
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    -- menu controls
    if IsControlJustPressed(table.unpack(cfg.controls.phone.up)) then SendNUIMessage({act="event",event="UP"}) end
    if IsControlJustPressed(table.unpack(cfg.controls.phone.down)) then SendNUIMessage({act="event",event="DOWN"}) end
    if IsControlJustPressed(table.unpack(cfg.controls.phone.left)) then SendNUIMessage({act="event",event="LEFT"}) end
    if IsControlJustPressed(table.unpack(cfg.controls.phone.right)) then SendNUIMessage({act="event",event="RIGHT"}) end
    if IsControlJustPressed(table.unpack(cfg.controls.phone.select)) then SendNUIMessage({act="event",event="SELECT"}) end
    if IsControlJustPressed(table.unpack(cfg.controls.phone.cancel)) then SendNUIMessage({act="event",event="CANCEL"}) end

    -- open general menu
    if IsControlJustPressed(table.unpack(cfg.controls.phone.open)) and (not tvRP.isInComa() or not cfg.coma_disable_menu) and (not tvRP.isHandcuffed() or not cfg.handcuff_disable_menu) then vRPserver._openMainMenu() end

    -- F5,F6 (default: control michael, control franklin)
    if IsControlJustPressed(table.unpack(cfg.controls.request.yes)) then SendNUIMessage({act="event",event="F5"}) end
    if IsControlJustPressed(table.unpack(cfg.controls.request.no)) then SendNUIMessage({act="event",event="F6"}) end

    -- pause events
    local pause_menu = IsPauseMenuActive()
    if pause_menu and not paused then
      paused = true
      TriggerEvent("vRP:pauseChange", paused)
    elseif not pause_menu and paused then
      paused = false
      TriggerEvent("vRP:pauseChange", paused)
    end
  end
end)

