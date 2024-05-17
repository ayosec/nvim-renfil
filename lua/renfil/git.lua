local M = {}

local Buffer = require("string.buffer")

---@param git_program string
---@param path string
---@param on_complete fun(in_index: boolean)
function M.in_index(git_program, path, on_complete)
    local on_exit = function(_, code, _)
        on_complete(code == 0)
    end

    local cmd = {
        git_program,
        "ls-files",
        "--error-unmatch",
        path,
    }

    vim.fn.jobstart(cmd, {
        on_exit = on_exit,
        cwd = vim.fs.dirname(path),
        stdin = "null",
    })
end

---@param git_program string
---@param overwrite boolean
---@param source_path string
---@param target_path string
---@param on_complete fun(success: boolean, stdout: string)
function M.rename(git_program, overwrite, source_path, target_path, on_complete)
    local cmd = { git_program, "mv" }

    if overwrite then
        table.insert(cmd, "--force")
    end

    table.insert(cmd, source_path)
    table.insert(cmd, target_path)

    local stdout = Buffer.new()

    local function read_io(_, data)
        stdout:put(table.concat(data, "\n"))
    end

    local on_exit = function(_, code, _)
        on_complete(code == 0, stdout:tostring())
    end

    vim.fn.jobstart(cmd, {
        on_exit = on_exit,
        cwd = vim.fs.dirname(source_path),
        stdin = "null",
        on_stdout = read_io,
        on_stderr = read_io,
    })
end

return M
