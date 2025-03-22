

return function(args)
  local node_type = args.node
  for i, node in ipairs(args.levelmanager.nodes) do
    if node.data.label == node_type then
      node.data.active = false
      node.data.controllable = false
      for _, neighbor in ipairs(node.neighbors) do
        if (neighbor.data.type == "goal") then
          node.lambda.abstain(neighbor)
        end
      end
      break
    end
  end
end
