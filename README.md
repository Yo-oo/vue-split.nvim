# vue-split.nvim

A Neovim plugin that splits Vue Single File Components (.vue files) into separate windows for template, script, and style blocks.

## Demo

https://github.com/user-attachments/assets/3e727ed2-3827-43d9-85e6-ff0dc2eca5d7

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Yo-oo/vue-split.nvim",
  ft = { "vue" },
  lazy = true,
  opts = {},
},
```

## Configuration

All options are optional.

```lua
require("vue-split").setup({
  -- Key mapping to toggle the split view. Set to false to disable.
  keymap = "<leader>vs",

  -- Height of the bottom pane in the three-pane layout.
  bottom_height = 15,

  -- Which section to place in each position.
  -- Valid values: "template", "script", "style"
  layout = {
    top_left  = "template",
    top_right = "script",
    bottom    = "style",
  },
})
```
