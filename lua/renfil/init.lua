local M = {}

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

        local function do_rename()
            M.rename(config, bufnr, overwrite, argument)
        end

        if argument then
            do_rename()
        else
            local cwd = vim.fn.getcwd() .. "/"
            local current_name = vim.api.nvim_buf_get_name(bufnr)

            if vim.startswith(current_name, cwd) then
                current_name = current_name:sub(#cwd + 1)
            end

            vim.ui.input({
                prompt = config.input_prompt,
                default = current_name,
                completion = "file",
            }, function(input)
                if input then
                    argument = vim.fn.simplify(vim.fn.fnamemodify(input, ":p"))
                    do_rename()
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
function M.rename(config, bufnr, overwrite, target_path)
    local source_path = vim.api.nvim_buf_get_name(bufnr)
    target_path = vim.fn.fnamemodify(target_path, ":p")

    if source_path == target_path then
        return
    end

    if not overwrite then
        -- Ideally, the rename should be done with `RENAME_NOREPLACE`,
        -- but this is not available in Neovim.
        if vim.loop.fs_stat(target_path) then
            vim.api.nvim_err_writeln(target_path .. " already exists.")
            return
        end
    end

    -- Use rename() since it can move files between devices (like tmpfs/ext4).
    ---@diagnostic disable-next-line param-type-mismatch
    local result = vim.fn.rename(source_path, target_path)
    if result ~= 0 then
        vim.api.nvim_err_writeln("Rename to " .. target_path .. " failed.")
        return
    end

    -- Replace buffer name.
    ---@diagnostic disable-next-line param-type-mismatch
    local old_bufnr = vim.fn.bufnr(target_path)
    if old_bufnr ~= -1 then
        vim.api.nvim_buf_delete(old_bufnr, { force = true })
    end

    vim.api.nvim_buf_set_name(bufnr, vim.fn.fnamemodify(target_path, ":."))
    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent! write!")
        vim.cmd.edit()
    end)
end

return M
