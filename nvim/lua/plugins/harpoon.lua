return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>fa", function() require("harpoon"):list():add() end,                                    desc = "Harpoon add file" },
    { "<C-f>",      function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon menu" },
    { "<C-1>",      function() require("harpoon"):list():select(1) end,                                desc = "Harpoon to 1" },
    { "<C-2>",      function() require("harpoon"):list():select(2) end,                                desc = "Harpoon to 2" },
    { "<C-3>",      function() require("harpoon"):list():select(3) end,                                desc = "Harpoon to 3" },
    { "<C-4>",      function() require("harpoon"):list():select(4) end,                                desc = "Harpoon to 4" },
    { "<C-S-J>",    function() require("harpoon"):list():prev() end,                                   desc = "Harpoon prev" },
    { "<C-S-K>",    function() require("harpoon"):list():next() end,                                   desc = "Harpoon next" },
  },
  config = function()
    local harpoon = require("harpoon")
    harpoon:setup() -- REQUIRED for v2
  end,
}
