-- File tree in a side split, the VS Code explorer equivalent.

return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    -- Loaded on the key or the command, not at startup.
    cmd = "Neotree",
    keys = {
        { "<C-b>", "<cmd>Neotree toggle<CR>", desc = "Toggle file tree" },
        { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle file tree" },
        { "<leader>o", "<cmd>Neotree focus<CR>", desc = "Focus file tree" },
        -- Same sidebar, but listing only what git says changed -- the closest
        -- thing to VS Code's Source Control view. Enter opens the file, A
        -- stages it, gu unstages, gc commits.
        { "<leader>ge", "<cmd>Neotree git_status<CR>", desc = "Git changes (sidebar)" },
    },
    opts = {
        close_if_last_window = true, -- do not leave a lone tree behind
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = true,
        filesystem = {
            follow_current_file = { enabled = true }, -- reveal the open buffer
            use_libuv_file_watcher = true, -- react to changes made outside nvim
            filtered_items = {
                hide_dotfiles = false, -- this is a dotfiles repo
                hide_gitignored = true,
                hide_by_name = { ".git", "node_modules", "__pycache__" },
            },
        },
        window = {
            width = 34,
            mappings = {
                ["<space>"] = "none", -- keep <leader> usable inside the tree
                ["l"] = "open",
                ["h"] = "close_node",
                ["<C-b>"] = "close_window",
            },
        },
        default_component_configs = {
            indent = { with_expanders = true },
            git_status = {
                symbols = {
                    added = "",
                    modified = "",
                    deleted = "✖",
                    renamed = "󰁕",
                    untracked = "",
                    ignored = "",
                    unstaged = "󰄱",
                    staged = "",
                    conflict = "",
                },
            },
        },
    },
}
