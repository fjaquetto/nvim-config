local function diffview_toggle()
	local ok, lib = pcall(require, "diffview.lib")
	if ok and lib.get_current_view() then
		vim.cmd("DiffviewClose")
	else
		vim.cmd("DiffviewOpen")
	end
end

return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gv", diffview_toggle, desc = "Diffview: abrir/fechar" },
		{ "<leader>gV", "<cmd>DiffviewOpen HEAD~1..HEAD<cr>", desc = "Diffview: último commit" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: histórico do arquivo" },
		{ "<leader>gX", "<cmd>DiffviewClose<cr>", desc = "Diffview: fechar" },
	},
	opts = {
		use_icons = true,
		view = {
			default = { layout = "diff2_horizontal" },
			merge_tool = { layout = "diff3_horizontal" },
			file_history = { layout = "diff2_horizontal" },
		},
	},
}
