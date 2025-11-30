local utils = require("ftree.utils")

local M = {}

function M._AddDirStatus(result, project_root)
    local dirs = {}
    for p, s in pairs(result.data) do
        if s ~= "!!" then
            local modified = vim.fn.fnamemodify(p, ":h")
            dirs[modified] = s
        end
    end

    for dirname, s in pairs(dirs) do
        local modified = dirname
        while modified ~= project_root and modified ~= "/" do
            modified = vim.fn.fnamemodify(modified, ":h")
            dirs[modified] = s
        end
    end

    result.data = vim.tbl_extend("force", result.data, dirs)
    return result
end

function M.RootPath(cwd)
    local cmd = "git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel"
    local toplevel = vim.fn.system(cmd)

    if not toplevel or #toplevel == 0 or toplevel:match "fatal" then
        return nil
    end

    -- git always returns path with forward slashes
    if vim.fn.has "win32" == 1 then
        toplevel = toplevel:gsub("/", "\\")
    end

    -- remove newline
    return toplevel:sub(0, -2)
end

function M.Status(cwd)
    result = {}

    local project_root = M.RootPath(cwd)
    if not project_root then
        result.result = "fail"
        result.stderr = "not a git repository"
    end

    local command = { "git", "--no-optional-locks", "status", "--porcelain=v1", "-u", "--ignored=matching" }
    local git_job = vim.system(command, { cwd = cwd, timeout = 4000 })
    local job_result = git_job:wait()

    if job_result.code == -1 or job_result.code == nil then
        result.result = "timeout"
    elseif job_result.code ~= 0 then
        result.result = "fail"
        result.status = job_result.code
        result.stderr = job_result.stderr
    end

    result.result = "success"
    result.data = {}
    for line in (job_result.stdout or ""):gmatch("[^\n]*\n") do
        local status = line:sub(1, 2)
        -- removing `"` when git is returning special file status containing spaces
        local path = line:sub(4, -2):gsub('^"', ""):gsub('"$', "")
        -- replacing slashes if on windows
        if vim.fn.has "win32" == 1 then
            path = path:gsub("/", "\\")
        end
        if #status > 0 and #path > 0 then
            result.data[utils.path_remove_trailing(utils.path_join { project_root, path })] = status
        end
    end
    return M._AddDirStatus(result, project_root)
end

return M