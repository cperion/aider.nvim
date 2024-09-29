return {
  "cperion/aider.nvim",
  opts = {
    auto_manage_context = true,
    default_layout = "vsplit",
    keys = {
      open = "<leader>ao",
      toggle = "<leader>at",
      background = "<leader>ab",
    },
  },
  keys = {
    {
      "<leader>at",
      function()
        require("aider.core").toggle("vsplit")
      end,
      desc = "Toggle Aider",
    },
    {
      "<leader>ao",
      function()
        require("aider.core").open("vsplit")
      end,
      desc = "Open Aider",
    },
    {
      "<leader>ab",
      function()
        require("aider.core").background()
      end,
      desc = "Run Aider in Background",
    },
  },
  config = function(_)
    local aider_ok, aider = pcall(require, "aider")
    if not aider_ok then
      vim.notify("Aider plugin not found", vim.log.levels.ERROR)
      return
    end
    aider.setup()
  end,
}
