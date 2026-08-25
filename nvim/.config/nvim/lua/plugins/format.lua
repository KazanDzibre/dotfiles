-- Formatting, including on save.
--
-- conform runs a real formatter per filetype and falls back to the language
-- server when none is configured, so a filetype never silently goes unformatted.

return {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo", "Format" },
    keys = {
        {
            "<leader>cf",
            function()
                require("conform").format({ async = true, lsp_format = "fallback" })
            end,
            mode = { "n", "v" },
            desc = "Format buffer",
        },
        {
            "<leader>uf",
            function()
                vim.g.disable_autoformat = not vim.g.disable_autoformat
                vim.notify("Format on save " .. (vim.g.disable_autoformat and "OFF" or "ON"), vim.log.levels.INFO)
            end,
            desc = "Toggle format on save",
        },
    },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            python = { "ruff_format" },
            rust = { "rustfmt" },
            cs = { "csharpier" },
            sh = { "shfmt" },
            bash = { "shfmt" },
            -- stop_after_first: prettierd is the daemon and much faster; plain
            -- prettier is only tried if it is not running.
            javascript = { "prettierd", "prettier", stop_after_first = true },
            javascriptreact = { "prettierd", "prettier", stop_after_first = true },
            typescript = { "prettierd", "prettier", stop_after_first = true },
            typescriptreact = { "prettierd", "prettier", stop_after_first = true },
            json = { "prettierd", "prettier", stop_after_first = true },
            jsonc = { "prettierd", "prettier", stop_after_first = true },
            yaml = { "prettierd", "prettier", stop_after_first = true },
            html = { "prettierd", "prettier", stop_after_first = true },
            css = { "prettierd", "prettier", stop_after_first = true },
            scss = { "prettierd", "prettier", stop_after_first = true },
            markdown = { "prettierd", "prettier", stop_after_first = true },
        },

        -- Anything not listed above still gets formatted by its language
        -- server, if that server can do it.
        default_format_opts = { lsp_format = "fallback" },

        format_on_save = function(bufnr)
            -- Escape hatches: <leader>uf for the session, :FormatDisable! for
            -- one buffer. Useful when editing someone else's badly formatted
            -- file, where formatting on save would produce a huge diff.
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                return
            end
            return { timeout_ms = 1500, lsp_format = "fallback" }
        end,
    },
    init = function()
        vim.api.nvim_create_user_command("FormatDisable", function(args)
            if args.bang then
                vim.b.disable_autoformat = true -- this buffer only
            else
                vim.g.disable_autoformat = true
            end
        end, { desc = "Disable format on save", bang = true })

        vim.api.nvim_create_user_command("FormatEnable", function()
            vim.b.disable_autoformat = false
            vim.g.disable_autoformat = false
        end, { desc = "Re-enable format on save" })

        vim.api.nvim_create_user_command("Format", function()
            require("conform").format({ async = true, lsp_format = "fallback" })
        end, { desc = "Format the current buffer" })
    end,
}
