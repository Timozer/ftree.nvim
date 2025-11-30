local utils = require('ftree.utils')
local buf = require('ftree.buf')

local M = {}

function M.CR(node, renderer)
    if node and node.nodes then
        return require('ftree.actions.dir').DirToggle(node, renderer)
    end
    return M.EditFile(node, renderer)
end

function M.OpenFileFunc(mode)
    return function(node)
        local api = vim.api
        local tabpage = api.nvim_get_current_tabpage()
        local win_ids = api.nvim_tabpage_list_wins(tabpage)

        for _, winnr in ipairs(win_ids) do
            if node.abs_path == vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr)) then
                vim.api.nvim_set_current_win(winnr)
                return
            end
        end
    end
end

function M.EditFile(node, renderer)
    if node.ftype == "link" and node.link_type ~= "file" or node.ftype ~= "file" then
        return
    end

    vim.api.nvim_set_current_win(renderer.view:GetValidPrevWinid())
    pcall(vim.cmd, "edit "..vim.fn.fnameescape(node.ftype == "link" and node.link_to or node.abs_path))
end

function M.SplitFile(node, renderer)
    if node.ftype == "link" and node.link_type ~= "file" or node.ftype ~= "file" then
        return
    end

    vim.api.nvim_set_current_win(renderer.view.GetValidPrevWinid())
    pcall(vim.cmd, "sp "..vim.fn.fnameescape(node.ftype == "link" and node.link_to or node.abs_path))
end

function M.VSplitFile(node, renderer)
    if node.ftype == "link" and node.link_type ~= "file" or node.ftype ~= "file" then
        return
    end

    vim.api.nvim_set_current_win(renderer.view.GetValidPrevWinid())
    pcall(vim.cmd, "vsp "..vim.fn.fnameescape(node.ftype == "link" and node.link_to or node.abs_path))
end

function M.NewFile(node, renderer)
    local tmpNode = node
    if node.ftype == "file" or (node.ftype == "link" and node.link_type == "file") then
        tmpNode = node.parent
    elseif node.ftype == "folder" or (node.ftype == "link" and node.link_type == "folder") then
        if node.status == "closed" then
            tmpNode = node.parent
        end
    end

    local opts = { prompt = "["..tmpNode.abs_path.."]" .. " New dir or file: " }

    vim.ui.input(opts, function(fname)
        if not fname or #fname == 0 then
            return
        end

        vim.api.nvim_command("normal! :")

        local abs_path = utils.path_join({ tmpNode.abs_path, fname })

        if utils.file_exists(abs_path) then
            utils.Notify(fname .. " already exists")
            return
        end

        local job_mkdir = vim.system({"mkdir", "-p", vim.fn.fnamemodify(fname, ":h")}, {timeout = 4000})
        local result_mkdir = job_mkdir:wait()
        if result_mkdir.code ~= 0 then
            utils.Notify("fail to create directory for " .. fname .. ", err: " .. (result_mkdir.stderr or ""))
            return
        end

        local filename = vim.fn.fnamemodify(fname, ":t")
        if #filename > 0 then
            local job_touch = vim.system({"touch", fname}, {cwd = tmpNode.abs_path, timeout = 4000})
            local result_touch = job_touch:wait()
            if result_touch.code ~= 0 then
                utils.Notify("fail to create " .. fname .. ", err: " .. (result_touch.stderr or ""))
                return
            end
        end

        tmpNode:Load() -- 更新父目录以显示新创建的文件
    end)
    return true
end

function M.RenameFile(node)
    local dir = vim.fn.fnamemodify(node.abs_path, ":h")
    local opts = { 
        prompt = "["..dir.."]" .. " Rename " .. node.name .. " to: ",
        default = node.name,
    }

    vim.ui.input(opts, function(fname)
        if not fname or #fname == 0 or fname == node.name then
            return
        end

        local abs_path = utils.path_join({dir, fname})
        if utils.file_exists(abs_path) then
            utils.Notify(fname .. " already exists")
            return
        end

        local job_mv = vim.system({"mv", node.name, fname}, {cwd = dir, timeout = 4000})
        local result_mv = job_mv:wait()
        if result_mv.code ~= 0 then
            utils.Notify("fail to rename " .. fname .. ", err: " .. (result_mv.stderr or ""))
            return
        end

        old_path = node.abs_path
        node.name = fname
        node.abs_path = abs_path
        if node.ftype == "folder" or (node.ftype == "link" and node.link_type == "folder") then
            node.nodes = {}
            if node.status == "opened" then
                node:Load()
            end
        end

        if node.ftype == "folder" then
            buf.RenameBufByNamePrefix(old_path .. "/", node.abs_path .. "/")
        else
            buf.RenameBufByNamePrefix(old_path, node.abs_path)
        end

    end)
    return true
end

function M.RemoveFile(node, renderer)
    if node == renderer.tree then
        utils.Notify("cannot remove root folder")
        return
    end

    local resp = utils.GetInputChar("Delete " .. node.abs_path .. " ? [y/n] ")
    if resp ~= "y" then
        return
    end

    local job_rm = vim.system({"rm", "-r", "-f", node.abs_path}, {timeout = 4000})
    local result_rm = job_rm:wait()
    if result_rm.code ~= 0 then
        utils.Notify("fail to remove " .. node.abs_path .. ", err: " .. (result_rm.stderr or ""))
        return
    end

    rm_path = node.abs_path
    if node.ftype == "folder" then
        rm_path = rm_path .. "/"
    end

    print("del buf by name prefix: "..rm_path)
    buf.DelBufByNamePrefix(rm_path, true)

    node.parent:Load()
    return true
end

function M.CopyFileName(node)
    vim.fn.setreg("+", node.name)
    vim.fn.setreg('"', node.name)
    utils.Notify("Copy "..node.name.." to clipboard")
end

function M.CopyAbsPath(node)
    vim.fn.setreg("+", node.abs_path)
    vim.fn.setreg('"', node.abs_path)
    utils.Notify("Copy "..node.abs_path.." to clipboard")
end

function M.Refresh(node, renderer)
    renderer.tree:Load()
    return true
end

return M