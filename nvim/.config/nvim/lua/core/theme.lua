-- Colourscheme switching, remembered across sessions.
--
-- The choice is stored in stdpath("data") rather than in the repo, so switching
-- themes on a whim does not produce a dirty git tree.

local M = {}

M.themes = {
    "catppuccin-mocha",
    "catppuccin-macchiato",
    "catppuccin-frappe",
    "tokyonight-night",
    "tokyonight-storm",
    "gruvbox",
    "kanagawa",
}

M.default = "catppuccin-mocha"

local state_file = vim.fn.stdpath("data") .. "/theme.txt"

local function read_saved()
    local f = io.open(state_file, "r")
    if not f then
        return nil
    end
    local name = f:read("*l")
    f:close()
    if name and name ~= "" then
        return vim.trim(name)
    end
end

local function save(name)
    local f = io.open(state_file, "w")
    if f then
        f:write(name .. "\n")
        f:close()
    end
end

--- Apply a colourscheme and remember it. Falls back to the default (and then to
--- a built-in) rather than leaving the editor unstyled if a theme is missing --
--- which happens on first launch, before lazy.nvim has finished installing.
function M.apply(name, remember)
    local ok = pcall(vim.cmd.colorscheme, name)
    if not ok and name ~= M.default then
        ok = pcall(vim.cmd.colorscheme, M.default)
    end
    if not ok then
        pcall(vim.cmd.colorscheme, "habamax")
        return false
    end
    if remember ~= false then
        save(name)
    end
    return true
end

--- Called at startup, after lazy.nvim has loaded the theme plugins.
function M.load()
    M.apply(read_saved() or M.default, false)
end

function M.current()
    return vim.g.colors_name or M.default
end

function M.cycle()
    local current = M.current()
    local index = 1
    for i, name in ipairs(M.themes) do
        -- vim.g.colors_name is the base name for some themes ("catppuccin"
        -- rather than "catppuccin-mocha"), so match on a prefix too.
        if name == current or vim.startswith(name, current) then
            index = i
            break
        end
    end
    local next_theme = M.themes[(index % #M.themes) + 1]
    if M.apply(next_theme) then
        vim.notify("Colourscheme: " .. next_theme, vim.log.levels.INFO)
    end
end

function M.pick()
    vim.ui.select(M.themes, { prompt = "Colourscheme" }, function(choice)
        if choice then
            M.apply(choice)
        end
    end)
end

vim.api.nvim_create_user_command("Theme", function(opts)
    if opts.args ~= "" then
        M.apply(opts.args)
    else
        M.pick()
    end
end, {
    nargs = "?",
    complete = function()
        return M.themes
    end,
    desc = "Set or pick a colourscheme",
})

return M
