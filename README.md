# vue-split.nvim

A Neovim plugin that intelligently splits Vue Single File Components (.vue files) into separate windows for template, script, and style blocks.

## Demo

https://github.com/user-attachments/assets/3e727ed2-3827-43d9-85e6-ff0dc2eca5d7

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
  {
    "vue-split",
    url = "Yo-oo/vue-split.nvim",
    ft = { "vue" },
    lazy = true,
    -- optional
    opts = {
      keymap = "your_keymap",
    }
  },
```
