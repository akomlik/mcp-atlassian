#!/bin/bash

set -e

# The script is in the project directory, so we can use its location to define PROJECT_DIR
PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
VENV_DIR="$PROJECT_DIR/.venv"

# Check if the virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment in $VENV_DIR..." >&2
  python3 -m venv "$VENV_DIR"
fi

# Activate the virtual environment and install dependencies
source "$VENV_DIR/bin/activate"

echo "Installing/updating dependencies..." >&2
pip install --quiet -e "$PROJECT_DIR"

echo "Starting MCP Atlassian server..." >&2
exec mcp-atlassian