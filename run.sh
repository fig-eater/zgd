#!/usr/bin/bash
mkdir -p gen
zig run main.zig -- api/extension_api.json gen/