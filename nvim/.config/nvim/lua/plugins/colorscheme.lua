-- Colourschemes. All are loaded eagerly (lazy = false) with a high priority so
-- switching between them at runtime never hits a not-yet-loaded plugin.
--
-- The active one is chosen by core/theme.lua, not here.

return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        opts = {
            flavour = "mocha",
            transparent_background = false,
            styles = {
                comments = { "italic" },
                keywords = { "italic" },
            },
            integrations = {
                neotree = true,
                treesitter = true,
                which_key = true,
                native_lsp = { enabled = true },
            },
        },
    },

    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 900,
        opts = { style = "night" },
    },

    {
        "ellisonleao/gruvbox.nvim",
        lazy = false,
        priority = 900,
        opts = { contrast = "hard" },
    },

    {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 900,
        opts = {},
    },
}
