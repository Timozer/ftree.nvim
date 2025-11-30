local utils = require("ftree.utils")
local icons = require("ftree.icons")

local M = {
    instances = {}, -- 每个 tab 的实例
    default_opts = nil, -- 存储默认选项
}

local function get_instance()
    local tabpage = vim.api.nvim_get_current_tabpage()
    if not M.instances[tabpage] then
        M.instances[tabpage] = {
            lines = {},
            view = M.default_opts and M.default_opts.view or nil,
            tree = M.default_opts and M.default_opts.tree or nil,
            gitstatus = nil,
            filter = nil,
            keymaps = M.default_opts and M.default_opts.keymaps or nil,
        }
    end
    return M.instances[tabpage]
end

function M._RefreshGitStatus()
    local instance = get_instance()
    instance.gitstatus = nil
    local ret = require("ftree.git").Status(instance.tree.abs_path)
    if ret.result == "success" then
        instance.gitstatus = ret.data
    end
end

function M._RefreshLines()
    local instance = get_instance()
    err = M.GetTreeContext(instance.tree, 0)
    if err then
        -- TODO:
        require("ftree.utils").Notify("[FTree] Error: " .. vim.inspect(err), vim.log.levels.ERROR)
        return
    end
end

function M.GetRenderContext()
    local instance = get_instance()
    local lines = {}
    local highlights = {}
    for i, item in ipairs(instance.lines) do
        table.insert(lines, item.line)
        for _, highlight in pairs(item.highlights) do
            highlight[2] = i - 1
            table.insert(highlights, highlight)
        end
    end
    return lines, highlights
end

function M.Draw()
    local instance = get_instance()
    if not instance.tree or not instance.view or not instance.view.Visable() then
        return
    end

    instance.lines = {}
    instance.highlights = {}

    M._RefreshGitStatus()
    M._RefreshLines()

    local lines, highlights = M.GetRenderContext()
    instance.view.Update(lines, highlights, instance.keymaps['tree'])
end

function M.GetNodeIcon(node)
    local icon = " "
    local hl = ""
    if node.ftype == "file" then
        icon, hl = icons.GetIcon(node.name)
    elseif node.ftype == "folder" then
        icon = node.status == "closed" and "" or ""
        hl = node.status == "closed" and "FTreeFolderClosed" or "FTreeFolderOpened"
    elseif node.ftype == "link" then
        icon = node.link_type == "folder" and "" or ""
        hl = node.link_type == "folder" and "FTreeSymlinkFolder" or "FTreeSymlinkFile"
    end
    return icon, hl
end

-- local gitIcons = {
--     ["M "] = { { "[M]", "FTreeGitStaged" } },
--     [" M"] = { { "[M]", "FTreeGitModified" } },
--     ["C "] = { { icon = i.staged, hl = "NvimTreeGitStaged" } },
--     [" C"] = { { icon = i.unstaged, hl = "NvimTreeGitDirty" } },
--     ["CM"] = { { icon = i.unstaged, hl = "NvimTreeGitDirty" } },
--     [" T"] = { { icon = i.unstaged, hl = "NvimTreeGitDirty" } },
--     ["T "] = { { icon = i.staged, hl = "NvimTreeGitStaged" } },
--     ["MM"] = {
--         { icon = i.staged, hl = "NvimTreeGitStaged" },
--         { icon = i.unstaged, hl = "NvimTreeGitDirty" },
--     },
--     ["MD"] = {
--         { icon = i.staged, hl = "NvimTreeGitStaged" },
--     },
--     ["A "] = {
--         { icon = i.staged, hl = "NvimTreeGitStaged" },
--     },
--     ["AD"] = {
--         { icon = i.staged, hl = "NvimTreeGitStaged" },
--     },
--     [" A"] = {
--         { icon = i.untracked, hl = "NvimTreeGitNew" },
--     },
--     -- not sure about this one
--     ["AA"] = {
--         { icon = i.unmerged, hl = "NvimTreeGitMerge" },
--         { icon = i.untracked, hl = "NvimTreeGitNew" },
--     },
--     ["AU"] = {
--         { icon = i.unmerged, hl = "NvimTreeGitMerge" },
--         { icon = i.untracked, hl = "NvimTreeGitNew" },
--     },
--     ["AM"] = {
--         { icon = i.staged, hl = "NvimTreeGitStaged" },
--         { icon = i.unstaged, hl = "NvimTreeGitDirty" },
--     },
--     ["??"] = { { icon = i.untracked, hl = "NvimTreeGitNew" } },
--     ["R "] = { { icon = i.renamed, hl = "NvimTreeGitRenamed" } },
--     [" R"] = { { icon = i.renamed, hl = "NvimTreeGitRenamed" } },
--     ["RM"] = {
--         { icon = i.unstaged, hl = "NvimTreeGitDirty" },
--         { icon = i.renamed, hl = "NvimTreeGitRenamed" },
--     },
--     ["UU"] = { { icon = i.unmerged, hl = "NvimTreeGitMerge" } },
--     ["UD"] = { { icon = i.unmerged, hl = "NvimTreeGitMerge" } },
--     ["UA"] = { { icon = i.unmerged, hl = "NvimTreeGitMerge" } },
--     [" D"] = { { icon = i.deleted, hl = "NvimTreeGitDeleted" } },
--     ["D "] = { { icon = i.deleted, hl = "NvimTreeGitDeleted" } },
--     ["RD"] = { { icon = i.deleted, hl = "NvimTreeGitDeleted" } },
--     ["DD"] = { { icon = i.deleted, hl = "NvimTreeGitDeleted" } },
--     ["DU"] = {
--         { icon = i.deleted, hl = "NvimTreeGitDeleted" },
--         { icon = i.unmerged, hl = "NvimTreeGitMerge" },
--     },
--     ["!!"] = { { icon = i.ignored, hl = "NvimTreeGitIgnored" } },
-- }

