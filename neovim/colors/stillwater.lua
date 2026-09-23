-- Stillwater for Neovim. Warm gruvbox surfaces, muted cyan accent.
-- Syntax lime stays. Enable with :colorscheme stillwater

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "stillwater"
vim.o.termguicolors = true
vim.o.background = "dark"

local p = {
  canvas = "#1d2021",
  raised = "#222526",
  overlay = "#1a1c1d",
  border = "#3c3836",
  text = "#ebdbb2",
  muted = "#8f8f99",
  warm = "#c4a489",
  accent = "#5aa8b4",
  hover = "#6ebcc6",
  deep = "#3d7a88",
  error = "#f44747",
  warning = "#d9c679",
  selection = "#3a4e64",
  comment = "#88846F",
  string = "#E6DB74",
  keyword = "#F92672",
  func = "#A6E22E",
  support = "#66D9EF",
  constant = "#AE81FF",
  parameter = "#FD971F",
  variable = "#F8F8F2",
}

local function hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

hl("Normal", { fg = p.text, bg = p.canvas })
hl("NormalFloat", { fg = p.text, bg = p.raised })
hl("FloatBorder", { fg = p.border, bg = p.raised })
hl("Comment", { fg = p.comment, italic = true })
hl("Constant", { fg = p.constant })
hl("String", { fg = p.string })
hl("Character", { fg = p.string })
hl("Number", { fg = p.constant })
hl("Boolean", { fg = p.constant })
hl("Identifier", { fg = p.variable })
hl("Function", { fg = p.func })
hl("Statement", { fg = p.keyword })
hl("Keyword", { fg = p.keyword })
hl("Conditional", { fg = p.keyword })
hl("Repeat", { fg = p.keyword })
hl("Operator", { fg = p.keyword })
hl("PreProc", { fg = p.keyword })
hl("Type", { fg = p.func })
hl("Special", { fg = p.support })
hl("Underlined", { fg = p.accent, underline = true })
hl("Error", { fg = p.error })
hl("Todo", { fg = p.warning, bold = true })
hl("Cursor", { fg = p.canvas, bg = p.accent })
hl("CursorLine", { bg = p.raised })
hl("CursorLineNr", { fg = p.accent })
hl("LineNr", { fg = p.muted })
hl("VertSplit", { fg = p.border })
hl("WinSeparator", { fg = p.border })
hl("StatusLine", { fg = p.text, bg = p.raised })
hl("StatusLineNC", { fg = p.muted, bg = p.overlay })
hl("TabLine", { fg = p.muted, bg = p.overlay })
hl("TabLineSel", { fg = p.text, bg = p.canvas })
hl("Visual", { bg = p.selection })
hl("Search", { fg = p.canvas, bg = p.accent })
hl("IncSearch", { fg = p.canvas, bg = p.hover })
hl("Pmenu", { fg = p.text, bg = p.raised })
hl("PmenuSel", { fg = p.canvas, bg = p.accent })
hl("PmenuSbar", { bg = p.overlay })
hl("PmenuThumb", { bg = p.border })
hl("MatchParen", { fg = p.accent, bold = true })
hl("ColorColumn", { bg = p.raised })
hl("SignColumn", { bg = p.canvas })
hl("Folded", { fg = p.muted, bg = p.raised })
hl("Directory", { fg = p.accent })
hl("Title", { fg = p.func, bold = true })
hl("ErrorMsg", { fg = p.error })
hl("WarningMsg", { fg = p.warning })
hl("Question", { fg = p.accent })
hl("MoreMsg", { fg = p.accent })
hl("NonText", { fg = p.border })
hl("Whitespace", { fg = p.border })
hl("DiagnosticError", { fg = p.error })
hl("DiagnosticWarn", { fg = p.warning })
hl("DiagnosticInfo", { fg = p.accent })
hl("DiagnosticHint", { fg = p.support })
hl("DiffAdd", { fg = p.func })
hl("DiffChange", { fg = p.warning })
hl("DiffDelete", { fg = p.error })
hl("DiffText", { fg = p.accent })
hl("GitSignsAdd", { fg = p.func })
hl("GitSignsChange", { fg = p.warning })
hl("GitSignsDelete", { fg = p.error })

hl("@comment", { link = "Comment" })
hl("@string", { link = "String" })
hl("@number", { link = "Number" })
hl("@boolean", { link = "Boolean" })
hl("@constant", { link = "Constant" })
hl("@function", { link = "Function" })
hl("@keyword", { link = "Keyword" })
hl("@type", { link = "Type" })
hl("@variable", { fg = p.variable })
hl("@variable.parameter", { fg = p.parameter, italic = true })
hl("@property", { fg = p.variable })
hl("@punctuation", { fg = p.warm })
hl("@tag", { fg = p.keyword })
hl("@constructor", { fg = p.support })
