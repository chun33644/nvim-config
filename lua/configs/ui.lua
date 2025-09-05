
local M = {}

M.nvim_tree = {
  filters = {
    dotfiles = false,
    git_ignored = false,
    custom = { "\\.git", "\\.cache" },
  },
}

return M




