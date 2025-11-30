local M = {
    tab_states = {}, -- 存储每个 tab 的状态
    highlight_namespace = vim.api.nvim_create_namespace("FTreeHighlights"),
}

local function get_tab_state()
    local tabpage = vim.api.nvim_get_current_tabpage()
    if not M.tab_states[tabpage] then
        M.tab_states[tabpage] = {
            prev_win = nil,
            buf = nil,
            winnr = nil,
            win = nil,
            cursor = nil,
        }
    end
    return M.tab_states[tabpage]
end

function M.SavePrevWinid()
    local cur = vim.api.nvim_get_current_win()

    vim.api.nvim_command("wincmd p")
    local tab_state = get_tab_state()
    tab_state.prev_win = vim.api.nvim_get_current_win()

    vim.api.nvim_set_current_win(cur)
end

function M.GetValidPrevWinid()
    local tab_state = get_tab_state()
    if not tab_state.prev_win or not vim.api.nvim_win_is_valid(tab_state.prev_win) then
        local cur = vim.api.nvim_get_current_win()

        vim.api.nvim_command("wincmd l")
        tab_state.prev_win = vim.api.nvim_get_current_win()

        vim.api.nvim_set_current_win(cur)
    end
    return tab_state.prev_win
end

function M.Open(opts)
    if M.Visable() then
        return
    end

    local tab_state = get_tab_state()
    tab_state.prev_win = vim.api.nvim_get_current_win()

    local tabpage = vim.api.nvim_get_current_tabpage()

    if not tab_state.buf or
        not tab_state.buf.bufnr or
        not vim.api.nvim_buf_is_valid(tab_state.buf.bufnr) then
        tab_state.buf = require("ftree.buf").New({
                name = "FTree_" .. tabpage,
                opts = {
                    swapfile   = false,
                    buftype    = "nofile",
                    modifiable = false,
                    filetype   = "FTree",
                    bufhidden  = "hide",
                    buflisted  = false,
                },
            })
    end

    if not tab_state.winnr or not vim.api.nvim_win_is_valid(tab_state.winnr) then
        local window = require("ftree.win").New({
            bufnr = tab_state.buf.bufnr,
            width = 20,
            opts = {
                relativenumber = false,
                number         = false,
                list           = false,
                foldenable     = false,
                winfixwidth    = true,
                winfixheight   = true,
                spell          = false,
                signcolumn     = "yes",
                foldmethod     = "manual",
                foldcolumn     = "0",
                cursorcolumn   = false,
                cursorlineopt  = "line",
                colorcolumn    = "0",
                wrap           = false,
            }
        })
        tab_state.winnr = window.winnr
        tab_state.win = window
        M.RestoreState()
    end

end

function M.GetWinid()
    local tab_state = get_tab_state()
    if tab_state and tab_state.win then
        return tab_state.win.winnr
    end
    return nil
end

function M.Visable()
    local tab_state = get_tab_state()
    return tab_state and tab_state.winnr ~= nil and vim.api.nvim_win_is_valid(tab_state.winnr)
end

-- Update view buffer lines, highlights and keymaps
function M.Update(lines, highlights, keymaps)
    local tab_state = get_tab_state()
    if not tab_state.buf or not tab_state.buf.bufnr or not vim.api.nvim_buf_is_loaded(tab_state.buf.bufnr) then
        return
    end

    vim.api.nvim_buf_set_option(tab_state.buf.bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(tab_state.buf.bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(tab_state.buf.bufnr, M.highlight_namespace, 0, -1)
    for _, data in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(tab_state.buf.bufnr, M.highlight_namespace, data[1], data[2], data[3], data[4])
    end
    vim.api.nvim_buf_set_option(tab_state.buf.bufnr, "modifiable", false)

    tab_state.buf:SetKeymaps(keymaps)
end

function M.GetCursor()
    local tab_state = get_tab_state()
    return tab_state and
        tab_state.winnr ~= nil and
        vim.api.nvim_win_is_valid(tab_state.winnr) and
        vim.api.nvim_win_get_cursor(tab_state.winnr)
end

function M.SetCursor(cursor)
    if not M.Visable() then
        return
    end
    local tab_state = get_tab_state()
    vim.api.nvim_win_set_cursor(tab_state.winnr, cursor)
end

function M.SaveState()
    local tab_state = get_tab_state()
    tab_state.cursor = M.GetCursor()
end

function M.RestoreState()
    local tab_state = get_tab_state()
    if tab_state.cursor then
        vim.api.nvim_win_set_cursor(tab_state.win.winnr, tab_state.cursor)
    end
end

function M.Close()
    M.SaveState()
    local tab_state = get_tab_state()
    vim.api.nvim_win_close(tab_state.win.winnr, true)
end

function M.GetSign(lnum)
    if not M.Visable() then
        return
    end

    local tab_state = get_tab_state()
    return vim.fn.sign_getplaced(tab_state.buf.bufnr, {
        group = "FTreeView",
        lnum = lnum,
    })
end

function M.SetSign(name, lnum)
    if not M.Visable() then
        return
    end
    local tab_state = get_tab_state()
    local id = vim.fn.sign_place(lnum, "FTreeView", name, tab_state.buf.bufnr, {lnum = lnum})
end

function M.ClearSign(id)
    if not M.Visable() then
        return
    end
    local tab_state = get_tab_state()
    vim.fn.sign_unplace("FTreeView", { buffer = tab_state.buf.bufnr, id = id })
end

return M
