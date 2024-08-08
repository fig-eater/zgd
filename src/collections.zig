const std = @import("std");

pub fn ComptimeTrie(comptime entries: [][]const u8) type {
    const min, const max, const min_len, const max_len = comptime min_max_blk: {
        var max_val: u8 = 0;
        var min_val: u8 = std.math.maxInt(u8);
        var max_len: usize = 0;
        var min_len: usize = std.math.maxInt(usize);
        for (entries) |entry| {
            if (entry.len < min_len) {
                min_len = entry.len;
            }
            if (entry.len > max_len) {
                max_len = entry.len;
            }

            for (entry) |c| {
                if (c < min_val) {
                    min_val = c;
                }
                if (c > max_val) {
                    max_val = c;
                }
            }
        }
        break :min_max_blk .{ min_val, max_val, min_len, max_len };
    };

    const child_count = max - min;

    const TrieNode = struct {
        children: [child_count]?*@This() = &.{null} ** child_count,
        is_word: bool = false,

        pub inline fn next(self: @This(), b: u8) ?*const @This() {
            return if (b >= min and b <= max)
                self.children[b - min]
            else
                null;
        }
    };

    comptime var data: []TrieNode = &.{};
    comptime var root: TrieNode = .{};
    comptime {
        for (entries) |word| {
            var node: *TrieNode = &root;
            for (word) |c| {
                if (node.children[c]) |child| {
                    node = child;
                } else {
                    data = data ++ &.{TrieNode{}};
                    const next: *TrieNode = &data[data.len - 1];
                    node.children[c] = next;
                    node = next;
                }
            }
            node.is_word = true;
        }
    }

    const Trie = struct {
        root: Node,

        pub const Node = TrieNode;

        pub fn exists(self: @This(), bytes: []const u8) bool {
            if (bytes.len > max_len or bytes.len < min_len) return false;
            var node: *const Node = &self.root;
            for (bytes) |b| {
                if (node.next(b)) |next| {
                    node = next;
                } else {
                    return false;
                }
            }
            return node.is_word;
        }
    };
    return Trie;
}
