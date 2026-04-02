local M = {}

-- marker for tab
local PLUGIN_TAB_VAR = "vue_split_plugin_tab"
local ORIGIN_TAB_VAR = "vue_split_origin_tab"

local DEFAULT_LAYOUT = {
	top_left = "template",
	top_right = "script",
	bottom = "style",
}

-- Returns:
--   sections: { template=line, script=line, style=line } (first occurrence of each)
--   ranges:   list of { type, start, finish } for every block found
--             finish = line just before the next block starts (or EOF)
local function find_vue_sections()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local sections = {}
	local all_blocks = {}

	for i, line in ipairs(lines) do
		local tag_type
		if line:match("^%s*<template") then
			tag_type = "template"
		elseif line:match("^%s*<script") then
			tag_type = "script"
		elseif line:match("^%s*<style") then
			tag_type = "style"
		end

		if tag_type then
			if not sections[tag_type] then
				sections[tag_type] = i
			end
			table.insert(all_blocks, { type = tag_type, start = i })
		end
	end

	-- Each block's range extends to just before the next block starts (or EOF).
	-- This guarantees the closing tag line is always included in the fold.
	local ranges = {}
	for i, block in ipairs(all_blocks) do
		local finish = (all_blocks[i + 1] and all_blocks[i + 1].start - 1) or #lines
		table.insert(ranges, { type = block.type, start = block.start, finish = finish })
	end

	return sections, ranges
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

-- Fold all sections whose type != section_type in the given window, then scroll
-- the cursor line to the top. Combining both in one nvim_win_call ensures zt
-- sees the final folded layout rather than running before folds are applied.
local function apply_section_folds(win_id, section_type, ranges)
	vim.schedule(function()
		vim.api.nvim_win_call(win_id, function()
			if ranges then
				vim.wo.foldmethod = "manual"
				for _, range in ipairs(ranges) do
					if range.type ~= section_type then
						vim.cmd(range.start .. "," .. range.finish .. "fold")
					end
				end
			end
			vim.cmd("normal! zt")
		end)
	end)
end

local function create_split_view(layout, bottom_height)
	local sections, ranges = find_vue_sections()
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
		M.setup_two_pane_view(sections, layout, ranges)
	else
		M.setup_three_pane_view(sections, layout, bottom_height, ranges)
	end

	return true
end

function M.setup_two_pane_view(sections, layout, ranges)
	-- derive left/right order from layout priority: top_left > top_right > bottom
	local panes = {}
	for _, pos in ipairs({ "top_left", "top_right", "bottom" }) do
		local section = layout[pos]
		if sections[section] and #panes < 2 then
			table.insert(panes, { line = sections[section], type = section })
		end
	end

	vim.cmd("vsplit")

	local win_pane1 = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_cursor(0, { panes[1].line, 0 })

	vim.cmd("wincmd l")
	local win_pane2 = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_cursor(0, { panes[2].line, 0 })

	vim.cmd("wincmd h")

	apply_section_folds(win_pane1, panes[1].type, ranges)
	apply_section_folds(win_pane2, panes[2].type, ranges)
end

function M.setup_three_pane_view(sections, layout, bottom_height, ranges)
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
	end

	if sections[bottom_section] and win_bottom then
		vim.api.nvim_set_current_win(win_bottom)
		vim.api.nvim_win_set_cursor(win_bottom, { sections[bottom_section], 0 })
	end

	if sections[top_right_section] and win_top_right then
		vim.api.nvim_set_current_win(win_top_right)
		vim.api.nvim_win_set_cursor(win_top_right, { sections[top_right_section], 0 })
	end

	vim.api.nvim_set_current_win(win_top_left)

	if sections[top_left_section] then
		apply_section_folds(win_top_left, top_left_section, ranges)
	end
	if sections[bottom_section] and win_bottom then
		apply_section_folds(win_bottom, bottom_section, ranges)
	end
	if sections[top_right_section] and win_top_right then
		apply_section_folds(win_top_right, top_right_section, ranges)
	end
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
