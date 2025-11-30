local M = {}

function M.MoveToParent(close)
    return function(node, renderer)
        if node == renderer.tree then
            return
        end

        local parent = node.parent

        for i, line in ipairs(renderer.lines) do
            if parent ==  line.node then
                renderer.view.SetCursor({i, 0})
            end
        end

        if close and node ~= renderer.tree then
            parent.status = "closed"
            return true
        end
    end
end

function M.MoveToLastChild(node, renderer)
    local cur_node = nil

    if (node.ftype == "folder" or (node.ftype == "link" and node.link_type == "folder")) and node.status == "opened" then
        cur_node = node
    else
        cur_node = node.parent
    end

    local last = cur_node.nodes[#cur_node.nodes]

    for i, line in ipairs(renderer.lines) do
        if last == line.node then
            renderer.view.SetCursor({i, 0})
        end
    end
end

function M.MoveToNextSibling(node, renderer)
    if node == renderer.tree then
        return
    end

    local parent = node.parent
    local next_node = nil

    for i, _ in ipairs(parent.nodes) do
        if parent.nodes[i] == node then
            next_node = i == #parent.nodes and parent.nodes[1] or parent.nodes[i + 1]
            break
        end
    end

    for i, line in ipairs(renderer.lines) do
        if next_node == line.node then
            renderer.view.SetCursor({i, 0})
        end
    end
end

function M.MoveToPrevSibling(node, renderer)
    if node == renderer.tree then
        return
    end

    local parent = node.parent
    local prev_node = nil

    for i, _ in ipairs(parent.nodes) do
        if parent.nodes[i] == node then
            prev_node = i == 1 and parent.nodes[#parent.nodes] or parent.nodes[i - 1]
            break
        end
    end

    for i, line in ipairs(renderer.lines) do
        if prev_node == line.node then
            renderer.view.SetCursor({i, 0})
        end
    end
end

return M