function M.GetGitIcon(node)
    local instance = get_instance()
    local stat = instance.gitstatus and instance.gitstatus[node.abs_path] or nil
    if stat == nil then
        return "", ""
    end
    if stat == "M " then
        return "[M]", "FTreeGitStaged"
    elseif stat == " M" then
        return "[M]", "FTreeGitModified"
    elseif stat == "R " or stat == " R" then
        return "[R]", "FTreeGitRenamed"
    elseif stat == " A" then
        return "[A]", "FTreeGitAdded"
    elseif stat == "??" then
        return "[★]", "FTreeGitUntracked"
    elseif stat == "!!" then
        return "[◌]", "FTreeGitIgnored"
    end
    return "", ""
end

-- indent : icon : filename : gitstatus
function M.GetTreeContext(tree, depth)
    local instance = get_instance()
    if instance.filter and instance.filter(tree, instance.gitstatus) then
        return
    end

    local indent = string.rep(" ", depth * 2)

    local icon, icon_hl = M.GetNodeIcon(tree)
    icon = #icon > 0 and icon .. " " or ""

    local gitstatus, gitstatus_hl = M.GetGitIcon(tree)
    gitstatus = #gitstatus > 0 and " " .. gitstatus or ""

    local name = tree.name
    local name_hl = gitstatus_hl

    if instance.tree == tree then
        icon = ""
        icon_hl = ""
        name = utils.path_join {
            utils.path_remove_trailing(vim.fn.fnamemodify(tree.abs_path, ":~")),
            "..",
        }
        name_hl = "FTreeRootFolder"
        gitstatus = ""
        gitstatus_hl = ""
    end

    local new_line = {
        line = string.format("%s%s%s%s", indent, icon, name, gitstatus),
        node = tree,
        highlights = {
            {icon_hl, -1, #indent, #indent + #icon},
            {name_hl, -1, #indent + #icon, #indent + #icon + #name},
            {gitstatus_hl, -1, #indent + #icon + #name, #indent + #icon + #name + #gitstatus},
        }
    }
    table.insert(instance.lines, new_line)

    if tree.ftype == "folder" and tree.status == "opened" then
        for _, node in ipairs(tree.nodes) do
            M.GetTreeContext(node, depth + 1)
        end
    end

    return nil
end

function M.GetFocusedNode()
    local instance = get_instance()
    local cursor = instance.view.GetCursor()
    return instance.lines[cursor[1]]["node"]
end

function M.DoAction(action)
    return function()
        local node = M.GetFocusedNode()
        local refresh = action(node, M)
        if refresh ~= nil and refresh == true then
            M.Draw()
        end
    end
end

function M.Toggle()
    local instance = get_instance()
    if not instance.view or not instance.view.Visable() then
        -- 为当前 tab 创建新的树实例（如果不存在）
        if not instance.tree then
            instance.tree = require("ftree.node").New()
        end
        if instance.view then
            instance.view.Open()
            M.Draw()
        end
    else
        instance.view.Close()
    end
end

function M.Focus()
    local instance = get_instance()
    vim.api.nvim_set_current_win(instance.view.GetWinid())
end

function M.ShowTree(view, tree)
end

function M.ShowHelp(view)
end

function M.setup(opts)
    -- 存储默认选项，以便用于后续创建的 tab 实例
    M.default_opts = opts or {}
    
    local instance = get_instance()
    instance.view = opts and opts.view
    instance.tree = opts and opts.tree
    instance.keymaps = opts and opts.keymaps
end

return M