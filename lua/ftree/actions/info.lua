local utils = require('ftree.utils')

local M = {
    finfo_win = nil,
}

function M.ShowFileInfo(node, renderer)
    local fstat = node:FsStat()
    if not fstat then
        utils.Notify("Cannot access file information for: " .. node.abs_path, vim.log.levels.WARN)
        return
    end

    -- 权限字符串转换函数
    local function format_permissions(fstat)
        -- 获取文件权限字符串
        local perm_string = vim.fn.getfperm(node.abs_path)
        if not perm_string or #perm_string ~= 9 then
            -- 如果获取失败，返回基本的文件类型
            if fstat.type == "directory" then
                return "d---------"
            elseif fstat.type == "link" then
                return "l---------"
            else
                return "----------"
            end
        end
        
        -- 文件类型
        local perm = ""
        if fstat.type == "directory" then
            perm = perm .. "d"
        elseif fstat.type == "link" then
            perm = perm .. "l"
        else
            perm = perm .. "-"
        end
        
        -- 直接使用获取到的权限字符串
        perm = perm .. perm_string
        
        return perm
    end

    -- 文件类型描述
    local function get_file_type(fstat)
        if fstat.type == "directory" then
            return "Directory"
        elseif fstat.type == "file" then
            return "Regular File"
        elseif fstat.type == "link" then
            return "Symbolic Link"
        else
            return fstat.type or "Unknown"
        end
    end

    -- 获取用户名和组名
    local owner_info = "N/A:N/A"
    if fstat.uid and fstat.gid then
        -- 获取用户名
        local user_result = vim.system({"sh", "-c", "id -un " .. fstat.uid}, {timeout=1000}):wait()
        local user_name = "N/A"
        if user_result and user_result.code == 0 and user_result.stdout then
            user_name = vim.trim(user_result.stdout)
        else
            user_name = tostring(fstat.uid)
        end
        
        -- 获取组名
        local group_result = vim.system({"sh", "-c", "id -gn " .. fstat.gid}, {timeout=1000}):wait()
        local group_name = "N/A"
        if group_result and group_result.code == 0 and group_result.stdout and vim.trim(group_result.stdout) ~= "" then
            group_name = vim.trim(group_result.stdout)
        else
            -- 如果 id -gn 失败，尝试使用 getent 命令
            local getent_result = vim.system({"sh", "-c", "getent group " .. fstat.gid .. " | cut -d: -f1"}, {timeout=1000}):wait()
            if getent_result and getent_result.code == 0 and getent_result.stdout and vim.trim(getent_result.stdout) ~= "" then
                group_name = vim.trim(getent_result.stdout)
            else
                group_name = tostring(fstat.gid)
            end
        end
        
        owner_info = user_name .. ":" .. group_name
    end

    -- 获取 MIME 类型
    local mime_type = "N/A"
    local mime_result = vim.system({"file", "-b", "--mime-type", node.abs_path}, {timeout=1000}):wait()
    if mime_result and mime_result.code == 0 and mime_result.stdout then
        mime_type = vim.trim(mime_result.stdout)
    end

    -- 对于文本文件，尝试获取行数
    local line_count = nil
    if mime_type:match("^text/") or node.ext == "txt" or node.ext == "lua" or node.ext == "js" or node.ext == "py" or node.ext == "json" or node.ext == "html" or node.ext == "css" or node.ext == "xml" then
        local wc_result = vim.system({"wc", "-l", node.abs_path}, {timeout=2000}):wait()
        if wc_result and wc_result.code == 0 and wc_result.stdout then
            line_count = vim.trim(wc_result.stdout):match("(%d+)")
        end
    end

    local context = {
        "Path: " .. node.abs_path,
        "Name: " .. node.name,
        "Type: " .. get_file_type(fstat),
        "Size: " .. utils.format_bytes(fstat.size),
        "Permissions: " .. format_permissions(fstat),
        "Owner: " .. owner_info,
        "Links: " .. (fstat.nlink or "N/A"),
    }

    -- 如果是文件，尝试获取扩展名
    if node.ftype == "file" then
        local ext = node.ext or string.match(node.name, ".?[^.]+%.(.*)") or ""
        if ext ~= "" then
            table.insert(context, #context + 1, "Extension: " .. ext)
        end
    end

    -- 添加 MIME 类型
    table.insert(context, #context + 1, "MIME Type: " .. mime_type)

    -- 添加行数（如果可用）
    if line_count then
        table.insert(context, #context + 1, "Lines: " .. (line_count or "N/A"))
    end

    -- 如果是链接，添加目标信息
    if node.ftype == "link" then
        local link_target = node.link_to or vim.loop.fs_realpath(node.abs_path) or "Unknown"
        table.insert(context, #context + 1, "Link Target: " .. link_target)
    end

    -- 添加时间信息
    table.insert(context, #context + 1, "File Times:")
    table.insert(context, #context + 1, "  Created: " .. os.date("%Y/%m/%d %H:%M:%S", fstat.birthtime.sec))
    table.insert(context, #context + 1, "  Modified: " .. os.date("%Y/%m/%d %H:%M:%S", fstat.mtime.sec))
    table.insert(context, #context + 1, "  Accessed: " .. os.date("%Y/%m/%d %H:%M:%S", fstat.atime.sec))
    
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
    M.finfo_win = { winnr = winnr, node = node }
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, context)
    vim.api.nvim_win_set_buf(winnr, bufnr)

    vim.cmd [[
        augroup FTreeCloseFileInfoWin
          au CursorMoved * lua require('ftree.actions.info')._CloseFileInfo()
        augroup END
    ]]
end

function M._CloseFileInfo()
    if M.finfo_win ~= nil then
        vim.api.nvim_win_close(M.finfo_win.winnr, { force = true })
        vim.cmd "augroup FTreeCloseFileInfoWin | au! CursorMoved | augroup END"
        M.finfo_win = nil
    end
end

return M
