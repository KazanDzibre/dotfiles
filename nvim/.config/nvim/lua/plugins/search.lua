-- Project-wide search and replace -- VS Code's Ctrl+Shift+H.
--
-- Telescope's live_grep finds matches but cannot rewrite them. grug-far opens a
-- real buffer: type a search, type a replacement, see every hit with its
-- surrounding lines, then apply the whole thing at once.
--
-- The engine is ripgrep, which is at /usr/bin/rg here. Without it the buffer
-- opens and reports an error instead of results, so this plugin is not useful
-- on a machine that lacks it.

return {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
        {
            "<leader>sr",
            function()
                require("grug-far").open()
            end,
            desc = "Search / replace (project)",
        },
        {
            "<leader>sw",
            function()
                require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
            end,
            desc = "Search / replace word under cursor",
        },
        {
            "<leader>sv",
            function()
                require("grug-far").with_visual_selection()
            end,
            mode = "x",
            desc = "Search / replace selection",
        },
        {
            "<leader>sf",
            function()
                -- `paths` scopes ripgrep to one file, which is the closest thing
                -- to VS Code's in-file replace widget.
                require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
            end,
            desc = "Search / replace (this file)",
        },
    },
    opts = {
        -- The results buffer is a normal window, so it inherits splitright from
        -- core/options.lua and lands on the right.
        headerMaxWidth = 80,
    },
}
