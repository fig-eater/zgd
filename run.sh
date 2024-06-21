#!/usr/bin/bash
rm -r src/gen/
zig build run -- src/api/extension_api.json src/gen/