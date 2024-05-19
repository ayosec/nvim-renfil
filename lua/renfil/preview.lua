local M = {}

local Diff = require("renfil.diff")

---@param preview_ns integer
---@param preview_buf integer
---@param source string
---@param target string
---@param create_dirs boolean
function M.preview(preview_ns, preview_buf, source, target, create_dirs)
    local from, to = Diff.diff_message(source, target)

    local lines = { "", "" }
    local highlights = {}

    local function add(linenum, text, hl)
        local line = lines[linenum]
        local start = #line + 1
        lines[linenum] = line .. text

        if hl then
            table.insert(highlights, { hl, linenum, start, #lines[linenum] })
        end
    end

    add(1, " ← ", "RenFilArrow")
    add(2, " → ", "RenFilArrow")

    for linenum, line in ipairs { from, to } do
        for _, fragment in ipairs(line) do
            add(linenum, fragment[1], fragment[2])
        end
    end

    if not create_dirs then
        local target_dir = vim.fs.dirname(target)
        if vim.fn.isdirectory(target_dir) ~= 1 then
            vim.list_extend(lines, { "", "", "" })

            add(4, "W: Target directory does not exist.", "WarningMsg")

            -- Extract the current command name, if any.
            local cmdline = vim.fn.getcmdline() or ""
            local cmd = cmdline:match("%S+")
            if cmd then
                add(5, "H: Use ", nil)
                add(5, cmd .. " ++p", "Identifier")
                add(5, " to create it.", nil)
            end
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
