#!/bin/bash
set -e
cd work
find coloros/ -name "*.bak" 2>/dev/null | while read -r bak; do
  mv "$bak" "${bak%.bak}"
done