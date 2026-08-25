-- Bootstrap lazy.nvim and load every spec in lua/plugins/.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
        }, true, {})
        return
    end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = { { import = "plugins" } },
    -- Which theme to show while plugins are installing on first launch.
    install = { colorscheme = { "catppuccin", "habamax" } },
    checker = { enabled = false }, -- no background update checks
    change_detection = { notify = false },
    performance = {
        rtp = {
            -- Built-in plugins that only slow startup down here.
            disabled_plugins = {
                "gzip",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
                "netrwPlugin", -- neo-tree replaces it
            },
        },
    },
})

-- Applied after the theme plugins exist, otherwise the colorscheme command
-- fails on a cold start.
require("core.theme").load()
