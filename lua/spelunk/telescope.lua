local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local M = {}

local function strip_prefix()
	local cwd = vim.fn.getcwd() .. '/'
	---@param str string
	return function(str)
		if string.sub(str, 1, #cwd) == cwd then
			return string.sub(str, #cwd + 1)
		end
	end
end

local line_previewer = previewers.new_buffer_previewer({
	title = 'Preview',
	get_buffer_by_name = function(_, entry)
		return entry.filename
	end,
	define_preview = function(self, entry)
		local lines = vim.fn.readfile(entry.value.file)
		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

		local ft = vim.filetype.match({ filename = entry.value.file })
		if ft then
			vim.bo[self.state.bufnr].filetype = ft
		end

		vim.schedule(function()
			vim.api.nvim_win_set_cursor(self.state.winid, { entry.value.line, 0 })
			-- Center the view on the line
			local top = vim.fn.line('w0', self.state.winid)
			local bot = vim.fn.line('w$', self.state.winid)
			local center = math.floor(top + (bot - top) / 2)
			vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, 'Search', center - 1, 0, -1)
		end)
	end,
})

---@param prompt string
---@param data any
---@param cb function
M.search_stacks = function(prompt, data, cb)
	local opts = {}
	local strip = strip_prefix()

	pickers.new(opts, {
		prompt_title = prompt,
		finder = finders.new_table {
			results = data,
			entry_maker = function(entry)
				local display_str = string.format('%s.%s:%d', entry.stack, strip(entry.file), entry.line)
				return {
					value = entry,
					display = display_str,
					ordinal = display_str,
				}
			end
		},
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, _)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				cb(selection.value.file, selection.value.line)
			end)
			return true
		end,
		previewer = line_previewer,
	}):find()
end

return M
