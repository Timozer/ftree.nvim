local utils = require("ftree.utils")
local icons = require("ftree.icons")

local R = {
}
R.__index = R

function R.New(opts)
    local ins = {
        lines = {},
        view = opts and opts.view or nil,
        tree = opts and opts.tree or nil,
        gitstatus = nil,
        filter = nil,
        keymaps = opts and opts.keymaps or nil,
    }
    local r = setmetatable(ins, R)
    return r
end

function R:_RefreshGitStatus()
    self.gitstatus = nil
    local ret = require("ftree.git").Status(self.tree.abs_path)
    if ret.result == "success" then
        self.gitstatus = ret.data
    end
end

function R:_RefreshLines()
    err = self:GetTreeContext(self.tree, 0)
    if err then
        require("ftree.utils").Notify("[FTree] Error: " .. vim.inspect(err), vim.log.levels.ERROR)
        return
    end
end

-- indent : icon : filename : gitstatus
function R:GetTreeContext(tree, depth)
    if self.filter and self.filter(tree, self.gitstatus) then
        return
    end

    local indent = string.rep(" ", depth * 2)

    local icon, icon_hl = self:GetNodeIcon(tree)
    icon = #icon > 0 and icon .. " " or ""

    local gitstatus, gitstatus_hl = self:GetGitIcon(tree)
    gitstatus = #gitstatus > 0 and " " .. gitstatus or ""

    local name = tree.name
    local name_hl = gitstatus_hl

    if self.tree == tree then
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
    table.insert(self.lines, new_line)

    if tree.ftype == "folder" and tree.status == "opened" then
        for _, node in ipairs(tree.nodes) do
            self:GetTreeContext(node, depth + 1)
        end
    end

    return nil
end


function R:GetRenderContext()
    local lines = {}
    local highlights = {}
    for i, item in ipairs(self.lines) do
        table.insert(lines, item.line)
        for _, highlight in pairs(item.highlights) do
            highlight[2] = i - 1
            table.insert(highlights, highlight)
        end
    end
    return lines, highlights
end

function R:Draw(node)
    if not self.tree or not self.view or not self.view.Visable() then
        return
    end

    self.lines = {}
    self.highlights = {}

    self:_RefreshGitStatus()
    self:_RefreshLines()

    local lines, highlights = self:GetRenderContext()
    self.view.Update(lines, highlights, self.keymaps['tree'])

    self:MoveCursorToNode(node)
end

function R:MoveCursorToNode(node)
    if self.lines then
        for i, line in ipairs(self.lines) do
            if line.node == node then
                self.view.SetCursor({i, 0})
                break
            end
        end
    end
end

function R:GetNodeIcon(node)
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

function R:GetGitIcon(node)
    local stat = self.gitstatus and self.gitstatus[node.abs_path] or nil
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

function R:GetFocusedNode()
    local cursor = self.view.GetCursor()
    return self.lines[cursor[1]]["node"]
end

function R:Toggle()
    if not self.view or not self.view.Visable() then
        if not self.tree then
            self.tree = require("ftree.node").New()
        end
        if self.view then
            self.view.Open()
            self:Draw()
        end
    else
        self.view.Close()
    end
end

function R:Focus()
    vim.api.nvim_set_current_win(self.view.GetWinid())
end

function R:MoveToParent(node, close)
    if node == self.tree then
        return
    end

    local parent = node.parent

    if self.lines then
        for i, line in ipairs(self.lines) do
            if parent ==  line.node then
                self.view.SetCursor({i, 0})
            end
        end
    end

    if close and node ~= self.tree then
        parent.status = "closed"
        return true
    end
end

function R:MoveToLastChild(node)
    local cur_node = nil

    if (node.ftype == "folder" or (node.ftype == "link" and node.link_type == "folder")) and node.status == "opened" then
        cur_node = node
    else
        cur_node = node.parent
    end

    if not cur_node.nodes or #cur_node.nodes == 0 then
        return
    end

    local last = cur_node.nodes[#cur_node.nodes]

    if self.lines then
        for i, line in ipairs(self.lines) do
            if last == line.node then
                self.view.SetCursor({i, 0})
            end
        end
    end
end

function R:MoveToNextSibling(node)
    if node == self.tree then
        return
    end

    local parent = node.parent
    local next_node = nil

    if not parent or not parent.nodes then
        return
    end

    for i, _ in ipairs(parent.nodes) do
        if parent.nodes[i] == node then
            next_node = i == #parent.nodes and parent.nodes[1] or parent.nodes[i + 1]
            break
        end
    end

    if next_node and self.lines then
        for i, line in ipairs(self.lines) do
            if next_node == line.node then
                self.view.SetCursor({i, 0})
            end
        end
    end
end

function R:MoveToPrevSibling(node, renderer)
    if node == self.tree then
        return
    end

    local parent = node.parent
    local prev_node = nil

    if not parent or not parent.nodes then
        return
    end

    for i, _ in ipairs(parent.nodes) do
        if parent.nodes[i] == node then
            prev_node = i == 1 and parent.nodes[#parent.nodes] or parent.nodes[i - 1]
            break
        end
    end

    if prev_node and self.lines then
        for i, line in ipairs(self.lines) do
            if prev_node == line.node then
                self.view.SetCursor({i, 0})
            end
        end
    end
end


local M = {
    instances = {}, -- 每个 tab 的实例
    default_opts = nil, -- 存储默认选项
}

function M.GetCurRender()
    local tabpage = vim.api.nvim_get_current_tabpage()
    if not M.instances[tabpage] then
        M.instances[tabpage] = R.New(M.default_opts)
    end
    return M.instances[tabpage]
end

function M.Toggle()
    local r = M.GetCurRender()
    return r:Toggle()
end


function M.DoAction(action)
    return function()
        local r = M.GetCurRender()
        local node = r:GetFocusedNode()
        local refresh = action(node, r)
        if refresh ~= nil and refresh == true then
            r:Draw(node)
        end
    end
end

function M.setup(opts)
    M.default_opts = opts or {}

    local instance = M.GetCurRender()
    instance.view = opts and opts.view
    instance.tree = opts and opts.tree
    instance.keymaps = opts and opts.keymaps
end

return M
