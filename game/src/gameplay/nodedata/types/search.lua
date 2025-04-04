local node_data = require("src.gameplay.nodedata.base")
local components = require("src.gameplay.nodedata.components")
local icons      = require("assets.icons")
local audiomanager = require("src.audio.audiomanager")

local type_name = "search"

return function (owner, params)
  local search = node_data(type_name, owner, params.x, params.y)
  search:addComponent(
    components.progressable,
    {
      quota = params.quota,
      on_connect = function (self)
        audiomanager.play_sfx("connect")
      end,
      on_progress = function (self)
        audiomanager.play_sfx("progress")
      end,
      on_complete = function (self, levelmanager, winner)
        audiomanager.play_sfx("door")
        local node_data = self.owner
        levelmanager.create_node({
          type = "path",
          x = node_data.x,
          y = node_data.y,
          vote_side = winner
        })
        levelmanager.remove_node(node_data.owner)
      end
    }
  )
  search:addComponent(
    components.display,
    {
      icon = icons.search,
      label = params.label or type_name
    }
  )
  return search
end
