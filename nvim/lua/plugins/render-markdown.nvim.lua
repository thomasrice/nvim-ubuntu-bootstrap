local wiki = require("util.wikilinks")

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      heading = {
        icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
        width = "block",
        left_pad = 1,
        right_pad = 1,
      },
      quote = {
        enabled = false,
      },
      code = {
        position = 'right',
        border = 'thick',
        left_pad = 4,
        width = 'block',
        min_width = 80,
        right_pad = 4
      },
      checkbox = {
        enabled = true,
        unchecked = {
          icon = '  [ ]'
        },
        checked = {
          icon = '  [x]'
        },
      },
      link = {
        wiki = {
          icon = "",
          body = function(ctx)
            local target = wiki.resolve_wikilink_target(ctx.destination)
            local exists = target and wiki.wikilink_exists(target)
            local text = ctx.alias or ctx.destination
            local hl = exists and "MarkdownWikiLinkExisting" or "MarkdownWikiLinkMissing"
            return { text, hl }
          end,
        },
        custom = {
          web = {
            icon = ""
          }
        }
      },
    },
  },
}
