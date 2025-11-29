-- configs/lsp.lua
-- 這份檔案在被 require 時會直接執行初始化，不會回傳 table

-- 依賴：mason.nvim、mason-lspconfig.nvim、nvim-lspconfig、nvim-treesitter
-- 如果你已有自己的 nvlsp（on_attach/on_init/capabilities），把下面簡易預設換成你的
local mr = require("mason-registry")

-- 簡易預設（建議換成你自己的）
local nvlsp = rawget(_G, "nvlsp") or {
  on_attach = function(_) end,
  on_init = function(_) end,
  capabilities = vim.lsp.protocol.make_client_capabilities(),
}

-- 想要安裝的語言項目：
-- "*" 代表所有語言的通用項目；key 使用 filetype（c、cpp）
-- 這裡我們只針對 C / C++
ensure_installed = ensure_installed or {
  ["*"] = {},                 -- 需要的話你可以放共用 mason 包，例如 "bash-language-server"
  c      = { "ts/c", "clangd" },  -- Treesitter 的 c parser，LSP 用 clangd
  cpp    = { "ts/cpp", "clangd" },-- Treesitter 的 cpp parser，LSP 同樣用 clangd
}

-- 啟動時就先安裝
eagerly_installed_langs = eagerly_installed_langs or { "c", "cpp" }

