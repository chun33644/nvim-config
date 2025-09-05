

return {
    { -- Override 'nvim-tree' plugin
        "nvim-tree/nvim-tree.lua",
        opts = require("configs.ui").nvim_tree,
    },

    { -- Set consistent terminal background color with theme
        "typicode/bg.nvim",
        lazy = false,
    },


}
