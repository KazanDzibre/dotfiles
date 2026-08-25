-- Language servers: diagnostics, go-to-definition, hover, rename, code actions.
-- This is the half of "VS Code parity" that understands the code; completion
-- lives in plugins/completion.lua.
--
-- mason installs the servers into ~/.local/share/nvim/mason and puts them on
-- nvim's PATH, so nothing has to be installed system-wide.

return {
    {
        "mason-org/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        opts = {
            ui = {
                border = "rounded",
                icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
            },
        },
    },

    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "mason-org/mason.nvim",
            "mason-org/mason-lspconfig.nvim",
            -- Every schema on schemastore.org as a Lua table. This is what makes
            -- package.json, tsconfig.json, appsettings.json, docker-compose.yml
            -- and the GitHub Actions workflow files complete and validate the way
            -- they do in VS Code -- jsonls and yamlls ship with almost none.
            { "b0o/SchemaStore.nvim", lazy = true, version = false },
        },
        config = function()
            -- ── Diagnostics ────────────────────────────────────────────────
            vim.diagnostic.config({
                virtual_text = { spacing = 2, prefix = "●" },
                underline = true,
                update_in_insert = false, -- do not shout while still typing
                severity_sort = true,
                float = { border = "rounded", source = true },
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = " ",
                        [vim.diagnostic.severity.WARN] = " ",
                        [vim.diagnostic.severity.INFO] = " ",
                        [vim.diagnostic.severity.HINT] = "󰌵 ",
                    },
                },
            })

            -- ── Per-buffer keymaps ─────────────────────────────────────────
            -- Set on LspAttach so they only exist where a server is running,
            -- and so `gd` still falls back to its builtin meaning elsewhere.
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("nuketown_lsp_attach", { clear = true }),
                callback = function(event)
                    local function map(keys, fn, desc, mode)
                        vim.keymap.set(mode or "n", keys, fn, { buffer = event.buf, desc = "LSP: " .. desc })
                    end

                    map("gd", vim.lsp.buf.definition, "Go to definition")
                    map("gD", vim.lsp.buf.declaration, "Go to declaration")
                    map("gr", vim.lsp.buf.references, "References")
                    map("gI", vim.lsp.buf.implementation, "Implementations")
                    map("gy", vim.lsp.buf.type_definition, "Type definition")
                    map("K", vim.lsp.buf.hover, "Hover docs")
                    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
                    map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "v" })
                    -- <leader>cf is deliberately NOT mapped here. conform owns
                    -- it, and a buffer-local map would shadow the global one on
                    -- exactly the buffers where formatting matters most.
                    map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
                    map("<leader>cs", vim.lsp.buf.document_symbol, "Document symbols")
                    map("[d", function()
                        vim.diagnostic.jump({ count = -1 })
                    end, "Previous diagnostic")
                    map("]d", function()
                        vim.diagnostic.jump({ count = 1 })
                    end, "Next diagnostic")

                    -- Highlight other uses of the symbol under the cursor.
                    local client = vim.lsp.get_client_by_id(event.data.client_id)

                    -- eslint's autofix is a command on its own server, not a
                    -- formatter, so conform cannot run it. Deliberately not on
                    -- save: prettier already formats there, and the two fight
                    -- over the same lines.
                    if client and client.name == "eslint" then
                        map("<leader>ce", "<cmd>LspEslintFixAll<CR>", "ESLint fix all")
                    end

                    if client and client:supports_method("textDocument/documentHighlight") then
                        local hl_group = vim.api.nvim_create_augroup("nuketown_lsp_highlight", { clear = false })
                        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                            buffer = event.buf,
                            group = hl_group,
                            callback = vim.lsp.buf.document_highlight,
                        })
                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                            buffer = event.buf,
                            group = hl_group,
                            callback = vim.lsp.buf.clear_references,
                        })
                    end
                end,
            })

            -- ── Per-server settings ────────────────────────────────────────
            -- Neovim 0.11 merges these into whatever nvim-lspconfig ships, so
            -- only the differences belong here.
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        -- Stop it complaining that `vim` is undefined.
                        diagnostics = { globals = { "vim" } },
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                    },
                },
            })

            vim.lsp.config("pyright", {
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode = "basic",
                            autoSearchPaths = true,
                            useLibraryCodeForTypes = true,
                        },
                    },
                },
            })

            vim.lsp.config("rust_analyzer", {
                settings = {
                    ["rust-analyzer"] = {
                        cargo = { allFeatures = true },
                        checkOnSave = { command = "clippy" },
                    },
                },
            })

            vim.lsp.config("omnisharp", {
                -- Without this, every C# symbol comes back mangled as
                -- `Foo.Bar.Baz` instead of `Baz`.
                settings = {
                    FormattingOptions = { EnableEditorConfigSupport = true },
                    RoslynExtensionsOptions = {
                        EnableAnalyzersSupport = true,
                        EnableImportCompletion = true,
                    },
                },
            })

            -- ── Which servers to run ───────────────────────────────────────
            vim.lsp.config("jsonls", {
                settings = {
                    json = {
                        schemas = require("schemastore").json.schemas(),
                        validate = { enable = true },
                    },
                },
            })

            vim.lsp.config("yamlls", {
                settings = {
                    yaml = {
                        -- yamlls has its own schema downloader; turning it off and
                        -- handing it SchemaStore's list keeps json and yaml on one
                        -- source and works offline.
                        schemaStore = { enable = false, url = "" },
                        schemas = require("schemastore").yaml.schemas(),
                    },
                },
            })

            local servers = {
                "lua_ls",
                "ts_ls", -- JavaScript / TypeScript
                "omnisharp", -- .NET / C#
                "rust_analyzer",
                "pyright",
                "bashls",
                "clangd", -- C / C++
                "jsonls",
                "yamlls",
                "html",
                "cssls",
                "eslint", -- project's own lint rules, separate from ts_ls
                "dockerls",
                "taplo", -- TOML
                "marksman", -- markdown
            }

            require("mason-lspconfig").setup({
                ensure_installed = servers,
                -- Deliberately NOT `true`. mason-lspconfig would then enable
                -- every server it finds installed, and this machine still has
                -- ~23 left over from an older config -- opening a .ts file
                -- would also spin up tailwindcss, and a .java file jdtls.
                -- Enabling the list explicitly keeps that predictable.
                automatic_enable = false,
            })

            vim.lsp.enable(servers)
        end,
    },
}
