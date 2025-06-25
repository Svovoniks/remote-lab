local M = {}

function M.get_git_info(path)
  local fileDir = vim.fn.expand("%:p:h")
  local cdDir = string.format("cd %s; ", fileDir)

  local commit = vim.fn.system(cdDir .. "git log -1 --format=%H")
  local gitRoot = vim.fn.system(cdDir .. "git rev-parse --show-toplevel")

  local function strip_newlines(s)
    return s:gsub("\n", "")
  end

  commit = strip_newlines(commit)
  gitRoot = strip_newlines(gitRoot)
  local fullPath = strip_newlines(path)

  local relative = fullPath:sub(#gitRoot + 2)

  return commit, relative
end

local function get_remote_url()
  local fileDir = vim.fn.expand("%:p:h")
  local cdDir = string.format("cd %s; ", fileDir)
  local remotes = vim.fn.system(string.format("%s git remote", cdDir))
  local remote_list = vim.split(remotes, "\n")

  if #remote_list == 0 then
    print("It seems the repo does not have any remote.")
    return nil
  end

  -- Remove last empty string if exists
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

local function github_line_range(firstLine, lastLine)
  if firstLine == lastLine then
    return "L" .. firstLine
  else
    return "L" .. firstLine .. "-L" .. lastLine
  end
end

local function gitlab_line_range(firstLine, lastLine)
  return "L" .. firstLine .. "-" .. lastLine
end

local function is_github(remote_url)
  return string.match(remote_url, "github")
end

local function is_gitlab(remote_url)
  return string.match(remote_url, "gitlab")
end

local function normalize_github_url(remote)
  local rv = remote:gsub("^git@([^:/]*):", "https://%1/")
  rv = rv:gsub("^ssh://git@", "https://")
  rv = rv:gsub("%.git$", "")
  return rv
end

local function normalize_gitlab_url(remote)
  local rv = normalize_github_url(remote)
  return rv
end

local function generate_github_url(remote_url, action, commit, relative, firstLine, lastLine)
  local base = normalize_github_url(remote_url)
  local lineRange = github_line_range(firstLine, lastLine)

  if action == "blob" then
    return string.format("%s/blob/%s/%s#%s", base, commit, relative, lineRange)
  elseif action == "commit" then
    return string.format("%s/commit/%s", base, commit)
  elseif action == "compare" then
    return string.format("%s/compare/%s...%s?expand=1", base, firstLine, lastLine)
  end
end

local function generate_gitlab_url(remote_url, action, commit, relative, firstLine, lastLine)
  local base = normalize_gitlab_url(remote_url)
  local lineRange = gitlab_line_range(firstLine, lastLine)

  if action == "blob" then
    return string.format("%s/-/blob/%s/%s#%s", base, commit, relative, lineRange)
  elseif action == "commit" then
    return string.format("%s/-/commit/%s", base, commit)
  elseif action == "compare" then
    return string.format("%s/-/compare/%s...%s", base, firstLine, lastLine)
  end
end

local function generate_url(remote_url, action, commit, relative, firstLine, lastLine)
  if is_github(remote_url) then
    return generate_github_url(remote_url, action, commit, relative, firstLine, lastLine)
  elseif is_gitlab(remote_url) then
    return generate_gitlab_url(remote_url, action, commit, relative, firstLine, lastLine)
  else
    error(
      "The remote: "
        .. remote_url
        .. " has not been recognized as belonging to "
        .. "one of the supported git hosting environments: Github or GitLab"
    )
  end
end

function M.url(firstLine, lastLine, path, action, mode)
  local remote_url = get_remote_url()

  if not remote_url then
    return
  end

  local commit, relative = M.get_git_info(path)

  local target_commit = mode == "" and commit or mode

  return generate_url(remote_url, action, target_commit, relative, firstLine, lastLine)
end

return M