-- ===================================================================
-- 自動安裝器的主體（以閉包包起來，最後回傳一個函式 ensure_lang_installed）
-- ===================================================================
local ensure_lang_installed = (function()
  -- 先刷新 Mason registry，避免舊索引
  local mason_registry_refreshing = true
  mr.refresh(function() mason_registry_refreshing = false end)

  -- 流程控制旗標／佇列
  local installing = false
  local installed_langs = {}   -- set：installed_langs[lang] = true 才算處理過
  local installing_lang = nil
  local queued_langs = {}

  -- 訊息顯示（包一層 schedule，避免跨執行緒）
  local show = vim.schedule_wrap(function(fmt, ...)
    vim.notify(string.format(fmt, ...), vim.log.levels.INFO, { title = "LSP" })
  end)
  local show_error = vim.schedule_wrap(function(fmt, ...)
    vim.notify(string.format(fmt, ...), vim.log.levels.ERROR, { title = "LSP" })
  end)

  -- ------------------------------------------------------------
  -- 檢查 Treesitter parser 是否已安裝（以檔案路徑判斷）
  -- ------------------------------------------------------------
  local function is_treesitter_installed(lang)
    local function clean_path(input)
      local p = vim.fn.fnamemodify(input, ":p")
      if vim.fn.has("win32") == 1 then p = p:gsub("/", "\\") end
      return p
    end
    local matched = vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", true) or {}
    local install_dir = require("nvim-treesitter.configs").get_parser_install_dir()
    if not install_dir then return false end
    install_dir = clean_path(install_dir)
    for _, path in ipairs(matched) do
      if vim.startswith(clean_path(path), install_dir) then return true end
    end
    return false
  end

  ---@alias PackageType "lspconfig"|"mason"|"mason-lspconfig"|"treesitter"

  -- ------------------------------------------------------------
  -- 將使用者填的名稱解析成來源類型與實際名稱
  -- 支援：裸名稱（clangd）、前綴格式（ts/c、lspconfig/clangd、mason/clangd）
  -- 並使用 mason-lspconfig 的映射表互轉
  -- ------------------------------------------------------------
  local function parse_name(name)
    local parts = vim.split(name, "/")

    local map = require("mason-lspconfig").get_mappings()
    local parsers = require("nvim-treesitter.parsers").get_parser_configs()

    if #parts == 1 then
      -- 單字：優先透過 mason-lspconfig 映射，然後 treesitter，最後當成「LSP server 名稱」
      if map.lspconfig_to_package[name] then
        return "mason-lspconfig", map.lspconfig_to_package[name]
      end
      if map.package_to_lspconfig[name] then
        return "mason-lspconfig", name
      end
      if parsers[name] then
        return "treesitter", name
      end
      -- fallback：視為 LSP server 名稱（走新 API vim.lsp.config）
      return "lspconfig", name
    end

    -- 明確前綴
    local type_matches = { lspconfig = "lspconfig", mason = "mason", ts = "treesitter" }
    if #parts == 2 then
      local t = type_matches[parts[1]]
      if not t then error(("Invalid package type in '%s'"):format(name)) end

      if t == "treesitter" and not parsers[parts[2]] then
        error(("Invalid treesitter parser '%s'"):format(parts[2]))
      end

      -- 前綴若可透過映射轉成 mason-lspconfig，就轉
      if t == "lspconfig" and map.lspconfig_to_package[parts[2]] then
        return "mason-lspconfig", map.lspconfig_to_package[parts[2]]
      end
      if t == "mason" and map.package_to_lspconfig[parts[2]] then
        return "mason-lspconfig", parts[2]
      end
      return t, parts[2]
    end

    error(("Invalid package format '%s'"):format(name))
  end

  -- ------------------------------------------------------------
  -- 實際執行「針對某語言」的安裝：收集要裝的項目 → 依序執行
  -- ------------------------------------------------------------
  local function install_lang(lang, cb)
    ---@type table[]  -- 佇列中每個元素描述一個要裝的項目
    local queued_pkgs = {}

    -- 如果有對應的 treesitter parser，將它補到清單最前
    ensure_installed[lang] = ensure_installed[lang] or {}
    local ts_available = require("nvim-treesitter.parsers").get_parser_configs()[lang:lower()]
    if ts_available then
      local to_add = "ts/" .. lang:lower()
      local exists = false
      for _, n in ipairs(ensure_installed[lang]) do
        if n == to_add then exists = true; break end
      end
      if not exists then table.insert(ensure_installed[lang], 1, to_add) end
    end

    -- 把需要的項目解析成具體安裝描述，放入 queued_pkgs
    for _, unparsed in ipairs(ensure_installed[lang]) do
      local function describe()
        local t, name = parse_name(unparsed)

        if t == "treesitter" then
          if is_treesitter_installed(name) then return end
          return { type = "treesitter", name = name }
        end

        if t == "lspconfig" then
          -- 新 API：vim.lsp.config + vim.lsp.enable
          local function setup()
            -- 這裡的 name 是 LSP server 名稱（例如 "clangd"）
            vim.lsp.config(name, {
              on_attach = nvlsp.on_attach,
              on_init = nvlsp.on_init,
              capabilities = nvlsp.capabilities,
            })
            -- 啟用這個 config，讓它對應的 filetypes 自動 attach
            vim.lsp.enable({ name })
          end

          -- 若前面有 mason/treesitter 要裝，則先延後 setup
          if #queued_pkgs > 0 then
            return { type = "lspconfig", name = name, setup = setup }
          end
          -- 沒東西在佇列就直接 setup
          setup()
          return
        end

        -- mason 套件（包含透過 mason-lspconfig 映射過來的）
        local ok, pkg = pcall(mr.get_package, name)
        if ok then
          if pkg:is_installed() then return end
          return { type = "mason", pkg = pkg }
        end

        -- 錯誤情況（例如網路問題或打錯）
        if t == "mason-lspconfig" then
          show_error("[LSP] Network error: failed to find '%s' in Mason registry", unparsed)
          return
        end
        show_error("[LSP] Cannot find '%s' in Mason registry (typo or network?)", unparsed)
      end

      local d = describe()
      if d then table.insert(queued_pkgs, d) end
    end

    -- 沒東西要裝就回呼 callback
    if #queued_pkgs == 0 then if cb then cb() end; return end
    if lang ~= "*" then show("[LSP] [0/%d] Installing for %s...", #queued_pkgs, lang) end

    -- 逐項安裝：Treesitter → Mason → LSP config
    local function install_pkg(i)
      if i > #queued_pkgs then
        -- 全部跑完就結束（vim.lsp.enable 已經在上面呼叫過了）
        if cb then cb() end
        return
      end

      local desc = queued_pkgs[i]

      -- 1) Treesitter：呼叫 :TSInstall，然後輪詢是否安裝成功（最多等 8 秒）
      if desc.type == "treesitter" then
        show("[LSP] [%d/%d] TSInstall %s...", i, #queued_pkgs, lang == "*" and desc.name or lang)
        local start = os.clock()
        local timeout_ms = 8000
        vim.cmd("TSInstall " .. desc.name)
        local function poll()
          if is_treesitter_installed(desc.name) then
            show("[LSP] [%d/%d] Treesitter OK for %s", i, #queued_pkgs, lang == "*" and desc.name or lang)
            return install_pkg(i + 1)
          end
          if os.clock() - start > timeout_ms / 1000 then
            show_error("[LSP] [%d/%d] Treesitter timeout for %s", i, #queued_pkgs, lang == "*" and desc.name or lang)
            return install_pkg(i + 1) -- 超時就跳過，繼續後面項目
          end
          vim.defer_fn(poll, 100)
        end
        return vim.defer_fn(poll, 100)
      end

      -- 2) LSP config：執行延後的 setup（裡面會呼叫 vim.lsp.config + enable）
      if desc.type == "lspconfig" then
        show("[LSP] [%d/%d] LSP config %s", i, #queued_pkgs, desc.name)
        if desc.setup then desc.setup() end
        return vim.schedule(function() install_pkg(i + 1) end)
      end

      -- 3) Mason 套件：呼叫 mason 安裝，成功才標記 installed_langs[lang] = true
      local pkg = desc.pkg
      show("[LSP] [%d/%d] Mason install %s%s", i, #queued_pkgs, pkg.name, lang=="*" and "" or (" for "..lang))
      pkg:install({}, function(success)
        if success then
          installed_langs[lang] = true    -- 成功才標記（修正原本失敗也標記的問題）
          show("[LSP] [%d/%d] Installed %s", i, #queued_pkgs, pkg.name)
        else
          show_error("[LSP] [%d/%d] Failed %s", i, #queued_pkgs, pkg.name)
          -- 失敗不標記，保留下次重試機會
        end
        vim.schedule(function() install_pkg(i + 1) end)
      end)
    end

    install_pkg(1)
  end

  -- ============================================================
  -- 對外暴露的函式：排隊、節流、等 mason registry 刷新
  -- ============================================================
  return function(lang)
    -- 將 filetype 對齊到 ensure_installed 的 key（忽略大小寫）
    for key in pairs(ensure_installed) do
      if lang:lower() == key:lower() then lang = key; break end
    end

    -- 若這個語言沒有設定、且也沒有 treesitter parser，就不處理
    if not ensure_installed[lang]
       and not require("nvim-treesitter.parsers").get_parser_configs()[lang:lower()] then
      return
    end

    -- 避免重入／重複排隊
    if installed_langs[lang] then return end
    if installing_lang == lang then return end
    for _, l in ipairs(queued_langs) do if l == lang then return end end

    -- 放進安裝佇列，如未啟動安裝機制，就啟動它
    table.insert(queued_langs, lang)
    if not installing then
      local function go()
        if #queued_langs == 0 then installing = false; return end
        if mason_registry_refreshing then return vim.defer_fn(go, 100) end
        installing_lang = table.remove(queued_langs, 1)
        vim.schedule(function()
          install_lang(installing_lang, function()
            installed_langs[installing_lang] = true  -- 完成該語言流程才標記
            installing_lang = nil
            vim.schedule(go)
          end)
        end)
      end
      installing = true
      vim.schedule(go)
    end
  end
end)()

-- ============================================================
-- 自動觸發：當讀取檔案或設定 filetype 時，嘗試確保該語言就緒
-- ============================================================
vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
  pattern = "*",
  callback = function()
    ensure_lang_installed(vim.bo.filetype)
  end,
})

-- 啟動時先處理通用項與「想先裝」的語言（C / C++）
ensure_lang_installed("*")
for _, lang in ipairs(eagerly_installed_langs) do
  ensure_lang_installed(lang)
end
