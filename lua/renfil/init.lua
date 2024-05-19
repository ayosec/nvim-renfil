local M = {}

---@param bufnr integer
---@param path string
local function update_buffer_names(bufnr, path)
    -- Delete old buffers with the same name to avoid collisions.
    for _, other_buf in pairs(vim.api.nvim_list_bufs()) do
        if other_buf ~= bufnr then
            local n = vim.api.nvim_buf_get_name(other_buf)
            if n == path then
                vim.api.nvim_buf_delete(other_buf, { force = true })
                break
            end
        end
    end

    vim.api.nvim_buf_set_name(bufnr, vim.fn.fnamemodify(path, ":."))
    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent! write!")
        vim.cmd.edit()
    end)
end

---@param bufnr integer
---@param overwrite boolean
---@param source_path string
---@param target_path string
---@param on_complete nil|fun(success: boolean)
local function regular_rename(bufnr, overwrite, source_path, target_path, on_complete)
    if not overwrite then
        -- Ideally, the rename should be done with `RENAME_NOREPLACE`,
        -- but this is not available in Neovim.
        if vim.loop.fs_stat(target_path) then
            vim.api.nvim_err_writeln(target_path .. " already exists.")

            if on_complete then
                on_complete(false)
            end

            return
        end
    end

    -- Use rename() since it can move files between devices (like tmpfs/ext4).
    ---@diagnostic disable-next-line param-type-mismatch
    local result = vim.fn.rename(source_path, target_path)
    if result ~= 0 then
        vim.api.nvim_err_writeln("Rename to " .. target_path .. " failed.")

        if on_complete then
            on_complete(false)
        end

        return
    end

    update_buffer_names(bufnr, target_path)

    if on_complete then
        on_complete(true)
    end
end

--- Compute the source and target for the rename command.
---
---@param bufnr integer
---@param argument string
---@return nil|{ create_dirs: boolean, target: string }
local function parse_argument(bufnr, argument)
    local create_dirs = argument:sub(-1) == "/"

    -- Extract options from the argument, similar to `:write`.
    --
    -- Currently, only `++p` is supported.
    while true do
        local _, _, opt, tail = argument:find("^%s*++(%S+)%s*(.*)")
        if not opt then
            break
        end

        if opt == "p" then
            create_dirs = true
        else
            vim.api.nvim_err_writeln("Invalid option: ++" .. opt)
            return
        end

        argument = tail
    end

    local filename = vim.fn.expandcmd(argument)

    if filename:sub(-1) == "/" then
        local source = vim.api.nvim_buf_get_name(bufnr)
        filename = filename .. vim.fs.basename(source)
    end

    filename = vim.fn.fnamemodify(filename, ":p")

    return {
        create_dirs = create_dirs,
        target = vim.fn.simplify(filename),
    }
end

