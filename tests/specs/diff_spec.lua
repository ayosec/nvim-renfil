local Diff = require("renfil.diff")

local PK = Diff.PartKind

---@diagnostic disable-next-line:undefined-field
local assert_eq = assert.are.same

describe("Diff", function()
    it("same path", function()
        local diff = Diff.paths_diff("/foo/bar", "/foo/bar")
        assert_eq({ { text = "/foo/bar", kind = PK.Common } }, diff)
    end)

    it("basename", function()
        local diff = Diff.paths_diff("/foo/bar.x", "/foo/bar2.x")
        assert_eq({
            { text = "/foo/", kind = PK.Common },
            { text = "bar", kind = PK.Removed },
            { text = "bar2", kind = PK.Added },
            { text = ".x", kind = PK.Common },
        }, diff)
    end)

    it("subdirectories", function()
        local diff = Diff.paths_diff("/a/b/c/bar.x", "/a/b/d/e/mod.x")
        assert_eq({
            { text = "/a/b/", kind = PK.Common },
            { text = "c", kind = PK.Removed },
            { text = "d", kind = PK.Added },
            { text = "/", kind = PK.Common },
            { text = "bar", kind = PK.Removed },
            { text = "e/mod", kind = PK.Added },
            { text = ".x", kind = PK.Common },
        }, diff)

        diff = Diff.paths_diff("foo/bar", "foo/x/bar")
        assert_eq({
            { text = "foo/", kind = PK.Common },
            { text = "x/", kind = PK.Added },
            { text = "bar", kind = PK.Common },
        }, diff)
    end)

    it("parent directory", function()
        local diff = Diff.paths_diff("foo/a.x", "bar/a.x")
        assert_eq({
            { text = "foo", kind = PK.Removed },
            { text = "bar", kind = PK.Added },
            { text = "/a.x", kind = PK.Common },
        }, diff)
    end)

    it("multiple changes", function()
        local diff = Diff.paths_diff("0/1/2/3/4/5/6/z", "0/1/4/5/7/8/z")
        assert_eq({
            { text = "0/1/", kind = PK.Common },
            { text = "2/3/", kind = PK.Removed },
            { text = "4/5/", kind = PK.Common },
            { text = "6", kind = PK.Removed },
            { text = "7/8", kind = PK.Added },
            { text = "/z", kind = PK.Common },
        }, diff)
    end)
end)
