-- Nuketown neovim config -- Lua only, plugins via lazy.nvim.
--
-- Read in this order:
--   core/options.lua   editor behaviour
--   core/keymaps.lua   keys that do not belong to a plugin
--   core/theme.lua     colourscheme switching, remembered between sessions
--   core/lazy.lua      bootstraps lazy.nvim and imports lua/plugins/*
--
-- The leader key must be set BEFORE lazy.nvim loads: plugin specs capture
-- <leader> at definition time, so setting it later silently binds them to the
-- wrong key.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("core.options")
require("core.keymaps")
require("core.lazy")
