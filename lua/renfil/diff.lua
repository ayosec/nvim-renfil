local M = {}

---@enum renfil.diff.PartKind
M.PartKind = {
    Common = "C",
    Added = "A",
    Removed = "R",
}

---@class renfil.diff.Part
---@field text string
---@field kind renfil.diff.PartKind

---@param source string
---@param target string
---@return renfil.diff.Part[]
function M.paths_diff(source, target)
    if source == target then
        return {
            {
                kind = M.PartKind.Common,
                text = source,
            },
        }
    end

    local source_parts = vim.split(source, "/")
    local target_parts = vim.split(target, "/")

    local diff = vim.diff(table.concat(source_parts, "\n"), table.concat(target_parts, "\n"), {
        ctxlen = math.max(#source_parts, #target_parts),
    })

    ---@type renfil.diff.Part[]
    local parts = {}

    for diff_line in vim.gsplit(diff, "\n") do
        ---@type renfil.diff.Part|nil
        local last = parts[#parts]

        local function add(t, kind)
            if last and last.kind == kind then
                last.text = last.text .. "/" .. t
            else
                table.insert(parts, { text = t, kind = kind })
            end
        end

        local prefix = diff_line:sub(1, 1)
        local text = diff_line:sub(2)

        if prefix == " " then
            if last and last.kind ~= M.PartKind.Common then
                text = "/" .. text
            end

            add(text, M.PartKind.Common)
            last = nil
        elseif prefix == "-" then
            add(text, M.PartKind.Removed)
        elseif prefix == "+" then
            add(text, M.PartKind.Added)
        else
            last = nil
        end

        if last then
            -- Slashes between fragments must appear in the `Common` ones.
            if last.kind == M.PartKind.Common then
                last.text = last.text .. "/"
            end
        end
    end

    return parts
end

---@param source string
---@param target string
---@return string[]
---@return string[]
function M.diff_message(source, target)
    local cwd = vim.fn.getcwd() .. "/"
    if vim.startswith(source, cwd) and vim.startswith(target, cwd) then
        source = source:sub(#cwd + 1)
        target = target:sub(#cwd + 1)
    end

    local parts = M.paths_diff(source, target)
    local from, to = {}, {}

    local function add(list, text, hl)
        local last = list[#list]

        -- Avoid two consecutive `/`.
        if last and last[1]:sub(-1) == "/" and text:sub(1, 1) == "/" then
            text = text:sub(2)
        end

        table.insert(list, { text, hl })
    end

    for _, part in ipairs(parts) do
        if part.kind == M.PartKind.Common then
            add(from, part.text, "RenFilPathCommon")
            add(to, part.text, "RenFilPathCommon")
        elseif part.kind == M.PartKind.Added then
            add(to, part.text, "RenFilPathAdded")
        elseif part.kind == M.PartKind.Removed then
            add(from, part.text, "RenFilPathRemoved")
        else
            error("Invalid part.kind in " .. vim.inspect(part))
        end
    end

    return from, to
end

return M
