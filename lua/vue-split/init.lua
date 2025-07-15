local M = {}

-- marker for tab
local PLUGIN_TAB_VAR = "vue_split_plugin_tab"

local function find_vue_sections()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local sections = {}

  for i, line in ipairs(lines) do
    if line:match "^%s*<template" then
      sections.template = i
    elseif line:match "^%s*<script" then
      sections.script = i
    elseif line:match "^%s*<style" then
      sections.style = i
    end
  end

  return sections
end

local function count_sections(sections)
  local count = 0
  for _, _ in pairs(sections) do
    count = count + 1
  end
  return count
end

local function is_plugin_tab()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local ok, is_plugin = pcall(vim.api.nvim_tabpage_get_var, current_tab, PLUGIN_TAB_VAR)
  return ok and is_plugin
end

local function create_split_view()
  local sections = find_vue_sections()
  local section_count = count_sections(sections)

  if section_count == 0 then
    vim.notify("vue block not found", vim.log.levels.WARN)
    return false
  end

  if section_count == 1 then
    vim.notify("only one vue block, can't split", vim.log.levels.WARN)
    return false
  end

  local file_path = vim.api.nvim_buf_get_name(0)
  vim.cmd("tabnew " .. vim.fn.fnameescape(file_path))

  -- mark this tab is created by plugin
  local new_tab = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_tabpage_set_var(new_tab, PLUGIN_TAB_VAR, true)

  if section_count == 2 then
    M.setup_two_pane_view(sections)
  else
    M.setup_three_pane_view(sections)
  end

  return true
end

function M.setup_two_pane_view(sections)
  vim.cmd "vsplit"

  local section_list = {}
  for name, line in pairs(sections) do
    table.insert(section_list, { name = name, line = line })
  end

  table.sort(section_list, function(a, b)
    return a.line < b.line
  end)

  vim.api.nvim_win_set_cursor(0, { section_list[1].line, 0 })
  vim.cmd "normal! zt"

  vim.cmd "wincmd l"
  vim.api.nvim_win_set_cursor(0, { section_list[2].line, 0 })
  vim.cmd "normal! zt"

  vim.cmd "wincmd h"
end

function M.setup_three_pane_view(sections)
  if sections.script then
    vim.cmd "split"
    vim.api.nvim_win_set_height(0, 15)
  end

  if sections.style then
    vim.cmd "wincmd t"
    vim.cmd "vsplit"
  end

  if sections.template then
    vim.cmd "wincmd t"
    vim.api.nvim_win_set_cursor(0, { sections.template, 0 })
    vim.cmd "normal! zt"
  end

  if sections.script then
    vim.cmd "wincmd l"
    vim.api.nvim_win_set_cursor(0, { sections.script, 0 })
    vim.cmd "normal! zt"
  end

  if sections.style then
    vim.cmd "wincmd j"
    vim.api.nvim_win_set_cursor(0, { sections.style, 0 })
    vim.cmd "normal! zt"
  end

  vim.cmd "wincmd t"
end

local function close_split_view()
  vim.cmd "tabclose"
end

local function toggle_vue_split()
  -- if current tab is created by plugin, close it
  if is_plugin_tab() then
    close_split_view()
    return
  end

  -- check if current buffer is a vue file
  if vim.bo.filetype ~= "vue" then
    vim.notify("this is not a vue file", vim.log.levels.WARN)
    return
  end

  -- check if current buffer is a file and not a new file
  local file_path = vim.api.nvim_buf_get_name(0)
  if file_path == "" then
    vim.notify("this is not a file", vim.log.levels.WARN)
    return
  end

  -- create split view
  create_split_view()
end

function M.setup(opts)
  opts = opts or {}
  local keymap = opts.keymap or "<leader>vs"

  vim.keymap.set("n", keymap, toggle_vue_split, {
    noremap = true,
    silent = true,
    desc = "vue split",
  })

  vim.api.nvim_create_user_command("VueSplit", toggle_vue_split, {
    desc = "vue split",
  })
end

return M
