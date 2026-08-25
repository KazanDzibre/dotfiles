-- Integrated terminal -- VS Code's Ctrl+`.
--
-- The backend is snacks.nvim, which this config already pulls in as
-- claudecode.nvim's terminal provider (see claude.lua). Using it here costs no
-- extra plugin; this file owns the snacks spec and claude.lua just depends on
-- it.
--
-- Only snacks' `terminal` module is enabled. Every other snacks module stays
-- off -- listing a module in `opts` is what turns it on.
--
-- <C-t> is the toggle in both directions: normal mode opens or restores it,
-- terminal mode hides it again. In stock Neovim <C-t> pops the tag stack, which
-- nothing in this config uses now that gd goes through the LSP.
--
-- Leaving terminal mode without hiding the window is <C-\><C-n>, or a double
-- <Esc> -- snacks' own mapping. claude.lua turns that double-<Esc> off for
-- *its* window only, because Claude uses <Esc><Esc> itself.

return {
    "folke/snacks.nvim",
    lazy = true,
    opts = {
        terminal = {
            win = {
                keys = {
                    nuketown_hide_term = {
                        "<C-t>",
                        function(self)
                            self:hide()
                        end,
                        mode = "t",
                        desc = "Hide terminal",
                    },
                },
            },
        },
    },
    keys = {
        {
            "<C-t>",
            function()
                require("snacks").terminal.toggle()
            end,
            desc = "Toggle terminal",
        },
        {
            "<leader>tt",
            function()
                require("snacks").terminal.toggle()
            end,
            desc = "Toggle terminal",
        },
        {
            -- A different opts table means a different terminal, so the float
            -- and the split are two independent shells rather than one window
            -- that changes shape.
            "<leader>tf",
            function()
                require("snacks").terminal.toggle(nil, {
                    win = { position = "float", border = "rounded", width = 0.85, height = 0.8 },
                })
            end,
            desc = "Toggle floating terminal",
        },
        {
            "<leader>tn",
            function()
                require("snacks").terminal.open()
            end,
            desc = "New terminal",
        },
    },
}
