-- Node / Express and .NET ecosystem tooling -- the parts VS Code ships that a
-- language server alone does not give you.
--
--   package-info  npm versions rendered inline in package.json
--   kulala        a REST client for .http files, i.e. Thunder Client
--
-- JSON/YAML schema completion is the third piece and lives in lsp.lua, wired
-- into jsonls and yamlls via SchemaStore.

return {
    -- Latest / outdated npm versions as virtual text next to each dependency in
    -- package.json, plus install / update / delete without leaving the file.
    --
    -- Shells out to `npm` (present) and uses `jq` when it is installed (it is)
    -- to parse the registry response.
    --
    -- Keys are buffer-local, set when a package.json is opened, so <leader>n is
    -- free everywhere else -- the same approach gitsigns takes in git.lua.
    {
        "vuki656/package-info.nvim",
        dependencies = { "MunifTanjim/nui.nvim" },
        event = { "BufRead package.json" },
        opts = {
            package_manager = "npm",
            autostart = true,
            hide_up_to_date = false, -- seeing "you are current" is the point
            hide_unstable_versions = true,
        },
        config = function(_, opts)
            require("package-info").setup(opts)

            vim.api.nvim_create_autocmd("BufEnter", {
                group = vim.api.nvim_create_augroup("nuketown_package_info", { clear = true }),
                pattern = "package.json",
                callback = function(event)
                    local pi = require("package-info")
                    local function map(keys, fn, desc)
                        vim.keymap.set("n", keys, fn, { buffer = event.buf, desc = "npm: " .. desc })
                    end

                    map("<leader>ns", pi.show, "Show versions")
                    map("<leader>nh", pi.hide, "Hide versions")
                    map("<leader>nt", pi.toggle, "Toggle versions")
                    map("<leader>nu", pi.update, "Update package on this line")
                    map("<leader>nd", pi.delete, "Delete package on this line")
                    map("<leader>ni", pi.install, "Install a new package")
                    map("<leader>nc", pi.change_version, "Change version on this line")

                    local ok, wk = pcall(require, "which-key")
                    if ok then
                        wk.add({ { "<leader>n", group = "npm", buffer = event.buf } })
                    end
                end,
            })
        end,
    },

    -- REST client: write requests in a .http file, run them from the cursor,
    -- read the response in a split. The same format VS Code's REST Client and
    -- JetBrains' HTTP client use, so a .http file checked into an Express or
    -- ASP.NET repo works in all three.
    --
    -- Requests go out through `curl` and responses are formatted with `jq`;
    -- both are installed.
    {
        "mistweaverco/kulala.nvim",
        ft = { "http", "rest" },
        keys = {
            -- The one key worth having outside a .http buffer: a throwaway
            -- request buffer for poking at an endpoint once.
            {
                "<leader>Rs",
                function()
                    require("kulala").scratchpad()
                end,
                desc = "REST scratchpad",
            },
        },
        init = function()
            -- Make sure .http and .rest open as an http buffer, which is what
            -- the `ft` above waits for.
            vim.filetype.add({ extension = { http = "http", rest = "http" } })
        end,
        opts = {
            display_mode = "split",
            default_view = "body",
        },
        config = function(_, opts)
            require("kulala").setup(opts)

            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("nuketown_kulala", { clear = true }),
                pattern = "http",
                callback = function(event)
                    local kulala = require("kulala")
                    local function map(keys, fn, desc)
                        vim.keymap.set("n", keys, fn, { buffer = event.buf, desc = "REST: " .. desc })
                    end

                    map("<leader>Rr", kulala.run, "Run request under cursor")
                    map("<leader>Ra", kulala.run_all, "Run every request in the file")
                    map("<leader>Rp", kulala.replay, "Replay last request")
                    map("<leader>Rt", kulala.toggle_view, "Toggle body / headers")
                    map("<leader>Rc", kulala.copy, "Copy as curl")
                    map("<leader>Rq", kulala.close, "Close response window")
                    map("]r", kulala.jump_next, "Next request")
                    map("[r", kulala.jump_prev, "Previous request")

                    local ok, wk = pcall(require, "which-key")
                    if ok then
                        wk.add({ { "<leader>R", group = "rest client", buffer = event.buf } })
                    end
                end,
            })
        end,
    },
}
