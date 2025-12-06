local M = {}

function M.ToggleGitIgnoredFiles(node, renderer)
    if renderer.filter ~= nil then
        renderer.filter = nil
    else
        renderer.filter = require("ftree.filter").IsGitIgnored
    end
    return true
end

function M.ToggleDotFiles(node, renderer)
    if renderer.filter ~= nil then
        renderer.filter = nil
    else
        renderer.filter = require("ftree.filter").IsDotFile
    end
    return true
end

return M
