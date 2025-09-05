return {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    opts = {
      sort = {
        sorter = "case_sensitive",
      },
      view = {
        side = "right",   -- 改成右邊顯示
        width = 30,       -- ← 選一個你要的值（30 or 40）
      },
      renderer = {
        group_empty = true,
      },
      filters = {
        dotfiles = true,
      },
    },
    keys = {
      { "<C-n>", false }, -- 移除原本的 Ctrl+n
      { "<F9>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
      { "<F10>", "<cmd>NvimTreeFocus<CR>", desc = "Focus NvimTree" },
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)   -- ★ 明確呼叫，確保生效
    end,
}
