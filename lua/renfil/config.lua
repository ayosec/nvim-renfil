local M = {}

---@return renfil.Config
function M.default_config()
    ---@class renfil.Config
    local opts = {
        --- Name of the user command to rename the current buffer.
        ---@type string
        user_command = "RenameFile",

        --- Prompt when the target path is read from `ui.input`.
        ---@type string
        input_prompt = "Rename: ",

        --- Path to execute the `git` program.
        ---
        --- If `false`, git integration is disabled.
        ---
        ---@type string|false
        git = vim.fn.exepath("git"),
    }

    return opts
end

return M
