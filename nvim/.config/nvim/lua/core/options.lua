-- Editor behaviour. Nothing here needs a plugin.

local opt = vim.opt

-- Line numbers: absolute for the current line, relative around it, so motions
-- like 12j can be read straight off the gutter.
opt.number = true
opt.relativenumber = true

-- Indentation: 4 spaces, never a literal tab.
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.breakindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true -- ...unless the pattern contains a capital
opt.hlsearch = true
opt.incsearch = true

-- Appearance
opt.termguicolors = true -- 24-bit colour; foot supports it
opt.signcolumn = "yes" -- always reserved, so text does not jump when a
-- diagnostic or git sign appears
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 8 -- keep context above/below the cursor
opt.sidescrolloff = 8
opt.showmode = false -- lualine already shows it
opt.splitright = true
opt.splitbelow = true
opt.fillchars = { eob = " " } -- no ~ on empty lines

-- Files and undo
opt.swapfile = false
opt.backup = false
opt.undofile = true -- undo survives closing the file
opt.updatetime = 250 -- also drives CursorHold / diagnostics popups
opt.timeoutlen = 400 -- how long which-key waits before showing

-- Shared clipboard. wl-clipboard is installed, so yanks go to the Wayland
-- selection and can be pasted into other apps.
opt.clipboard = "unnamedplus"

opt.mouse = "a"
opt.confirm = true -- ask instead of failing when quitting unsaved buffers

-- Show whitespace that usually matters
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Live substitution preview in a split
opt.inccommand = "split"
