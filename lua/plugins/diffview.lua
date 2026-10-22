return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
		{ "<leader>gV", "<cmd>DiffviewOpen HEAD~1..HEAD<cr>", desc = "Diffview: último commit" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: histórico do arquivo" },
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
