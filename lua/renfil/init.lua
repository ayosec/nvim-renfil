local M = {}

---@param bufnr integer
---@param path string
local function update_buffer_names(bufnr, path)
    -- Replace buffer name.
    ---@diagnostic disable-next-line param-type-mismatch
    local old_bufnr = vim.fn.bufnr(path)
    if old_bufnr ~= -1 then
        vim.api.nvim_buf_delete(old_bufnr, { force = true })
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

---@param config? renfil.Config
function M.setup(config)
    local default_config = require("renfil.config").default_config()

    ---@type renfil.Config
    config = vim.tbl_deep_extend("force", {}, default_config, config or {})

    local opts = {
        nargs = "?",
        bang = true,
        complete = "file",
        desc = "Rename the file of the current buffer.",
    }

    local function callback(call_opts)
        local bufnr = vim.api.nvim_get_current_buf()
        local overwrite = call_opts.bang
        local argument = call_opts.fargs[1]

        local current_name = vim.api.nvim_buf_get_name(bufnr)

        if vim.api.nvim_buf_get_option(bufnr, "buftype") ~= "" or vim.fn.filereadable(current_name) == 0 then
            vim.api.nvim_err_writeln("The current buffer is not a file.")
            return
        end

        local function do_rename(filename)
            filename = vim.fn.expandcmd(filename)
            filename = vim.fn.fnamemodify(filename, ":p")
            filename = vim.fn.simplify(filename)
            M.rename(config, bufnr, overwrite, filename)
        end

        if argument then
            do_rename(argument)
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

    vim.api.nvim_create_user_command(config.user_command, callback, opts)
end

---@param config renfil.Config
---@param bufnr integer
---@param overwrite boolean
---@param target_path string
---@param on_complete nil|fun(success: boolean)
function M.rename(config, bufnr, overwrite, target_path, on_complete)
    local source_path = vim.api.nvim_buf_get_name(bufnr)
    target_path = vim.fn.fnamemodify(target_path, ":p")

    if source_path == target_path then
        if on_complete then
            on_complete(true)
        end

        return
    end

    if vim.fn.isdirectory(target_path) == 1 then
        if target_path:sub(-1, -1) ~= "/" then
            target_path = target_path .. "/"
        end

        target_path = target_path .. vim.fs.basename(source_path)
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
                regular_rename(bufnr, overwrite, source_path, target_path, on_complete)
            end
        end)

        return
    end

    regular_rename(bufnr, overwrite, source_path, target_path, on_complete)
end

return M
