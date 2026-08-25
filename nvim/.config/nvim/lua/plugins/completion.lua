-- Completion popup, signature help and snippets -- the as-you-type half of
-- VS Code parity.
--
-- blink.cmp rather than nvim-cmp: one plugin instead of six, and it ships its
-- own snippet engine so LuaSnip + cmp-* sources are not needed. `version` is
-- pinned to a release tag so it downloads a prebuilt binary instead of needing
-- a Rust build.

return {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
        keymap = {
            -- Tab accepts and cycles, which is the VS Code muscle memory.
            -- Also available: <C-space> to open, <C-e> to dismiss.
            preset = "super-tab",
        },

        appearance = {
            -- Nerd Font Mono is what foot uses; this keeps the icon column
            -- from being half a character wide.
            nerd_font_variant = "mono",
        },

        completion = {
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200,
                window = { border = "rounded" },
            },
            menu = {
                border = "rounded",
                draw = { treesitter = { "lsp" } },
            },
            -- Inline preview of what accepting would insert.
            ghost_text = { enabled = true },
        },

        signature = {
            enabled = true,
            window = { border = "rounded" },
        },

        sources = {
            default = { "lsp", "path", "snippets", "buffer" },
        },

        -- Rust fuzzy matcher; falls back to the Lua one if the prebuilt binary
        -- is unavailable, rather than breaking completion entirely.
        fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
}
