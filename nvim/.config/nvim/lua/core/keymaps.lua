-- Keymaps that do not belong to a specific plugin.
-- Plugin keys live in that plugin's spec under `keys = {}`, so lazy.nvim can
-- defer loading it until the key is actually pressed.

local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Save / quit
map("n", "<C-s>", "<cmd>write<CR>", { desc = "Save file" })
map("i", "<C-s>", "<Esc><cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })

-- Commenting.
--
-- Neovim 0.11 has this built in: `gcc` toggles a line, `gc` is an operator, and
-- `gc` in visual mode toggles the selection. No plugin required.
--
-- These extra bindings only exist for VS Code muscle memory. Terminals disagree
-- on what Ctrl+/ sends -- foot sends <C-_> -- so both spellings are bound.
map("n", "<C-_>", "gcc", { remap = true, desc = "Toggle comment line" })
map("n", "<C-/>", "gcc", { remap = true, desc = "Toggle comment line" })
map("v", "<C-_>", "gc", { remap = true, desc = "Toggle comment selection" })
map("v", "<C-/>", "gc", { remap = true, desc = "Toggle comment selection" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Resize with arrows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Taller window" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Shorter window" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Narrower window" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Wider window" })

-- Buffers
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Move the selection up/down, keeping indentation sane
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep the selection after shifting, so >>> is one keystroke each
map("v", "<", "<gv", { desc = "Outdent" })
map("v", ">", ">gv", { desc = "Indent" })

-- Cheatsheet. Opens the reference that ships next to this config, read-only in
-- a vertical split.
local function open_cheatsheet()
    local path = vim.fn.stdpath("config") .. "/CHEATSHEET.txt"
    if vim.fn.filereadable(path) == 0 then
        vim.notify("No CHEATSHEET.txt next to the config", vim.log.levels.WARN)
        return
    end
    vim.cmd("vsplit " .. vim.fn.fnameescape(path))
    vim.bo.modifiable = false
    vim.bo.readonly = true
    vim.wo.wrap = false
end

vim.api.nvim_create_user_command("Cheatsheet", open_cheatsheet, { desc = "Open the key reference" })
map("n", "<leader>H", open_cheatsheet, { desc = "Cheatsheet" })

-- Themes
map("n", "<leader>ut", function()
    require("core.theme").cycle()
end, { desc = "Cycle colourscheme" })
map("n", "<leader>uT", function()
    require("core.theme").pick()
end, { desc = "Pick colourscheme" })
