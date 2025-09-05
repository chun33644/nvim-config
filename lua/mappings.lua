require "nvchad.mappings"


local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

--map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map({ "n", "i", "v" }, "<leader>fg", function()
  if vim.bo.filetype == "TelescopePrompt" then
    vim.cmd "q!"
  else
    vim.cmd "Telescope live_grep"
  end
end, { desc = "search search across project" })


pcall(vim.keymap.del, "n", "<C-n>")
pcall(vim.keymap.del, "v", "<C-n>")
pcall(vim.keymap.del, "i", "<C-n>")

--=======================================
--診斷導航快速鍵
--=======================================
local function nmap(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
end

nmap("<leader>d", function() vim.diagnostic.open_float(nil, { focus = false, scope = "line" }) end, "Show diagnostic")
nmap("<leader>dn", vim.diagnostic.goto_next, "Next diagnostic")
nmap("<leader>dp", vim.diagnostic.goto_prev, "Prev diagnostic")

local opts = { noremap = true, silent = true }

-- 漂亮的浮窗（游標處有就顯示，沒有就看整行，還是沒有就提示）
map("n", "<leader>d", function()
  local bufnr = 0
  local lnum  = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- 先找游標所在位置的診斷（有些 server 會回報多個）
  local diags_cursor = vim.diagnostic.get(bufnr, { lnum = lnum })
  -- 若該行完全沒有診斷，直接提示
  if #diags_cursor == 0 then
    vim.notify("No diagnostics on this line.", vim.log.levels.INFO, { title = "LSP" })
    return
  end

  vim.diagnostic.open_float(bufnr, {
    focus = false,
    scope = "line",          -- 一次把這一行的所有診斷列出來
    border = "rounded",
    source = "if_many",
    severity_sort = true,
    prefix = function(diag, i, total)
      -- 在每條訊息前面加序號與嚴重等級
      local sev = ({
        [vim.diagnostic.severity.ERROR] = "Error",
        [vim.diagnostic.severity.WARN]  = "Warn",
        [vim.diagnostic.severity.INFO]  = "Info",
        [vim.diagnostic.severity.HINT]  = "Hint",
      })[diag.severity] or "Diag"
      return string.format("%d/%d %s: ", i, total, sev)
    end,
  })
end, vim.tbl_extend("force", opts, { desc = "Show diagnostics on this line" }))

-- 跳到下一個 / 上一個診斷（避免自動彈窗干擾）
map("n", "<leader>dn", function()
  vim.diagnostic.goto_next({ float = false })
end, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))

map("n", "<leader>dp", function()
  vim.diagnostic.goto_prev({ float = false })
end, vim.tbl_extend("force", opts, { desc = "Prev diagnostic" }))

--=============================
--cscope設定
--=============================
-- 自動載入 cscope DB（啟動時）
local function add_cscope_db()
  -- 順序：cscope.out -> $CSCOPE_DB -> .cscope.out
  if vim.fn.filereadable("cscope.out") == 1 then
    vim.cmd("cs add cscope.out")
  elseif (vim.env.CSCOPE_DB or "") ~= "" then
    vim.cmd("cs add " .. vim.env.CSCOPE_DB)
  elseif vim.fn.filereadable(".cscope.out") == 1 then
    vim.cmd("cs add .cscope.out")
  end

  -- 這些是 Vim 的選項；若 Neovim/外掛不支援就忽略
  pcall(vim.cmd, "set cscopeverbose")
  pcall(vim.cmd, "set cscopetag")
  pcall(vim.cmd, "set csto=0")
end

-- 啟動時嘗試加 DB（也可改為 DirChanged/BufEnter 等）
vim.api.nvim_create_autocmd("VimEnter", {
  callback = add_cscope_db,
})

-- 小工具：建立快捷鍵（把 <cword>/<cfile> 拼進 :cs）
local csmap = function(lhs, finder, get_target)
  vim.keymap.set("n", lhs, function()
    local target = get_target()
    if target and #target > 0 then
      vim.cmd("Cscope find " .. finder .. " " .. target)
    else
      vim.notify("cscope: empty target", vim.log.levels.WARN)
    end
  end, { silent = true, noremap = true, desc = "cscope find " .. finder })
end

-- 等價於你的 nmap（<cword>/<cfile> 以 Lua 方式取得）
csmap("zs", "s", function() return vim.fn.expand("<cword>") end)          -- s: symbol
csmap("zg", "g", function() return vim.fn.expand("<cword>") end)          -- g: definition
csmap("zc", "c", function() return vim.fn.expand("<cword>") end)          -- c: callers
csmap("zt", "t", function() return vim.fn.expand("<cword>") end)          -- t: text
csmap("ze", "e", function() return vim.fn.expand("<cword>") end)          -- e: egrep
csmap("zf", "f", function() return vim.fn.expand("<cfile>") end)          -- f: filename
csmap("zi", "i", function() return "^" .. vim.fn.expand("<cfile>") end)   -- i: includes
csmap("zd", "d", function() return vim.fn.expand("<cword>") end)          -- d: callee



