#!/usr/bin/bash
mkdir -p api
(cd api; godot --dump-extension-api & godot --dump-gdextension-interface )