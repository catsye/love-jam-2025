local node = require("src.gameplay.nodeobj.node")
local goal = require("src.gameplay.goal.goal")

local goalnode = {}

-- data : x, y, label, icon, progress
function goalnode.new(data)
  local newgoal = goal.new(data.label, data.icon)
  local newnode = node.new(data.x, data.y, data.icon, data.label)
  newnode.data.type = "goal"
  newnode.data.goal = newgoal
  newnode.data.progress = data.progress
  newnode.data.maxlength = data.maxlength
  newnode.data.on_complete = data.on_complete
  newnode.data.on_connect = data.on_connect
  newnode.data.on_vote = data.on_vote
  newnode.data.is_optional = data.is_optional

  local lambda = {
  }
  newnode.data.lambda = lambda
  return newnode
end

return goalnode
