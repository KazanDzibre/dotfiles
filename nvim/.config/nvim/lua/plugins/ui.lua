-- Statusline, icons, and keymap discovery.

-- Where lualine's diff component gets its numbers. Without this it runs
-- `git diff --shortstat` on a timer; gitsigns has already computed the same
-- thing for the buffer, so read it from there instead.
local function git_diff_source()
    local gs = vim.b.gitsigns_status_dict
    if gs then
        return { added = gs.added, modified = gs.changed, removed = gs.removed }
    end
end

return {
    -- Nerd Font icons used by neo-tree and lualine. The terminal already uses
    -- CaskaydiaCove Nerd Font Mono, so these render without extra setup.
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
        opts = {},
    },

    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        opts = {
            options = {
                theme = "auto", -- follows whatever colourscheme is active
                globalstatus = true, -- one statusline, not one per split
                section_separators = { left = "", right = "" },
                component_separators = { left = "", right = "" },
            },
            sections = {
                -- Branch plus +/~/- counts, read from gitsigns rather than by
                -- shelling out to git on every redraw.
                lualine_b = {
                    "branch",
                    { "diff", source = git_diff_source },
                    "diagnostics",
                },
                lualine_c = {
                    { "filename", path = 1 }, -- path relative to cwd
                },
                lualine_x = { "encoding", "fileformat", "filetype" },
            },
        },
    },

    -- Press <leader> (or any prefix) and wait: which-key lists what is
    -- available. This doubles as the in-editor half of the cheatsheet.
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "modern",
            spec = {
                { "<leader>a", group = "ai (claude)" },
                { "<leader>b", group = "buffer" },
                { "<leader>c", group = "code" },
                { "<leader>f", group = "find" },
                { "<leader>g", group = "git" },
                { "<leader>n", group = "npm packages" },
                { "<leader>r", group = "refactor" },
                -- Capital R, separate from <leader>r: kulala's HTTP runner.
                { "<leader>R", group = "http requests" },
                { "<leader>s", group = "search / replace" },
                { "<leader>t", group = "terminal" },
                { "<leader>u", group = "ui" },
            },
        },
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = true })
                end,
                desc = "All keymaps",
            },
        },
    },
}
