local renfil = require("renfil")

local config = require("renfil.config").default_config()

local CmdName = "RenameFileExtMods" .. math.random(1e6)

renfil.setup(vim.tbl_deep_extend("force", config, { user_command = CmdName }))

---@diagnostic disable-next-line:undefined-field
local assert_eq = assert.are.same

describe("ExtMods", function()
    it("apply extmods", function()
        local base = vim.fn.tempname()

        local cases = {
            { "%>mod", "a.x", "a/mod.x" },
            { "%<", "foo/a.x", "foo.x" },
            { "%/b.y", "b.x", "b.y" },
            { "%?a?b", "aa.x", "bb.x" },
        }

        for _, case in pairs(cases) do
            local source = base .. "/" .. case[2]
            local target = base .. "/" .. case[3]

            vim.fn.mkdir(vim.fs.dirname(source), "p")
            vim.fn.writefile({ "a", "b" }, source)

            vim.cmd.edit(source)
            vim.cmd[CmdName](case[1])

            vim.wait(1000, function()
                return vim.fn.filereadable(target) == 1
            end)

            assert_eq(target, vim.api.nvim_buf_get_name(0))
        end
    end)
end)
