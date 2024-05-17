local renfil = require("renfil")
local testutils = require("tests.utils")

local config = require("renfil.config").default_config()

---@diagnostic disable-next-line:undefined-field
local assert_eq = assert.are.same

describe("Base", function()
    it("rename when target does not exist", function()
        local tx, rx = testutils.oneshot()

        local source = vim.fn.tempname()
        local target = vim.fn.tempname()

        vim.fn.writefile({ "a", "b" }, source)

        local bufnr = vim.fn.bufadd(source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, false, target, tx)
        rx()

        assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(0, vim.fn.filereadable(source))
        assert_eq({ "a", "b" }, vim.fn.readfile(target))
    end)

    it("don't overwrite target", function()
        local tx, rx = testutils.oneshot()

        local source = vim.fn.tempname()
        local target = vim.fn.tempname()

        vim.fn.writefile({ "a", "b" }, source)
        vim.fn.writefile({ "c", "d" }, target)

        local bufnr = vim.fn.bufadd(source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, false, target, tx)
        rx()

        assert_eq(source, vim.api.nvim_buf_get_name(bufnr))
        assert_eq({ "a", "b" }, vim.fn.readfile(source))
        assert_eq({ "c", "d" }, vim.fn.readfile(target))

        testutils.assert_message(target .. " already exists.")
    end)

    it("overwrite target", function()
        local tx, rx = testutils.oneshot()

        local source = vim.fn.tempname()
        local target = vim.fn.tempname()

        vim.fn.writefile({ "a", "b" }, source)
        vim.fn.writefile({ "c", "d" }, target)

        local bufnr = vim.fn.bufadd(source)
        local bufnr_target = vim.fn.bufadd(target)

        vim.fn.bufload(bufnr)
        vim.fn.bufload(bufnr_target)

        renfil.rename(config, bufnr, true, target, tx)
        rx()

        assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(0, vim.fn.filereadable(source))
        assert_eq({ "a", "b" }, vim.fn.readfile(target))

        assert_eq(0, vim.fn.bufexists(bufnr_target))
    end)

    it("failed rename", function()
        local tx, rx = testutils.oneshot()

        local source = vim.fn.tempname()
        local target = vim.fn.tempname() .. "/bad"

        vim.fn.writefile({ "a", "b" }, source)

        local bufnr = vim.fn.bufadd(source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, true, target, tx)
        rx()

        assert_eq(source, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(1, vim.fn.filereadable(source))

        testutils.assert_message("Rename to " .. target .. " failed.")
    end)
end)
