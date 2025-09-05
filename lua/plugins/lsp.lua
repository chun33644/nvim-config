return {
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
  },

  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
  },


  -- add mason-lspconfig
  {
    "mason-org/mason-lspconfig.nvim",
    event = "VimEnter",
    dependencies = {
      "neovim/nvim-lspconfig",
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason.nvim",
    },
    opts = function()
      require "configs.lsp"
      return {
      -- select the one you want to install
      -- "lua_ls"
      }
    end,
  },



}
