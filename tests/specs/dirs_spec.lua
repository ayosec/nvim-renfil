local renfil = require("renfil")
local testutils = require("tests.utils")

local config = require("renfil.config").default_config()

---@diagnostic disable-next-line:undefined-field
local assert_eq = assert.are.same

describe("Directories", function()
    it("append basename to directories", function()
        local tx, rx = testutils.oneshot()

        local source_dir = vim.fn.tempname()
        local target_dir = vim.fn.tempname()

        vim.fn.mkdir(source_dir)
        vim.fn.mkdir(target_dir)

        local source = source_dir .. "/one"
        local target = target_dir .. "/one"

        vim.fn.writefile({ "a", "b" }, source)

        local bufnr = vim.fn.bufadd(source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, false, false, target_dir, tx)
        rx()

        assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(0, vim.fn.filereadable(source))
        assert_eq({ "a", "b" }, vim.fn.readfile(target))
    end)

    it("create missing directories", function()
        local tx, rx = testutils.oneshot()

        local source = vim.fn.tempname()
        local target = vim.fn.tempname() .. "/x"

        vim.fn.writefile({ "a", "b" }, source)

        local bufnr = vim.fn.bufadd(source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, true, false, target, tx)
        rx()

        assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(0, vim.fn.filereadable(source))
        assert_eq({ "a", "b" }, vim.fn.readfile(target))
    end)

    it("always create directories when ends with '/'", function()
        local tx, rx = testutils.oneshot()

        local source = vim.fn.tempname()
        local target = vim.fn.tempname() .. "/" .. vim.fs.basename(source)

        vim.fn.writefile({ "a", "b" }, source)

        local bufnr = vim.fn.bufadd(source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, false, false, vim.fs.dirname(target) .. "/", tx)
        rx()

        assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(0, vim.fn.filereadable(source))
        assert_eq({ "a", "b" }, vim.fn.readfile(target))
    end)
end)
