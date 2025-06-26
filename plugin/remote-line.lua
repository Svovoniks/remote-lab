if vim.g.loaded_remote_line then
  return
end
vim.g.loaded_remote_line = 1

vim.api.nvim_create_user_command("RemoteLab", function(opts)
  require("remote-lab.main").go(opts.line1, vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
end, {
  range = true,
  nargs = "?",
})
