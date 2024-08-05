local M = {}

---@enum renfil.diff.PartKind
M.PartKind = {
    Common = "C",
    Added = "A",
    Removed = "R",
}

---@param path string
---@return string[]
local function path_split(path)
    local parts = {}
    while path ~= "" do
        local a, b, tail = path:match("^(%W*)(%w*)(.*)")
        if a and a ~= "" then
            table.insert(parts, a)
        end

        if b and b ~= "" then
            table.insert(parts, b)
        end

        path = tail
    end

    return parts
end

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

    local source_parts = path_split(source)
    local target_parts = path_split(target)

    local diff = vim.diff(table.concat(source_parts, "\n"), table.concat(target_parts, "\n"), {
        algorithm = "minimal",
        ctxlen = math.max(#source_parts, #target_parts),
    })

    ---@type renfil.diff.Part[]
    local parts = {}

    for diff_line in vim.gsplit(diff, "\n") do
        ---@type renfil.diff.Part|nil
        local last = parts[#parts]

        local function add(t, kind)
            if last and last.kind == kind then
                last.text = last.text .. t
            else
                table.insert(parts, { text = t, kind = kind })
            end
        end

        local prefix = diff_line:sub(1, 1)
        local text = diff_line:sub(2)

        if prefix == " " then
            add(text, M.PartKind.Common)
        elseif prefix == "-" then
            add(text, M.PartKind.Removed)
        elseif prefix == "+" then
            add(text, M.PartKind.Added)
        end
    end

    return parts
end

---@param path string
---@param max_components integer
---@return boolean
---@return string
local function shared_prefix(path, max_components)
    local components = vim.split(path, "/")
    local to_drop = #components - max_components
    if to_drop < 1 then
        return false, path
    end

    return true, table.concat(vim.list_slice(components, to_drop + 1), "/")
end

---@param source string
---@param target string
---@param max_components_shared_prefix? integer
---@return string[]
---@return string[]
function M.diff_message(source, target, max_components_shared_prefix)
    source = vim.fn.fnamemodify(source, ":p:.")
    target = vim.fn.fnamemodify(target, ":p:.")

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

    for idx, part in ipairs(parts) do
        if part.kind == M.PartKind.Common then
            local text = part.text
            if max_components_shared_prefix and idx == 1 then
                local modified, common = shared_prefix(text, max_components_shared_prefix)
                if modified then
                    add(from, "…", "RenFilSharedPrefix")
                    add(to, "…", "RenFilSharedPrefix")
                    text = "/" .. common
                else
                    text = common
                end
            end

            add(from, text, "RenFilPathCommon")
            add(to, text, "RenFilPathCommon")
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
