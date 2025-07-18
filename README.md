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
  -- optional
  opts = {
    keymap = "<leader>vs",
  }
},
```
