local M = {}

---@alias renfil.ExtMod fun(input: string, source: string):string?

---@type table<string, renfil.ExtMod>
M.DEFAULT = {

    --- Move a file to a subdirectory, like `foo.lua → foo/init.lua`.
    ["%>"] = function(input, source)
        local suffix = source:find(".", 1, true) and ".%:e" or ""
        return vim.fn.substitute(input, [[^%>\(.*\)$]], [[%:r/\1]] .. suffix, "")
    end,

    --- Move a file to its parent directory, like `foo/init.lua → foo.lua`.
    ["%<"] = function(input, _)
        if input == "%<" then
            return "%:h.%:e"
        end
    end,

    --- Set a new new name in the same directory.
    ["%/"] = function(input, _)
        return vim.fn.substitute(input, [[^%/]], [[%:h/]], "")
    end,

    --- Use `%:gs?…?…?` to replace a string in the name.
    ["%?"] = function(input, _)
        if vim.fn.count(input, "?") < 2 then
            return nil
        end

        local suffix = input:sub(-1) == "?" and "" or "?"

        return vim.fn.substitute(input, [[^%?\(.*\)$]], [[%:gs?\1]] .. suffix, "")
    end,
}

---@param extmods table<string, renfil.ExtMod>
---@param argument string
---@param source string
---@return nil|string
function M.apply_extmods(extmods, argument, source)
    for prefix, extmod in pairs(extmods) do
        if vim.startswith(argument, prefix) then
            local modified = extmod(argument, source)
            if modified then
                return modified
            end
        end
    end
end

return M
