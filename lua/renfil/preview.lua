local M = {}

local Diff = require("renfil.diff")

---@param preview_ns integer
---@param preview_buf integer
---@param source string
---@param target string
function M.preview(preview_ns, preview_buf, source, target)
    local from, to = Diff.diff_message(source, target)

    local lines = { "", "" }
    local highlights = {}

    local function add(linenum, text, hl)
        local line = lines[linenum]
        local start = #line + 1
        lines[linenum] = line .. text
        table.insert(highlights, { hl, linenum, start, #lines[linenum] })
    end

    add(1, " ← ", "RenFilArrow")
    add(2, " → ", "RenFilArrow")

    for linenum, line in ipairs { from, to } do
        for _, fragment in ipairs(line) do
            add(linenum, fragment[1], fragment[2])
        end
    end

    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

    for _, highlight in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(
            preview_buf,
            preview_ns,
            highlight[1],
            highlight[2] - 1,
            highlight[3] - 1,
            highlight[4]
        )
    end

    return 2
end

return M
