-- Tree-sitter: real syntax trees rather than regex highlighting.
--
-- This is what makes highlighting correct in mixed files (JSX inside JS, SQL in
-- a string, markdown code fences) and what indentation and text objects read.
--
-- Parsers are compiled locally on install, which needs gcc -- present here.

return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    main = "nvim-treesitter.configs",
    opts = {
        ensure_installed = {
            -- always needed by neovim itself
            "lua",
            "vim",
            "vimdoc",
            "query",
            "regex",
            -- web
            "javascript",
            "typescript",
            "tsx",
            "html",
            "css",
            "scss",
            "json",
            "jsonc",
            -- .NET
            "c_sharp",
            -- systems
            "c",
            "cpp",
            "rust",
            "go",
            -- scripting
            "bash",
            "python",
            -- data and config
            "yaml",
            "toml",
            "sql",
            "dockerfile",
            "markdown",
            "markdown_inline",
            "diff",
            "gitcommit",
            "gitignore",
        },
        auto_install = true, -- grab a parser when an unknown filetype opens
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        incremental_selection = {
            enable = true,
            keymaps = {
                init_selection = "<C-space>",
                node_incremental = "<C-space>",
                node_decremental = "<BS>",
                scope_incremental = false,
            },
        },
    },
}
