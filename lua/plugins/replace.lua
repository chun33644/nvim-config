return {

    -- 多光標編輯
      {
      "mg979/vim-visual-multi",
      branch = "master",
      event = "VeryLazy", -- 也可用 keys = {...} 指定熱鍵再載入
      init = function()
        -- 關掉預設大量映射，自己定最常用的即可
        vim.g.VM_default_mappings = 1

        -- 自訂快捷鍵（常用精簡款）
        vim.g.VM_maps = {
          ["Find Under"]         = "<C-n>",  -- 選取目前游標下的字，並跳到下一個相同字
          ["Find Subword Under"] = "<C-n>",  -- 子字串也算
          ["Select All"]         = "<C-a>",  -- 一次選取檔案中所有匹配
          ["Skip Region"]        = "<C-x>",  -- 跳過這個匹配，不選它
          ["Remove Region"]      = "<C-p>",  -- 取消上一個加入的匹配
          -- ["Toggle Mappings"]    = "gm",     -- 切換 VM 模式映射（偶爾有衝突時好用）
          -- 也可啟用滑鼠：按住 Alt 再左鍵拖曳，或設定：
          -- ["Add Cursor At Pos"]  = "<C-LeftMouse>",
        }
      end,
      },


}

