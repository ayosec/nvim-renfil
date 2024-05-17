local renfil = require("renfil")
local testutils = require("tests.utils")

local config = require("renfil.config").default_config()

---@diagnostic disable-next-line:undefined-field
local assert_eq = assert.are.same

local function create_repo()
    local workdir = vim.fn.tempname()
    vim.fn.mkdir(workdir)

    local source = workdir .. "/one"

    vim.fn.writefile({ "a" }, source)

    local initcmds = {
        { "init" },
        { "add", "one" },
        { "commit", "--message", "nothing" },
    }

    for _, args in ipairs(initcmds) do
        local cmd = { "git", "-c", "user.email=renfil", "-c", "user.name=renfil" }
        vim.list_extend(cmd, args)
        testutils.run_command(cmd, workdir)
    end

    return { workdir = workdir, source = source }
end

describe("Git", function()
    it("rename tracked files", function()
        local tx, rx = testutils.oneshot()

        local repo = create_repo()
        local target = repo.workdir .. "/two"

        local bufnr = vim.fn.bufadd(repo.source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, false, false, target, tx)
        rx()

        assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        assert_eq(0, vim.fn.filereadable(repo.source))
        assert_eq({ "a" }, vim.fn.readfile(target))

        testutils.run_command({ "git", "ls-files", "--error-unmatch", target }, repo.workdir)
    end)

    it("don't overwrite target", function()
        local tx, rx = testutils.oneshot()

        local repo = create_repo()
        local target = repo.workdir .. "/two"

        vim.fn.writefile({ "b" }, target)

        testutils.run_command({ "git", "add", "two" }, repo.workdir)

        local bufnr = vim.fn.bufadd(repo.source)
        vim.fn.bufload(bufnr)

        renfil.rename(config, bufnr, false, false, target, tx)
        rx()

        assert_eq(repo.source, vim.api.nvim_buf_get_name(bufnr))
        assert_eq({ "a" }, vim.fn.readfile(repo.source))
        assert_eq({ "b" }, vim.fn.readfile(target))

        testutils.assert_message("git-mv failed")
    end)
end)
