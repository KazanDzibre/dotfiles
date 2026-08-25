-- Extract function / extract variable / inline -- the refactorings VS Code puts
-- behind its lightbulb that no language server actually implements.
--
-- These are treesitter operations, not LSP ones, so they need no server running
-- and behave the same in every supported language:
--
--     C, C#, C++, Go, Java, JavaScript/TypeScript/JSX/TSX, Lua, PHP,
--     Powershell, Python, Ruby, Vimscript
--
-- Both halves of the day job are on that list, so `<leader>re` works in a .cs
-- file and a .ts file alike. The queries ship with the plugin; the language's
-- treesitter parser still has to be installed (see treesitter.lua).
--
-- Rename is deliberately absent: <leader>rn is the LSP's, and an LSP rename is
-- the better one because it follows the symbol across files.
--
-- Two things about this plugin that are easy to get wrong:
--
-- * **These are operators, not commands.** In normal mode `<leader>re` waits
--   for a motion the way `d` does -- `<leader>reap` extracts a paragraph,
--   `<leader>rei{` a block, `<leader>re_` the current line. In visual mode it
--   acts on the selection immediately. That is why every key below is
--   `expr = true` and *returns* its function's value: the return is an
--   operatorfunc expression, so dropping the `return` silently does nothing.
--
-- * **It is pinned, and the pin is load-bearing.** Upstream now requires
--   Neovim 0.12 -- and means it: current HEAD calls `vim.iter():unique()`,
--   which does not exist on the 0.11.0 in ~/SourceBuilds, so every extract
--   dies with "attempt to call method 'unique' (a nil value)". b712180
--   (2026-04-06) is the last commit before that landed. It has the same API as
--   HEAD, so nothing below changes when the pin is lifted.
--
--   Lift it by deleting the `commit` line, but only once Neovim is on 0.12.
--
--   Upstream also swapped plenary for lewis6991/async.nvim around the same
--   time; that dependency is required at this pin too, not only at HEAD.

return {
    "ThePrimeagen/refactoring.nvim",
    commit = "b712180fd81be069e59249d3a8106157439890e3",
    dependencies = { "lewis6991/async.nvim" },
    keys = {
        {
            "<leader>re",
            function()
                return require("refactoring").extract_func()
            end,
            mode = { "n", "x" },
            expr = true,
            desc = "Extract function (motion)",
        },
        {
            "<leader>rE",
            function()
                return require("refactoring").extract_func_to_file()
            end,
            mode = { "n", "x" },
            expr = true,
            desc = "Extract function to file",
        },
        {
            "<leader>rv",
            function()
                return require("refactoring").extract_var()
            end,
            mode = { "n", "x" },
            expr = true,
            desc = "Extract variable",
        },
        {
            "<leader>ri",
            function()
                return require("refactoring").inline_var()
            end,
            mode = { "n", "x" },
            expr = true,
            desc = "Inline variable",
        },
        {
            "<leader>rI",
            function()
                return require("refactoring").inline_func()
            end,
            mode = { "n", "x" },
            expr = true,
            desc = "Inline function",
        },
        {
            -- Lists only the refactorings valid at the cursor or selection,
            -- which is the discoverable way in. Uses vim.ui.select.
            "<leader>rr",
            function()
                return require("refactoring").select_refactor()
            end,
            mode = { "n", "x" },
            desc = "Refactor menu",
        },
    },

    -- Deliberately no `opts`/`config`. This plugin needs no setup() call, and at
    -- the pinned commit it does not even export one -- lazy.nvim treats `opts`
    -- as "call setup() with this", so an empty table here is not a harmless
    -- default, it is a load-time error.
}
