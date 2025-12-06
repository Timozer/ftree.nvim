local M = {}

function M.DirToggle(node)
    if not node or not node.nodes then
        return
    end

    if node.status == "opened" then
        node:Collapse()
    else
        node:Expand()
    end

    return true
end

function M.DirIn(node, renderer)
    folder_node = node:FindFolderNode()
    if folder_node.nodes ~= nil then
        folder_node:Expand()
        renderer.tree = folder_node
        vim.api.nvim_command("cd " .. folder_node.abs_path)

        return true
    end
    return false
end

function M.DirOut(node, renderer)
    local cur_tree = renderer.tree

    if cur_tree.parent == nil then
        local tree = require("ftree.node").New({
                abs_path = vim.fn.fnamemodify(cur_tree.abs_path, ":h"),
                ftype = "folder",
                status = "opened",
                nodes = { cur_tree }
            })
        cur_tree.parent = tree
    end

    renderer.tree = cur_tree.parent
    vim.api.nvim_command("cd " .. renderer.tree.abs_path)

    return true
end

return M
