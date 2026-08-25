-- Small editing conveniences that VS Code has switched on out of the box:
-- auto-closing pairs, auto-closing tags, TODO highlighting, colour swatches.
--
-- None of these are load-bearing -- each one can be removed on its own without
-- touching anything else in this config.

return {
    -- Auto-close brackets, quotes and friends.
    --
    -- `check_ts` makes the decision with treesitter rather than by counting
    -- characters, so typing a quote inside a Lua string or a JS template
    -- literal does not insert a stray closing one.
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {
            check_ts = true,
            ts_config = {
                lua = { "string" },
                javascript = { "template_string" },
            },
            -- Surround the rest of the line with the pair being typed: <M-e>.
            fast_wrap = {},
        },
    },

    -- Auto-close and auto-rename HTML/JSX tags.
    --
    -- Renaming is the half that is hard to live without: editing the opening
    -- tag rewrites the closing one. It is driven by treesitter, so a filetype
    -- only works if its parser is in treesitter.lua's ensure_installed.
    {
        "windwp/nvim-ts-autotag",
        ft = {
            "html",
            "xml",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "markdown",
        },
        opts = {},
    },

    -- TODO / FIXME / HACK / NOTE highlighting, plus a project-wide list of them.
    --
    -- The search backend is ripgrep. `:TodoTelescope` needs telescope, which is
    -- lazy-loaded on its own commands -- calling it here loads it on demand.
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        event = { "BufReadPost", "BufNewFile" },
        cmd = { "TodoTelescope", "TodoQuickFix", "TodoLocList" },
        keys = {
            {
                "]t",
                function()
                    require("todo-comments").jump_next()
                end,
                desc = "Next TODO comment",
            },
            {
                "[t",
                function()
                    require("todo-comments").jump_prev()
                end,
                desc = "Previous TODO comment",
            },
            { "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "Find TODO comments" },
            {
                "<leader>fT",
                "<cmd>TodoTelescope keywords=TODO,FIX,FIXME,BUG<CR>",
                desc = "Find TODO / FIX only",
            },
        },
        opts = {
            signs = true,
            highlight = {
                -- Colour the keyword only, not the whole comment -- a wide
                -- background block on every NOTE gets loud fast.
                keyword = "wide_fg",
                after = "",
            },
        },
    },

    -- Inline colour swatches: #1e1e2e, rgb(), hsl(), and CSS colour functions
    -- get painted in the colour they name.
    --
    -- This is the maintained fork; NvChad/nvim-colorizer.lua now redirects here.
    --
    -- `names = false` matters: with it on, the *words* "red", "green" and "tan"
    -- are treated as colours, which lights up ordinary prose and identifiers.
    --
    -- The filetype list is aimed at this repo as much as at web work -- eww's
    -- yuck, rofi's rasi and the pywal scss templates are all colour soup.
    {
        "catgoose/nvim-colorizer.lua",
        main = "colorizer",
        event = "BufReadPre",
        keys = {
            { "<leader>uc", "<cmd>ColorizerToggle<CR>", desc = "Toggle colour swatches" },
        },
        opts = {
            filetypes = {
                "css",
                "scss",
                "sass",
                "less",
                "html",
                "javascript",
                "javascriptreact",
                "typescript",
                "typescriptreact",
                "vue",
                "svelte",
                "json",
                "jsonc",
                "yaml",
                "toml",
                "lua",
                "vim",
                "conf",
                "dosini",
                "yuck",
                "rasi",
            },
            user_default_options = {
                names = false,
                css = true, -- rgb(), hsl(), and the rest of the CSS functions
                css_fn = true,
                tailwind = true, -- bg-red-500 and friends
                mode = "background",
            },
        },
    },
}
