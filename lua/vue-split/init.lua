local M = {}

-- marker for tab
local PLUGIN_TAB_VAR = "vue_split_plugin_tab"
local ORIGIN_TAB_VAR = "vue_split_origin_tab"

local DEFAULT_LAYOUT = {
	top_left = "template",
	top_right = "script",
	bottom = "style",
}

local function find_vue_sections()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local sections = {}

	for i, line in ipairs(lines) do
		if not sections.template and line:match("^%s*<template") then
			sections.template = i
		elseif not sections.script and line:match("^%s*<script") then
			sections.script = i
		elseif not sections.style and line:match("^%s*<style") then
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

local function create_split_view(layout, bottom_height)
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

	local origin_tab = vim.api.nvim_get_current_tabpage()
	local file_path = vim.api.nvim_buf_get_name(0)
	vim.cmd("tabnew " .. vim.fn.fnameescape(file_path))

	-- mark this tab as created by plugin and store origin tab
	local new_tab = vim.api.nvim_get_current_tabpage()
	vim.api.nvim_tabpage_set_var(new_tab, PLUGIN_TAB_VAR, true)
	vim.api.nvim_tabpage_set_var(new_tab, ORIGIN_TAB_VAR, origin_tab)

	if section_count == 2 then
		M.setup_two_pane_view(sections, layout)
	else
		M.setup_three_pane_view(sections, layout, bottom_height)
	end

	return true
end

function M.setup_two_pane_view(sections, layout)
	-- derive left/right order from layout priority: top_left > top_right > bottom
	local panes = {}
	for _, pos in ipairs({ "top_left", "top_right", "bottom" }) do
		local section = layout[pos]
		if sections[section] and #panes < 2 then
			table.insert(panes, sections[section])
		end
	end

	vim.cmd("vsplit")

	vim.api.nvim_win_set_cursor(0, { panes[1], 0 })
	vim.cmd("normal! zt")

	vim.cmd("wincmd l")
	vim.api.nvim_win_set_cursor(0, { panes[2], 0 })
	vim.cmd("normal! zt")

	vim.cmd("wincmd h")
end

function M.setup_three_pane_view(sections, layout, bottom_height)
	local win_top_left = vim.api.nvim_get_current_win()
	local win_bottom, win_top_right

	local bottom_section = layout.bottom
	local top_right_section = layout.top_right
	local top_left_section = layout.top_left

	if sections[bottom_section] then
		vim.cmd("split")
		win_bottom = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_height(win_bottom, bottom_height)
		vim.api.nvim_set_current_win(win_top_left)
	end

	if sections[top_right_section] then
		vim.cmd("vsplit")
		win_top_right = vim.api.nvim_get_current_win()
	end

	if sections[top_left_section] then
		vim.api.nvim_set_current_win(win_top_left)
		vim.api.nvim_win_set_cursor(win_top_left, { sections[top_left_section], 0 })
		vim.cmd("normal! zt")
	end

	if sections[bottom_section] and win_bottom then
		vim.api.nvim_set_current_win(win_bottom)
		vim.api.nvim_win_set_cursor(win_bottom, { sections[bottom_section], 0 })
		vim.cmd("normal! zt")
	end

	if sections[top_right_section] and win_top_right then
		vim.api.nvim_set_current_win(win_top_right)
		vim.api.nvim_win_set_cursor(win_top_right, { sections[top_right_section], 0 })
		vim.cmd("normal! zt")
	end

	vim.api.nvim_set_current_win(win_top_left)
end

local function close_split_view()
	local current_tab = vim.api.nvim_get_current_tabpage()
	local ok, origin_tab = pcall(vim.api.nvim_tabpage_get_var, current_tab, ORIGIN_TAB_VAR)
	vim.cmd("tabclose")
	if ok and origin_tab and vim.api.nvim_tabpage_is_valid(origin_tab) then
		vim.api.nvim_set_current_tabpage(origin_tab)
	end
end

local function toggle_vue_split(layout, bottom_height)
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

	create_split_view(layout, bottom_height)
end

function M.setup(opts)
	opts = opts or {}
	local layout = vim.tbl_deep_extend("force", DEFAULT_LAYOUT, opts.layout or {})
	local bottom_height = opts.bottom_height or 15

	local function toggle()
		toggle_vue_split(layout, bottom_height)
	end

	if opts.keymap ~= false then
		local keymap = opts.keymap or "<leader>vs"
		vim.keymap.set("n", keymap, toggle, {
			noremap = true,
			silent = true,
			desc = "vue split",
		})
	end

	vim.api.nvim_create_user_command("VueSplit", toggle, {
		desc = "vue split",
	})
end

return M
