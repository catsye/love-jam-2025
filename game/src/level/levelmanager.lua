local votemanager        = require("src.gameplay.vote.votemanager")
local graph              = require("src.data.graph")
local distancecalculator = require("src.data.distance")
local grid               = require("src.data.grid")
local characternode      = require("src.gameplay.character.characternode")
local goalnode           = require("src.gameplay.goal.goalnode")
local levelserializer    = require("src.level.levelserializer")
local icons              = require("assets.icons")
local audiomanager       = require("src.audio.audiomanager")
local heartnode          = require("src.gameplay.heart.heartnode")

local levelmanager = {}
local currentgoals = {}
local currenthearts = {}
local currentparticipants = {}
local currentvotemanager = {}
local turncount = 0
local levels = {}
local levels_directory = 'assets/levels'

local function level_path_from_index(index)
  return string.format('assets/levels/level%s.json', index)
end

-- returning a string and then calling error helps diagnostics know that error was called
local function load_level_error(level_index, message)
  return string.format("Failed to load level, %s: %s", message, level_path_from_index(level_index))
end

local function load_level_files()
  local files = love.filesystem.getDirectoryItems(levels_directory)
  for _, file in ipairs(files) do
    local index_str = string.gsub(file, ".*(%d+).*", "%1")
    local index = tonumber(index_str)
    local path = string.format("%s/%s", levels_directory, file)
    print(string.format("loading level: %s, from: %s", index, path))
    levels[index] = levelserializer.read_from_json(path)
  end
end

function levelmanager.init()
  levelmanager.nodes = {}
  levelmanager.currentlevelname = "No Level Loaded"
  levelmanager.grid = grid.new(60)
  load_level_files()
end

local function create_player_node(info)
  local worldx, worldy = levelmanager.grid:gridToWorldCoords(info.grid_x, info.grid_y)
  return characternode.new{
    x = worldx,
    y = worldy,
    icon = icons.player,
    label = "player",
    active = true,
    maxlength = 1,
    controllable = true
  }
end

local function create_character_node(info)
  return characternode.new{
    x = info.x,
    y = info.y,
    icon = icons[info.icon],
    label = info.label,
    active = info.active,
    maxlength = info.maxlength,
  }
end

local function create_goal_node(info)
  return goalnode.new{
    x = info.x,
    y = info.y,
    icon = icons[info.icon],
    label = info.label,
    progress = {max = info.progress_quota, current = 0},
    maxlength = info.maxlength,
    on_complete = info.on_complete,
    on_connect = info.on_connect,
    on_vote = info.on_vote,
    is_optional = info.is_optional
  }
end

local function create_heart_node(info)
  return heartnode.new{
    x = info.x,
    y = info.y,
    icon = icons.object[info.icon],
    label = info.label,
    progress = {max = info.progress_quota, current = 0},
    maxlength = info.maxlength,
    on_complete = info.on_complete,
    on_connect = info.on_connect,
    on_vote = info.on_vote,
    char_owner = info.char_owner
  }
end

local function init_levelmanager_info(index, name)
  levelmanager.nodes = {}
  levelmanager.currentlevel = index
  levelmanager.turncount = 0
  levelmanager.currentlevelname = name
end

local function convert_info_coords(info)
  info.x, info.y = levelmanager.grid:gridToWorldCoords(info.grid_x, info.grid_y)
end

local function load_nodes(level_info_node_map, loaded_node_map, builder)
  for name, info in pairs(level_info_node_map) do
    convert_info_coords(info)
    local node = builder(info)
    if loaded_node_map[name] ~= nil then
      error(load_level_error("node names must be unique, found duplicate[" .. name .."]"))
    end
    table.insert(levelmanager.nodes, node)
    loaded_node_map[name] = node
  end
end

function levelmanager.on_load(index)
  audiomanager.play_sfx("next_level")
end

