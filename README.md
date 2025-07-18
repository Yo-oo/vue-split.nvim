# vue-split.nvim

A Neovim plugin that intelligently splits Vue Single File Components (.vue files) into separate windows for template, script, and style blocks.

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
