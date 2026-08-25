-- Git: the GitLens + Source Control half of VS Code parity.
--
-- Three plugins, each doing one job:
--
--   gitsigns   in the buffer -- change bars in the gutter, "who touched this
--              line" as virtual text at the end of it, stage/reset a single hunk
--   diffview   the diff viewer -- a file panel of everything that changed, and
--              per-file or per-repo history with the diff of each commit
--   neogit     the SourceTree-ish panel -- stage, unstage, commit, push, pull,
--              branch, stash, log, all from one buffer
--
-- gitsigns is the only one that loads at startup; the other two are behind
-- their commands.

return {
    -- ── gitsigns: signs, inline blame, hunk actions ─────────────────────────
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add = { text = "▎" },
                change = { text = "▎" },
                delete = { text = "" },
                topdelete = { text = "" },
                changedelete = { text = "▎" },
                untracked = { text = "▎" },
            },
            signs_staged_enable = true,

            -- This is the GitLens line. Off by default would mean turning it on
            -- every session, so it starts on; <leader>gt turns it off when the
            -- extra text at the end of the line gets in the way.
            current_line_blame = true,
            current_line_blame_opts = {
                virt_text = true,
                virt_text_pos = "eol",
                delay = 300,
                ignore_whitespace = false,
            },
            -- Same information GitLens shows: who, how long ago, and the commit
            -- subject. <abbrev_sha> makes it copyable for a git show.
            current_line_blame_formatter = "  <author>, <author_time:%R> · <abbrev_sha> <summary>",

            preview_config = { border = "rounded" },

            on_attach = function(bufnr)
                local gs = require("gitsigns")

                local function map(mode, keys, fn, desc)
                    vim.keymap.set(mode, keys, fn, { buffer = bufnr, desc = "Git: " .. desc })
                end

                -- Hunk navigation. ]c / [c are vim's own diff-mode motions, so
                -- reusing them keeps muscle memory when actually in a diff --
                -- hence the diff_mode check rather than an unconditional map.
                map("n", "]c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "]c", bang = true })
                    else
                        gs.nav_hunk("next")
                    end
                end, "Next hunk")

                map("n", "[c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "[c", bang = true })
                    else
                        gs.nav_hunk("prev")
                    end
                end, "Previous hunk")

                -- Staging, the VS Code gutter "+" / "undo" buttons.
                map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
                map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
                map("v", "<leader>gs", function()
                    gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Stage selected lines")
                map("v", "<leader>gr", function()
                    gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Reset selected lines")
                map("n", "<leader>gS", gs.stage_buffer, "Stage whole file")
                map("n", "<leader>gR", gs.reset_buffer, "Reset whole file")
                map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")

                -- Blame. The popup is the GitLens hover; the pane is its
                -- file-blame view, one commit per line down the left.
                map("n", "<leader>gb", function()
                    gs.blame_line({ full = true })
                end, "Blame this line")
                map("n", "<leader>gB", gs.blame, "Blame whole file (pane)")
                map("n", "<leader>gt", gs.toggle_current_line_blame, "Toggle inline blame")

                -- This buffer against the index, side by side.
                map("n", "<leader>gv", gs.diffthis, "Diff this file")

                -- ih works as a text object: `dih` deletes the hunk under the
                -- cursor, `vih` selects it.
                map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
            end,
        },
    },

    -- ── diffview: the diff viewer and history browser ───────────────────────
    {
        "sindrets/diffview.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose", "DiffviewToggleFiles" },
        keys = {
            { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Diff all changes" },
            { "<leader>gf", "<cmd>DiffviewFileHistory %<CR>", desc = "History of this file" },
            { "<leader>gF", "<cmd>DiffviewFileHistory<CR>", desc = "History of this branch" },
            { "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Close diffview" },
        },
        opts = {
            enhanced_diff_hl = true,
            view = {
                -- Two panes, mine on the left and theirs on the right, which is
                -- the layout VS Code's diff editor uses.
                default = { layout = "diff2_horizontal", winbar_info = true },
                file_history = { layout = "diff2_horizontal", winbar_info = true },
                -- Three-way during a merge: both sides plus the result.
                merge_tool = { layout = "diff3_horizontal", disable_diagnostics = true },
            },
            file_panel = {
                listing_style = "tree",
                win_config = { position = "left", width = 34 }, -- matches neo-tree
            },
            keymaps = {
                -- q closes the whole tab from anywhere inside it, rather than
                -- leaving a stray diff window behind.
                view = { { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } } },
                file_panel = { { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } } },
                file_history_panel = { { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } } },
            },
        },
    },

    -- ── neogit: stage, commit, push, branch ─────────────────────────────────
    {
        "NeogitOrg/neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",
            "nvim-telescope/telescope.nvim",
        },
        cmd = "Neogit",
        keys = {
            -- VS Code opens source control with Ctrl+Shift+G; a terminal cannot
            -- tell Ctrl+G from Ctrl+Shift+G, so this is plain <C-g>. It costs
            -- the builtin "show file info", which <leader>fb and the statusline
            -- already cover.
            { "<C-g>", "<cmd>Neogit<CR>", desc = "Git panel" },
            { "<leader>gg", "<cmd>Neogit<CR>", desc = "Git panel" },
            { "<leader>gc", "<cmd>Neogit commit<CR>", desc = "Commit" },
            { "<leader>gP", "<cmd>Neogit push<CR>", desc = "Push" },
            { "<leader>gl", "<cmd>Neogit pull<CR>", desc = "Pull" },
        },
        opts = {
            kind = "tab", -- a full tab, not a split fighting the file tree
            graph_style = "unicode", -- a real log graph, needs no extra binary
            disable_hint = false, -- keep the key hints at the top of the status
            integrations = {
                diffview = true, -- d on a file opens it in diffview
                telescope = true, -- branch/commit pickers use telescope
            },
            signs = {
                section = { "", "" },
                item = { "", "" },
            },
        },
    },
}
