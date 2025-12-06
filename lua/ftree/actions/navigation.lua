local M = {}

function M.MoveToParent(close)
    return function(node, renderer)
        return renderer:MoveToParent(node, close)
    end
end

function M.MoveToLastChild(node, renderer)
    return renderer:MoveToLastChild(node)
end

function M.MoveToNextSibling(node, renderer)
    return renderer:MoveToNextSibling(node)
end

function M.MoveToPrevSibling(node, renderer)
    return renderer:MoveToPrevSibling(node)
end

return M