---@param config renfil.Config
---@param overwrite boolean
---@param farg string?
local function command_impl(config, overwrite, farg)
    local bufnr = vim.api.nvim_get_current_buf()

    local current_name = vim.api.nvim_buf_get_name(bufnr)

    -- Reject non-file buffers.
    if vim.api.nvim_buf_get_option(bufnr, "buftype") ~= "" then
        vim.api.nvim_err_writeln("The current buffer is not a file.")
        return
    end

    -- Reject buffers if the file is not on disk.
    if vim.fn.filereadable(current_name) == 0 then
        vim.api.nvim_err_writeln("The file for this buffer does not exist.")
        return
    end

    local function do_rename(arg)
        local opts = parse_argument(bufnr, arg)
        if opts then
            local function on_complete(success)
                if not success then
                    return
                end

                local diff = require("renfil.diff")
                local from, to = diff.diff_message(current_name, opts.target)

                local msg = { { "[Rename] ", "RenFilHeader" } }
                vim.list_extend(msg, from)
                table.insert(msg, { " → ", "RenFilArrow" })
                vim.list_extend(msg, to)

                vim.api.nvim_echo(msg, true, {})
            end

            M.rename(config, bufnr, opts.create_dirs, overwrite, opts.target, on_complete)
        end
    end

    -- If present, use the command argument as the target,
    -- or ask for it if missing.
    if farg then
        do_rename(farg)
    else
        local cwd = vim.fn.getcwd() .. "/"

        if vim.startswith(current_name, cwd) then
            current_name = current_name:sub(#cwd + 1)
        end

        vim.ui.input({
            prompt = config.input_prompt,
            default = current_name,
            completion = "file",
        }, function(input)
            if input then
                do_rename(input)
            end
        end)
    end
end

local function set_default_hls()
    local hls = {
        RenFilArrow = { link = "Operator" },
        RenFilHeader = { link = "Title" },
        RenFilPathAdded = { fg = "green", ctermfg = 2 },
        RenFilPathCommon = { link = "Normal" },
        RenFilPathRemoved = { fg = "red", ctermfg = 1 },
    }

    for name, spec in pairs(hls) do
        spec.default = true
        vim.api.nvim_set_hl(0, name, spec)
    end
end

---@param config? renfil.Config
function M.setup(config)
    local default_config = require("renfil.config").default_config()

    ---@type renfil.Config
    config = vim.tbl_deep_extend("force", {}, default_config, config or {})

    local function callback(call_opts)
        command_impl(config, call_opts.bang, call_opts.fargs[1])
    end

    vim.api.nvim_create_user_command(config.user_command, callback, {
        nargs = "?",
        bang = true,
        complete = "file",
        desc = "Rename the file of the current buffer.",
    })

    set_default_hls()
end

---@param config renfil.Config
---@param bufnr integer
---@param create_dirs boolean
---@param overwrite boolean
---@param target_path string
---@param on_complete nil|fun(success: boolean)
function M.rename(config, bufnr, create_dirs, overwrite, target_path, on_complete)
    local source_path = vim.api.nvim_buf_get_name(bufnr)
    target_path = vim.fn.fnamemodify(target_path, ":p")

    if source_path == target_path then
        if on_complete then
            on_complete(true)
        end

        return
    end

    local target_parent
    local target_is_dir = false

    if target_path:sub(-1) == "/" then
        -- If `target` ends with `/` (so it is a directory),
        -- ensure that it created if missing.
        create_dirs = true
        target_is_dir = true
    elseif vim.fn.isdirectory(target_path) == 1 then
        target_path = target_path .. "/"
        target_is_dir = true
    end

    if target_is_dir then
        -- Append the original basename if target is a directory.
        target_parent = target_path
        target_path = target_path .. vim.fs.basename(source_path)
    else
        target_parent = vim.fs.dirname(target_path)
    end

    if create_dirs and vim.fn.isdirectory(target_parent) ~= 1 then
        local res = vim.fn.mkdir(target_parent, "p")

        if res ~= 1 then
            local msg = {
                { "Unable to create directory " .. target_parent, "ErrorMsg" },
            }

            vim.api.nvim_echo(msg, true, {})

            if on_complete then
                on_complete(false)
            end

            return
        end
    end

    local function rr()
        regular_rename(bufnr, overwrite, source_path, target_path, on_complete)
    end

    if config.git and config.git ~= "" then
        -- If git integration is enabled, check if the file is in a git index.
        -- In such case, use `git-mv` to rename it.

        local git = require("renfil.git")
        git.in_index(config.git, source_path, function(in_git)
            if in_git then
                git.rename(config.git, overwrite, source_path, target_path, function(success, stdout)
                    if success then
                        update_buffer_names(bufnr, target_path)
                    else
                        local msg = {
                            { "[git-mv failed]", "ErrorMsg" },
                            { " ", "Normal" },
                            { stdout, "Normal" },
                        }

                        vim.api.nvim_echo(msg, true, {})
                    end

                    if on_complete then
                        on_complete(success)
                    end
                end)
            else
                rr()
            end
        end)

        return
    end

    rr()
end

return M
