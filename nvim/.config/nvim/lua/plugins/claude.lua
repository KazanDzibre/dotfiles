-- Claude Code in a split, the way the VS Code extension works.
--
-- Neovim has no official Claude Code extension -- Anthropic ships VS Code and
-- JetBrains only. claudecode.nvim is a pure-Lua reimplementation of the same
-- WebSocket/MCP protocol those extensions speak, so the CLI running in the
-- terminal split is not just a shell: it knows which file is open, sees the
-- visual selection, opens files in this Neovim, and proposes edits as a real
-- native diff you can edit before accepting.
--
-- The plain alternative is `:terminal claude`, which works today and needs no
-- plugin -- but that Claude sees only what is typed into it.
--
-- snacks.nvim is the terminal backend (hide/restore, float support). Its spec
-- lives in terminal.lua, which owns it -- this is only a dependency edge, so
-- snacks is guaranteed loaded before claudecode asks for a terminal.

return {
    {
        "coder/claudecode.nvim",
        dependencies = { "folke/snacks.nvim" },

        -- Commands are declared so lazy.nvim creates stubs for them: `:ClaudeCode`
        -- has to exist on a fresh start, before any <leader>a key is pressed.
        cmd = {
            "ClaudeCode",
            "ClaudeCodeFocus",
            "ClaudeCodeSelectModel",
            "ClaudeCodeAdd",
            "ClaudeCodeSend",
            "ClaudeCodeTreeAdd",
            "ClaudeCodeStatus",
            "ClaudeCodeStart",
            "ClaudeCodeStop",
            "ClaudeCodeDiffAccept",
            "ClaudeCodeDiffDeny",
            "ClaudeCodeCloseAllDiffs",
        },

        keys = {
            -- One chord from anywhere, even mid-sentence or from inside the
            -- Claude split itself -- Zed's alt-a does the same.
            { "<M-a>", "<cmd>ClaudeCode<CR>", mode = { "n", "i", "t" }, desc = "Toggle Claude" },
            { "<leader>ac", "<cmd>ClaudeCode<CR>", desc = "Toggle Claude" },
            { "<leader>af", "<cmd>ClaudeCodeFocus<CR>", desc = "Focus Claude" },
            { "<leader>ar", "<cmd>ClaudeCode --resume<CR>", desc = "Resume a session" },
            { "<leader>aC", "<cmd>ClaudeCode --continue<CR>", desc = "Continue last session" },
            { "<leader>am", "<cmd>ClaudeCodeSelectModel<CR>", desc = "Pick model" },
            { "<leader>ax", "<cmd>ClaudeCodeStop<CR>", desc = "Stop the server" },

            -- Context. <leader>ab hands Claude the whole file; in visual mode
            -- <leader>as hands it exactly what is selected, which is the thing
            -- the plain `:terminal claude` cannot do.
            { "<leader>ab", "<cmd>ClaudeCodeAdd %<CR>", desc = "Add this buffer" },
            { "<leader>as", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "Send selection" },
            {
                -- Same key on a file in the tree: @-mention it.
                "<leader>as",
                "<cmd>ClaudeCodeTreeAdd<CR>",
                desc = "Add file to context",
                ft = { "neo-tree", "netrw" },
            },

            -- Diffs. :w and :q do the same from inside the diff window.
            { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<CR>", desc = "Accept diff" },
            { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<CR>", desc = "Reject diff" },
        },

        opts = {
            -- Neovim started from sway/rofi does not necessarily inherit the
            -- shell PATH that puts ~/.local/bin first, and that is where the
            -- CLI lives. Resolve it here rather than hoping bare "claude" is
            -- on $PATH.
            terminal_cmd = vim.fn.exepath("claude") ~= "" and vim.fn.exepath("claude")
                or vim.fn.expand("~/.local/bin/claude"),

            auto_start = true, -- start the MCP server with the plugin
            track_selection = true, -- Claude follows the cursor and selection
            log_level = "info",

            terminal = {
                provider = "snacks",
                split_side = "right", -- opposite the file tree
                split_width_percentage = 0.35,
                auto_close = true,

                snacks_win_opts = {
                    -- snacks maps a double <Esc> in terminal mode to "leave
                    -- terminal mode", which eats Claude's own double-Esc
                    -- (jump back to an earlier message). Turn it off; the
                    -- builtin <C-\><C-n> still leaves terminal mode.
                    keys = { term_normal = false },
                },
            },

            diff_opts = {
                layout = "vertical", -- side by side, like diffview
                open_in_new_tab = false,
                auto_resize_terminal = true,
            },
        },
    },
}
