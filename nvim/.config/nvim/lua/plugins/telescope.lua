-- Fuzzy finder: files, live grep, buffers, symbols. The Ctrl+P half of VS Code.
--
-- Needs ripgrep (grep) and fd (file listing), both installed system-wide.

return {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    cmd = "Telescope",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            -- Native fzf sorter. Compiled with make; without it the Lua sorter
            -- is used instead, which is noticeably slower on big trees.
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
        },
    },
    keys = {
        { "<C-p>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
        { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
        { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Grep in project" },
        { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
        { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Open buffers" },
        { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
        { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
        { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "Search keymaps" },
        { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "Diagnostics" },
        { "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
        { "<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace symbols" },
        { "<leader>fc", "<cmd>Telescope colorscheme<CR>", desc = "Colourschemes" },
    },
    config = function()
        local telescope = require("telescope")
        local actions = require("telescope.actions")

        -- Debian/Ubuntu ship fd as `fdfind`; the name `fd` belongs to another
        -- package. Telescope looks for `fd` first, so point it at the real
        -- binary rather than letting it fall back to `find`.
        local fd = vim.fn.executable("fd") == 1 and "fd" or (vim.fn.executable("fdfind") == 1 and "fdfind" or nil)

        telescope.setup({
            defaults = {
                prompt_prefix = "   ",
                selection_caret = "  ",
                path_display = { "truncate" },
                sorting_strategy = "ascending",
                layout_config = {
                    horizontal = { prompt_position = "top", preview_width = 0.55 },
                },
                file_ignore_patterns = { "^%.git/", "node_modules/", "%.lock$" },
                mappings = {
                    i = {
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-k>"] = actions.move_selection_previous,
                        ["<Esc>"] = actions.close, -- close from insert directly
                        ["<C-u>"] = false, -- let C-u clear the prompt instead
                    },
                },
            },
            pickers = {
                find_files = {
                    hidden = true, -- this is a dotfiles repo
                    find_command = fd and { fd, "--type", "f", "--hidden", "--strip-cwd-prefix", "--exclude", ".git" }
                        or nil,
                },
            },
            extensions = {
                fzf = {
                    fuzzy = true,
                    override_generic_sorter = true,
                    override_file_sorter = true,
                },
            },
        })

        pcall(telescope.load_extension, "fzf")
    end,
}
