local M = {}

-- 导入所有子模块
M.file = require('ftree.actions.file')
M.dir = require('ftree.actions.dir')
M.clipboard = require('ftree.actions.clipboard')
M.navigation = require('ftree.actions.navigation')
M.filter = require('ftree.actions.filter')
M.info = require('ftree.actions.info')

-- 保持向后兼容性：将旧的函数引用到新的位置
M.CR = M.file.CR
M.OpenFileFunc = M.file.OpenFileFunc
M.EditFile = M.file.EditFile
M.SplitFile = M.file.SplitFile
M.VSplitFile = M.file.VSplitFile
M.DirToggle = M.dir.DirToggle
M.DirIn = M.dir.DirIn
M.DirOut = M.dir.DirOut
M.NewFile = M.file.NewFile
M.RenameFile = M.file.RenameFile
M.RemoveFile = M.file.RemoveFile
M.Refresh = M.file.Refresh
M.CopyFileName = M.file.CopyFileName
M.CopyAbsPath = M.file.CopyAbsPath
M.ToggleMark = M.clipboard.ToggleMark
M.Copy = M.clipboard.Copy
M.Cut = M.clipboard.Cut
M.Paste = M.clipboard.Paste
M.ShowActionInfo = M.clipboard.ShowActionInfo
M._CloseActionInfo = M.clipboard._CloseActionInfo
M.ClearMarks = M.clipboard.ClearMarks
M.MoveToParent = M.navigation.MoveToParent
M.MoveToLastChild = M.navigation.MoveToLastChild
M.MoveToNextSibling = M.navigation.MoveToNextSibling
M.MoveToPrevSibling = M.navigation.MoveToPrevSibling
M.ToggleGitIgnoredFiles = M.filter.ToggleGitIgnoredFiles
M.ToggleDotFiles = M.filter.ToggleDotFiles
M.ShowFileInfo = M.info.ShowFileInfo
M._CloseFileInfo = M.info._CloseFileInfo

-- 设置函数
function M.setup(opts)
    vim.fn.sign_define("FTreeMark", { text = "*" })
end

return M