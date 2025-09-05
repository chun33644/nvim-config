
return {

  {
    "dhananjaylatkar/cscope_maps.nvim",
    lazy = false, -- 啟動就載入
    dependencies = {
      -- Telescope 本體 + 依賴
      { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
      -- 下列皆為可選（你沒用到可刪）
      "ibhagwan/fzf-lua",
      "echasnovski/mini.pick",
      "folke/snacks.nvim",
    },
    opts = {
      -- maps 相關（照官方鍵名）
      disable_maps = false,
      skip_input_prompt = true,     -- 自動吃 <cword>/<cfile>
      prefix = "<leader>c",

      -- cscope 相關
      cscope = {
        db_file = "./cscope.out",
        exec = "cscope",
        picker = "telescope",       -- ★ 改成 Telescope 就在這裡！
        picker_opts = {             -- 只有 quickfix/location 會用到大小/位置
          window_size = 5,
          window_pos = "bottom",
        },
        skip_picker_for_single_result = false,
        db_build_cmd = { script = "default", args = { "-bqkv" } },
        statusline_indicator = nil,
        project_rooter = {
          enable = false,           -- 想讓它自動往上找 cscope.out 再改 true
          change_cwd = false,
        },
        tag = {
          keymap = true,
          order = { "cs", "tag_picker", "tag" },
          tag_cmd = "tjump",
        },
      },

      -- stack view (可留預設)
      stack_view = { tree_hl = true },
    },
    config = function(_, opts)
      -- ★ 依官方要求：一定要呼叫 setup
      require("cscope_maps").setup(opts)
    end,
  }

}

