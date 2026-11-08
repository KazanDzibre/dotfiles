-- pywal.lua — a colourscheme built live from the wallpaper's pywal palette.
--
-- Reads ~/.cache/wal/colors.json each time it is applied. `theme-sync` tells
-- running editors to re-apply it when the wallpaper changes.

local path = vim.fn.expand("~/.cache/wal/colors.json")
local file = io.open(path, "r")
if not file then
    vim.notify("pywal: no palette at " .. path, vim.log.levels.WARN)
    return
end
local data = vim.json.decode(file:read("*a"))
file:close()

local function channels(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

local function mix(a, b, t)
    local ar, ag, ab = channels(a)
    local br, bg, bb = channels(b)
    return string.format("#%02x%02x%02x", ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
end

local bg, fg = data.special.background, data.special.foreground
local c = data.colors
local p = {
    bg = bg,
    fg = fg,
    dark = mix(bg, "#000000", 0.25),
    surface = mix(bg, fg, 0.07),
    raised = mix(bg, fg, 0.14),
    border = mix(bg, fg, 0.24),
    comment = mix(fg, bg, 0.45),
    dim = mix(fg, bg, 0.28),
    a1 = mix(c.color1, fg, 0.25),
    a2 = mix(c.color2, fg, 0.25),
    a3 = mix(c.color3, fg, 0.25),
    a4 = mix(c.color4, fg, 0.25),
    a5 = mix(c.color5, fg, 0.25),
    a6 = mix(c.color6, fg, 0.25),
    good = "#8ad79a",
    warn = "#f0c674",
    crit = "#f0808f",
}

vim.cmd("highlight clear")
vim.g.colors_name = "pywal"
vim.o.termguicolors = true

local groups = {
    Normal = { fg = p.fg, bg = p.bg },
    NormalNC = { fg = p.fg, bg = p.bg },
    NormalFloat = { fg = p.fg, bg = p.dark },
    FloatBorder = { fg = p.border, bg = p.dark },
    FloatTitle = { fg = p.a5, bg = p.dark, bold = true },
    Cursor = { fg = p.bg, bg = p.fg },
    CursorLine = { bg = p.surface },
    CursorColumn = { bg = p.surface },
    CursorLineNr = { fg = p.a5, bold = true },
    LineNr = { fg = p.comment },
    SignColumn = { bg = p.bg },
    ColorColumn = { bg = p.surface },
    VertSplit = { fg = p.border },
    WinSeparator = { fg = p.border },
    Visual = { bg = p.border },
    Search = { fg = p.bg, bg = p.a3 },
    IncSearch = { fg = p.bg, bg = p.a5 },
    CurSearch = { fg = p.bg, bg = p.a5 },
    MatchParen = { fg = p.a5, bold = true, underline = true },
    Pmenu = { fg = p.fg, bg = p.dark },
    PmenuSel = { fg = p.bg, bg = p.a5, bold = true },
    PmenuSbar = { bg = p.surface },
    PmenuThumb = { bg = p.border },
    StatusLine = { fg = p.fg, bg = p.raised },
    StatusLineNC = { fg = p.comment, bg = p.surface },
    TabLine = { fg = p.comment, bg = p.dark },
    TabLineSel = { fg = p.fg, bg = p.bg, bold = true },
    TabLineFill = { bg = p.dark },
    Folded = { fg = p.comment, bg = p.surface },
    FoldColumn = { fg = p.comment },
    NonText = { fg = p.border },
    Whitespace = { fg = p.border },
    SpecialKey = { fg = p.border },
    Directory = { fg = p.a4 },
    Title = { fg = p.a5, bold = true },
    ErrorMsg = { fg = p.crit, bold = true },
    WarningMsg = { fg = p.warn },
    MoreMsg = { fg = p.good },
    Question = { fg = p.good },
    ModeMsg = { fg = p.fg, bold = true },

    Comment = { fg = p.comment, italic = true },
    Constant = { fg = p.a3 },
    String = { fg = p.a2 },
    Character = { fg = p.a2 },
    Number = { fg = p.a3 },
    Boolean = { fg = p.a3 },
    Float = { fg = p.a3 },
    Identifier = { fg = p.fg },
    Function = { fg = p.a4 },
    Statement = { fg = p.a5 },
    Conditional = { fg = p.a5 },
    Repeat = { fg = p.a5 },
    Label = { fg = p.a5 },
    Operator = { fg = p.dim },
    Keyword = { fg = p.a5, bold = true },
    Exception = { fg = p.a1 },
    PreProc = { fg = p.a6 },
    Include = { fg = p.a6 },
    Define = { fg = p.a6 },
    Macro = { fg = p.a6 },
    Type = { fg = p.a1 },
    StorageClass = { fg = p.a5 },
    Structure = { fg = p.a1 },
    Typedef = { fg = p.a1 },
    Special = { fg = p.a6 },
    Delimiter = { fg = p.dim },
    Underlined = { underline = true },
    Bold = { bold = true },
    Italic = { italic = true },
    Error = { fg = p.crit },
    Todo = { fg = p.bg, bg = p.warn, bold = true },

    DiffAdd = { bg = mix(p.bg, p.good, 0.18) },
    DiffChange = { bg = mix(p.bg, p.warn, 0.14) },
    DiffDelete = { bg = mix(p.bg, p.crit, 0.18) },
    DiffText = { bg = mix(p.bg, p.warn, 0.32) },
    Added = { fg = p.good },
    Changed = { fg = p.warn },
    Removed = { fg = p.crit },
    GitSignsAdd = { fg = p.good },
    GitSignsChange = { fg = p.warn },
    GitSignsDelete = { fg = p.crit },

    DiagnosticError = { fg = p.crit },
    DiagnosticWarn = { fg = p.warn },
    DiagnosticInfo = { fg = p.a4 },
    DiagnosticHint = { fg = p.a6 },
    DiagnosticUnderlineError = { undercurl = true, sp = p.crit },
    DiagnosticUnderlineWarn = { undercurl = true, sp = p.warn },
    DiagnosticUnderlineInfo = { undercurl = true, sp = p.a4 },
    DiagnosticUnderlineHint = { undercurl = true, sp = p.a6 },

    ["@variable"] = { fg = p.fg },
    ["@variable.parameter"] = { fg = p.dim, italic = true },
    ["@variable.member"] = { fg = p.fg },
    ["@property"] = { fg = p.fg },
    ["@function"] = { link = "Function" },
    ["@function.builtin"] = { fg = p.a6 },
    ["@function.method"] = { link = "Function" },
    ["@constructor"] = { fg = p.a1 },
    ["@keyword"] = { link = "Keyword" },
    ["@keyword.return"] = { fg = p.a5, bold = true },
    ["@type"] = { link = "Type" },
    ["@type.builtin"] = { fg = p.a1, italic = true },
    ["@string"] = { link = "String" },
    ["@number"] = { link = "Number" },
    ["@boolean"] = { link = "Boolean" },
    ["@comment"] = { link = "Comment" },
    ["@punctuation"] = { fg = p.dim },
    ["@punctuation.bracket"] = { fg = p.dim },
    ["@punctuation.delimiter"] = { fg = p.dim },
    ["@tag"] = { fg = p.a5 },
    ["@tag.attribute"] = { fg = p.a3 },
    ["@tag.delimiter"] = { fg = p.dim },
    ["@markup.heading"] = { fg = p.a5, bold = true },
    ["@markup.link"] = { fg = p.a4, underline = true },
    ["@markup.raw"] = { fg = p.a2 },
    ["@lsp.type.parameter"] = { link = "@variable.parameter" },
    ["@lsp.type.property"] = { link = "@property" },
    ["@lsp.type.variable"] = { link = "@variable" },

    TelescopeNormal = { fg = p.fg, bg = p.dark },
    TelescopeBorder = { fg = p.border, bg = p.dark },
    TelescopeSelection = { bg = p.raised, bold = true },
    TelescopeMatching = { fg = p.a5, bold = true },
    NeoTreeNormal = { fg = p.fg, bg = p.dark },
    NeoTreeNormalNC = { fg = p.fg, bg = p.dark },
    NeoTreeDirectoryIcon = { fg = p.a4 },
    NeoTreeDirectoryName = { fg = p.fg },
    CmpItemAbbrMatch = { fg = p.a5, bold = true },
    CmpItemKind = { fg = p.a4 },
}

for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
end

for i = 0, 15 do
    vim.g["terminal_color_" .. i] = c["color" .. i]
end
