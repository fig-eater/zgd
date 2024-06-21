#!/usr/bin/bash
mkdir -p src/api
(cd src/api; godot --dump-extension-api & godot --dump-gdextension-interface )