function levelmanager.load(index)
  print("Loading Level " .. index)
  levelmanager.on_load(index)

  -- grab level info from table, preferably this is verified to exist
  -- and is validat load time
  print(#levels)
  local levelinfo = levels[index]
  init_levelmanager_info(index, levelinfo.name)

  -- used to build existing connections and enforce unique names
  local loaded_node_map = {}

  -- create player
  local player = create_player_node(levelinfo.player_location)
  loaded_node_map["player"] = player
  table.insert(levelmanager.nodes, player)

  -- load nodes
  load_nodes(levelinfo.characters, loaded_node_map, create_character_node)
  load_nodes(levelinfo.goals, loaded_node_map, create_goal_node)
  -- load_nodes(levelinfo.heart, loaded_node_map, create_heart_node)

  -- create exiting connections
  if levelinfo.connections ~= nil then
    print("Creating existing connections")
    for name, node in pairs(loaded_node_map) do
      if levelinfo.connections[name] ~= nil then
        local side = levelinfo.connections[name].side
        local targetname = levelinfo.connections[name].nodes
        for _, target in ipairs(targetname) do
          local length = distancecalculator.worldToGridDistance(levelmanager.grid, node.data.x, node.data.y, loaded_node_map[target].data.x, loaded_node_map[target].data.y)
          print("connection distance ", length)
          node.lambda.pick_side(loaded_node_map[target], side, length)
        end
      end
    end
  end

  -- setup votemanager
  levelmanager.setupvotemanager(false)

  print("Level loaded successfully")
end

function levelmanager.setupvotemanager(is_re_setup)
  currentgoals = votemanager.retrieveallgoals(levelmanager.nodes)
  -- currenthearts = votemanager.retrieveallhearts(levelmanager.nodes)
  currentparticipants = votemanager.retrieveallparticipants(levelmanager.nodes)
  if not (is_re_setup) then
    currentvotemanager = votemanager.new(levelmanager)
  end
  currentvotemanager:addvoteboxlist(currentgoals)
end

function levelmanager.progressvote()
  turncount = turncount + 1
  print("Start vote turn ", turncount)
  if not levelmanager.islevelcompleted() then
    currentvotemanager:startvote(currentparticipants, currentgoals)
    currentvotemanager:endvote()
  end
end

function levelmanager.islevelcompleted()
  if currentgoals == nil or #currentgoals == 0 then
    return true
  else
    local foundunfinishedgoal = false
    for _, goal in ipairs(currentgoals) do
      if goal.data.goal.state ~= "decided" then
        foundunfinishedgoal = true
        break
      end
    end
    return not foundunfinishedgoal
  end
end

function levelmanager.islevelwin()
  local foundfailuregoal = false
  for _, goal in ipairs(currentgoals) do
    if not goal.data.is_optional then
      if goal.data.goal.state ~= "decided" then
        foundfailuregoal = true
      elseif goal.data.goal.winner == "oppose" then
        foundfailuregoal = true
        print("========WINNER : ", goal.data.goal.winner)
      end
    end
    print("WINNER : ", goal.data.goal.winner)
    if (foundfailuregoal) then
      break
    end
  end
  return not foundfailuregoal
end

function levelmanager.checklevelprogress()
  local islevelstillinprogress = true
  if levelmanager.islevelcompleted() then
    print("Level completed!")
    islevelstillinprogress = false
    if levelmanager.islevelwin() then
      print("Level successed!")
      levelmanager.loadnextlevel()
    else
      print("Level failed!")
      levelmanager.restartlevel()
    end
  else
    print("Level in progress...")
  end
  return islevelstillinprogress
end

function levelmanager.restartlevel()
  if levelmanager.currentlevel == nil then
    error("No level loaded")
  else
    print("restarting")
    levelmanager.load(levelmanager.currentlevel)
  end
end

function levelmanager.all_levels_completed()
  return levelmanager.currentlevel > #levels and levelmanager.islevelcompleted()
end

function levelmanager.loadnextlevel()
  if levelmanager.islevelcompleted() and not levelmanager.all_levels_completed() then
    levelmanager.load(levelmanager.currentlevel + 1)
  end
end

function levelmanager.printlevel()
  print("Current Level: " .. levelmanager.currentlevel)
  print("Level Name: " .. levelmanager.currentlevelname)
end

function levelmanager.collectEdges()
  local edges = {}
  local visited = graph.visitedSet()
  for _, node in ipairs(levelmanager.nodes) do
    if not visited:contains(node) then
      graph.traverse{node, onVisit = function (node)
        for _, neighbor in ipairs(node.neighbors) do
          if not visited:contains(neighbor) then
            table.insert(edges, graph.edge(node, neighbor))
          end
        end
      end}
    end
  end
  return edges
end

return levelmanager
