local votebox = require("src.gameplay.vote.votebox")
local voteutils = require("src.gameplay.vote.voteutils")
local nodeobj = require("src.gameplay.nodeobj.node")

local votemanager = {}

function votemanager.retrieveallgoals(nodes)
  local newgoals = {}
    for _, node in ipairs(nodes) do
        if node.data.type == "goal" then
            table.insert(newgoals, node)
        end
    end
    return newgoals
end

function votemanager.retrieveallhearts(nodes)
  local newhearts = {}
  for _, node in ipairs(nodes) do
      if node.data.type == "heart" then
          table.insert(newhearts, node)
      end
  end
  return newhearts
end

function votemanager.retrieveallparticipants(nodes)
  local newparticipants = {}
   for _, node in ipairs(nodes) do
        if node.data.type ~= "goal" or node.data.type ~= "heart" then
            table.insert(newparticipants, node)
        end
    end
    return newparticipants
end

local function on_goal_complete(vm, goal, levelmanager)
  if (goal.data.on_complete ~= nil) then
    for _, to_complete in ipairs(goal.data.on_complete) do
      local func_name = to_complete.func
      local args = to_complete.args
      args.levelmanager = levelmanager
      args.votemanager = vm
      args.src = goal
      local result = nodeobj.completetion_functions[func_name](args)
      -- print(result.data.icon)
    end
  end
end

local function handlewinner(vm, votebox, levelmanager)
  local result = votebox:decideresult()
  if not votebox:isdraw() then
    if (votebox.goal.data.progress.max > votebox.goal.data.progress.current) then
      table.insert(votebox.goal.data.goal.winners, result)
    end
  else
      -- do something else here
  end
  votebox:resetvote()
  votebox.goal.data.progress.current = #votebox.goal.data.goal.winners
  if votebox.goal.data.progress.current == votebox.goal.data.progress.max then
    local votestorages = voteutils.initvotetypestorages()
    for _, winner in ipairs(votebox.goal.data.goal.winners) do
      for _, storage in pairs(votestorages) do
         if winner == storage.label then
              storage.count = storage.count + 1
          end
      end
    end
    local maxscore = 0
    for _, storage in pairs(votestorages) do
      if storage.progress and storage.count > maxscore then
          maxscore = storage.count
      end
    end
    local winners = {}
    for _, storage in pairs(votestorages) do
      if storage.progress and storage.count == maxscore then
          table.insert(winners, storage.label)
      end
    end
    if #winners == 1 then
      votebox.goal.data.goal.winner = winners[1]
      votebox.goal.data.goal.state = "decided"
      on_goal_complete(vm, votebox.goal, levelmanager)
    else
      local useddraw = ""
      local drawstorages = voteutils.initdrawstorages()
      for _, storage in pairs(drawstorages) do
        useddraw = storage.label
        break
      end
      votebox.goal.data.goal.winner = useddraw
    end
  end
end

function votemanager.new(levelmanager)
    local newVotemanager = {
        -- goals = {},
        voteboxes = {},
        levelmanager = levelmanager,
        decideresult = function(self, goal)
            for _, vb in ipairs(self.voteboxes) do
              if vb.goal == goal then
                  handlewinner(self, vb, self.levelmanager)
                  break
              end
            end
        end,
        decideallresult = function(self)
            for _, vb in ipairs(self.voteboxes) do
              handlewinner(self, vb, self.levelmanager)
            end
        end,
        addvotebox = function(self, goal)
          if goal~= nil then
            table.insert(self.voteboxes, votebox.new())
            self.voteboxes[#self.voteboxes].goal = goal
          end
        end,
        addvoteboxlist = function(self, goals)
          for _, goal in ipairs(goals) do
                self:addvotebox(goal)
            end
        end,
        startvote = function(self)
          for _, vb in ipairs(self.voteboxes) do
              for _, participant in ipairs(votemanager.retrieveallparticipants(self.levelmanager.nodes)) do
                if participant ~= nil then
                  local edge = participant:getedge(vb.goal)
                  if edge ~= nil then
                    participant.lambda.vote(vb, edge.label)
                  end
                end
              end
            end
        end,
        endvote = function(self)
          self:decideallresult()
        end
    }
    return newVotemanager
end

return votemanager
