local M = {}


local function get_remote_url()
  local fileDir = vim.fn.expand("%:p:h")
  local cdDir = string.format("cd %s; ", fileDir)
  local remotes = vim.fn.system(string.format("%s git remote", cdDir))
  local remote_list = vim.split(remotes, "\n")

  if #remote_list == 0 then
    print("It seems the repo does not have any remote.")
    return nil
  end

  -- NOTE: Remove the last empty string
  if remote_list[#remote_list] == "" then
    table.remove(remote_list, #remote_list)
  end

  if not vim.g.remote_line_git_remote_repository and #remote_list >= 2 then
    vim.ui.select(remote_list, {
      prompt = "Select remote",
    }, function(selected)
      if selected then
        vim.g.remote_line_git_remote_repository = selected
      end
    end)
  end

  if
      vim.g.remote_line_git_remote_repository
      and not vim.tbl_contains(remote_list, vim.g.remote_line_git_remote_repository)
  then
    error(
      "The remote"
      .. string.format(" `%s`", vim.g.remote_line_git_remote_repository)
      .. " does not exist in the repository."
      .. " Please correct the value set for `remote_line_git_remote_repository`."
    )
  end

  local remote = vim.g.remote_line_git_remote_repository or remote_list[1]

  local remote_url = vim.fn.system(cdDir .. "git config --get remote." .. remote .. ".url")
  remote_url = vim.fn.trim(remote_url)

  return remote_url
end

local function is_github(remote_url)
  return string.match(remote_url, "github")
end

local function is_gitlab(remote_url)
  return string.match(remote_url, "gitlab")
end

local function new_generate_url(remote_url, relative, line)
  local url = ""

  local commit_hash = vim.fn.system(
    "git blame -L " .. line .. "," .. line .. " " .. relative .. " -s | awk '{print $1}' | tr -d '\n'"
  )

  local function prepare_url(remote)
    local rv = remote
    local a_pattern = "^[^@]*@([^:/]*):?/?"
    local replacement = "https://%1/"
    rv = rv:gsub(a_pattern, replacement)

    rv = rv:gsub("\n$", "")

    local b_pattern = ".git" .. "$"
    rv = rv:gsub(b_pattern, "")

    return rv
  end

  if is_gitlab(remote_url) then
    url = prepare_url(remote_url) .. "/-/" .. "commit" .. "/" .. commit_hash
  else
    error(
      "The remote: "
      .. remote_url
      .. " has not been recognized as belonging to "
      .. "one of the supported git hosting environments: GitLab"
    )
  end

  return url
end

local function get_git_info(path)
  local fileDir = vim.fn.expand("%:p:h")
  local cdDir = string.format("cd %s; ", fileDir)

  local gitRoot = vim.fn.system(cdDir .. "git rev-parse --show-toplevel")

  local function strip_newlines(s)
    return s:gsub("\n", "")
  end

  gitRoot = strip_newlines(gitRoot)
  local fullPath = strip_newlines(path)

  local relative = fullPath:sub(#gitRoot + 2)

  return relative
end

local function new_url(line, path)
  local remote_url = get_remote_url()

  if not remote_url then
    error("fail to get url")
  end

  local relative = get_git_info(path)

  return new_generate_url(remote_url, relative, line)
end


local function open_remote(url)
  if vim.fn.has("macunix") == 1 then
    vim.fn.system("open " .. url)
  elseif vim.fn.has("unix") == 1 then
    vim.fn.system("xdg-open " .. url)
  elseif vim.fn.has("win32") == 1 then
    os.execute("start " .. url)
  else
    print("Unsupported OS")
  end
end

local function new_open(line, path)
  local url = new_url(line, path)

  if url == "" then
    return
  end

  open_remote(url)
end

function M.go(line, path)
  new_open(line, path)
end

-- function M.go(lastLine, path)
--   remote.new_open(lastLine, path)
-- end

return M
