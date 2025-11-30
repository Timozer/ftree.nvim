local utils = require('ftree.utils')
local buf = require('ftree.buf')

local M = {
    marks = {},
    action = {
        type = nil,
        data = {}
    },
    action_info_win = nil,
}

function M.ToggleMark(node, renderer)
    if node == renderer.tree then
        return
    end

    local lnum = renderer.view.GetCursor()[1]
    local signs = renderer.view.GetSign(lnum)[1]
    if #signs.signs > 0 then
        renderer.view.ClearSign(signs.signs[1].id)
        for i, _ in ipairs(M.marks) do
            if M.marks[i] == node then
                table.remove(M.marks, i)
                break
            end
        end
    else
        renderer.view.SetSign("FTreeMark", lnum)
        table.insert(M.marks, node)
    end
end

function M.Copy(node, renderer)
    M.action.type = "copy"
    if #M.marks > 0 then
        M.action.data = M.marks
        M.marks = {}
        renderer.view.ClearSign()
    else
        M.action.data = {}
        table.insert(M.action.data, node)
    end
end

function M.Cut(node, renderer)
    M.action.type = "cut"
    if #M.marks > 0 then
        M.action.data = M.marks
        M.marks = {}
        renderer.view.ClearSign()
    else
        M.action.data = {}
        table.insert(M.action.data, node)
    end
end

function M.Paste(node, renderer)
    if not (#M.action.data > 0) then
        return
    end

    local paste_to = node
    if node.ftype == "file" or (node.ftype == "link" and node.ftype == "file") then
        paste_to = node.parent
    end

    local cmd = nil
    local args = nil
    if M.action.type == "cut" then
        cmd = "mv"
        args = {}
    elseif M.action.type == "copy" then
        cmd = "cp"
        args = { "-rf" }
    else
        return
    end

    local idx = 1
    while idx <= #M.action.data do
        local dst = utils.path_join({paste_to.abs_path, M.action.data[idx].name})

        local should_continue = false
        while true do
            if not utils.file_exists(dst) then
                break
            end

            local resp = utils.GetInputChar(dst .. " exists, rename/overwrite/cancel? [r/o/c] ")
            if resp == "r" then
                local opts = { 
                    prompt = "Rename " .. M.action.data[idx].abs_path .. " to: ",
                    default = dst,
                }
                vim.ui.input(opts, function(fname)
                    if fname == nil or #fname == 0 then
                        dst = ""
                        return
                    end
                    dst = fname
                end)
                if dst == "" then
                    should_continue = true
                    break
                end
            elseif resp == "o" then
                break
            else
                should_continue = true
                break
            end
        end

        if should_continue then
            idx = idx + 1
            goto continue_loop
        end

        tmpArgs = { M.action.data[idx].abs_path, dst }
        for j, aval in ipairs(args) do
            table.insert(tmpArgs, j, aval)
        end
        job_paste = vim.system({cmd, unpack(tmpArgs)}, { timeout = 4000 })
        local result_paste = job_paste:wait()
        if result_paste.code ~= 0 then
            msg = "paste: " .. M.action.data[idx].abs_path .. " to " .. dst .. " fail, err: " .. (result_paste.stderr or "")
            utils.Notify(msg)
            break
        end
        msg = "paste " .. M.action.data[idx].abs_path .. " to " .. dst .. " done"
        utils.Notify(msg)

        if M.action.data[idx].ftype == "folder" then
            buf.RenameBufByNamePrefix(M.action.data[idx].abs_path .. "/", dst .. "/")
        else
            buf.RenameBufByNamePrefix(M.action.data[idx].abs_path, dst)
        end

        table.remove(M.action.data, idx)
        ::continue_loop::
    end

    renderer.tree:Load()
    return true
end

function M.ShowActionInfo(node, renderer)
    local context = {
        "Action Type: " .. vim.inspect(M.action.type),
        "Data: ",
    }

    for i, val in ipairs(M.action.data) do
        table.insert(context, val.abs_path)
    end

    local win_width = vim.fn.max(vim.tbl_map(function(n) return #n end, context))
    local winnr = vim.api.nvim_open_win(0, false, {
        col = 1,
        row = 1,
        relative = "cursor",
        width = win_width + 1,
        height = #context,
        border = "shadow",
        noautocmd = true,
        style = "minimal",
    })
    M.action_info_win = { winnr = winnr, node = node }
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, context)
    vim.api.nvim_win_set_buf(winnr, bufnr)

    vim.cmd [[
        augroup FTreeCloseActionInfoWin
          au CursorMoved * lua require('ftree.actions.clipboard')._CloseActionInfo()
        augroup END
    ]]
end

function M._CloseActionInfo()
    if M.action_info_win ~= nil then
        vim.api.nvim_win_close(M.action_info_win.winnr, { force = true })
        vim.cmd "augroup FTreeCloseActionInfoWin | au! CursorMoved | augroup END"
        M.action_info_win = nil
    end
end

function M.ClearMarks(node, renderer)
    renderer.view.ClearSign()
    M.marks = {}
end

return M