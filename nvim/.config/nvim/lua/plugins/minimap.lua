-- VS Code's code preview strip, down the right-hand edge of every window.

return {
    {
        "Isrothy/neominimap.nvim",
        version = "v3.*",
        -- Not lazy: the plugin installs its own autocmds and only builds a
        -- minimap once a real file buffer exists, so there is nothing to gain
        -- from deferring it — and a lazy trigger would miss the first buffer.
        lazy = false,
        init = function()
            -- `float` puts a minimap on top of the right edge of each window,
            -- so it follows splits the way VS Code's does. The cost is that it
            -- covers text: sidescrolloff has to be wider than the minimap so
            -- the view scrolls before the cursor slides underneath it.
            -- (The alternative, layout = "split", reserves real columns but
            -- gives one shared minimap per tab instead of one per window.)
            vim.opt.sidescrolloff = 26

            -- Read once, at load: neominimap takes its whole configuration
            -- from this global rather than from a setup() call.
            ---@type Neominimap.UserConfig
            vim.g.neominimap = {
                auto_enable = true,
                layout = "float",
                float = {
                    minimap_width = 20,
                    -- No border, matching the rest of the look — the minimap
                    -- should read as part of the buffer, not a framed panel.
                    window_border = "none",
                    z_index = 1, -- under completion menus and which-key
                },
                -- Click to jump, but keep the cursor in the code afterwards,
                -- which is what clicking VS Code's minimap does.
                click = {
                    enabled = true,
                    auto_switch_focus = false,
                },
                -- VS Code marks search hits in the minimap too; diagnostics,
                -- git signs and treesitter colours are on by default.
                search = {
                    enabled = true,
                },
                -- Sidebars and scratch panels get no minimap. Most already
                -- have buftype "nofile", which is excluded by default; these
                -- are the ones that do not.
                exclude_filetypes = {
                    "help",
                    "bigfile",
                    "neo-tree",
                    "NeogitStatus",
                    "NeogitCommitMessage",
                    "DiffviewFiles",
                    "Outline",
                    "lazy",
                    "mason",
                    "checkhealth",
                    "man",
                },
            }
        end,
        keys = {
            { "<leader>um", "<cmd>Neominimap Toggle<cr>", desc = "Toggle minimap" },
            { "<leader>uM", "<cmd>Neominimap ToggleFocus<cr>", desc = "Focus minimap" },
        },
    },
}
