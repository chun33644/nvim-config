
require "nvchad.options"
local opt = vim.opt

opt.number = true

-- HighLight both the current line and its line number
opt.cursorlineopt = "both"
opt.cursorline = true

-- 更顯眼的行高亮
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a3f" })
-- 行號用亮黃色
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#ffff66", bold = true })


-- 顯示行尾空白
vim.api.nvim_create_autocmd({"BufWinEnter","InsertLeave"}, {
  pattern = "*",
  command = "match ExtraWhitespace /\\s\\+$/"
})
vim.api.nvim_create_autocmd("InsertEnter", {
  pattern = "*",
  command = "match none"
})
--存檔時自動刪掉
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  command = [[:%s/\s\+$//e]]
})



vim.opt.hlsearch = false  -- 不要高亮全部
vim.opt.incsearch = true  -- 只在輸入過程顯示當前匹配


-- 自動縮排設定
vim.opt.autoindent  = true   -- 新行延續前一行的縮排
vim.opt.smartindent = true   -- 針對程式語言增加額外縮排（例如 if {...} 後自動縮進）
vim.opt.smarttab    = true   -- 在行首用 <Tab> 會依縮排寬度計算
vim.opt.expandtab   = true   -- Tab 轉換成空白（建議開，避免混亂）
vim.opt.shiftwidth  = 4      -- 每次縮排的空格數
vim.opt.tabstop     = 4      -- 一個 <Tab> 等於幾個空格
vim.opt.softtabstop = 4      -- 編輯時 <Tab>/<BS> 視為幾個空格
