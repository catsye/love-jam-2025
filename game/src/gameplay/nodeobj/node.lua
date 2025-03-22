local graph = require("src.data.graph")
local nodeconverter = require("src.gameplay.nodeobj.nodeconverter.nodeconverter")
local nodedisabler = require("src.gameplay.nodeobj.nodedisabler.nodedisabler")
local sfxplayer = require("src.audio.sfxplayer")

local node = {}

function node.new(x, y, icon, label)
  local newnode = graph.node{
    x = x,
    y = y,
    icon = icon,
    label = label,
  }
  return newnode
end

node.completetion_functions = {
  convert_to = nodeconverter,
  play_sfx = sfxplayer,
  disable_node = nodedisabler,
}

node.connect_functions = {
  play_sfx = sfxplayer
}

node.vote_functions = {
  play_sfx = sfxplayer
}

return node
