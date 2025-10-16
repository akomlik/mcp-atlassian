# Gemini MCP for Atlassian Integration (Direnv Method)

This document outlines the final, working configuration for integrating the Gemini CLI with Jira and Confluence using the [mcp-atlassian](https://github.com/sooperset/mcp-atlassian) Docker container.

## Overview

The integration is configured via a custom MCP server definition in the Gemini CLI's `settings.json` file. The final, simplified configuration launches the Docker container directly. It relies on the shell's environment, populated by `direnv`, to be inherited by the Gemini CLI process.

**This method is flexible and can be configured globally (in `~/.gemini/settings.json`) or on a per-project basis.**

---

### ⚠️ Critical Bug: Non-Interactive Mode

Through extensive debugging, a critical bug or design limitation in the Gemini CLI has been identified:

**MCP servers that require an interactive Docker container (`docker run -i`) will hang indefinitely when called from the Gemini CLI's non-interactive "batch" mode.**

-   **Working:** `gemini` (starts interactive session) -> `get jira issue...`
-   **Hangs:** `gemini "get jira issue..."`

The only workaround is to use the interactive Gemini CLI session for all commands that require the Atlassian MCP tools.

---

### Quick Setup with `gemini mcp`

The `gemini mcp add` command provides a convenient way to bootstrap the initial `settings.json` configuration. However, due to a limitation in how it parses arguments, it requires a manual adjustment for our dynamic environment.

**Step 1: Run `gemini mcp add` to create the initial configuration.**

Use the `--scope` flag to target the desired `settings.json` file (`user` for global, `project` for local). This command will create the basic structure but will ignore environment flags without an explicit value.

```bash
# To configure the global (user) settings:
gemini mcp add atlassian --scope user docker run --rm -i \
  -e MCP_VERBOSE=false \
  ghcr.io/sooperset/mcp-atlassian:latest
```

**Step 2: Manually edit the generated `settings.json` file.**

The command above will create an incomplete entry. You must now manually edit the file (e.g., `~/.gemini/settings.json`) to add the full list of arguments and the `env` block that references the variables provided by `direnv`.

**The final, correct configuration should look like this:**

## Final `settings.json` Configuration

This configuration is the most robust and correct version, incorporating all of our debugging findings.

It relies on the fact that the `gemini` process inherits the environment variables loaded by `direnv`. The `-e` flags in the `args` array instruct Docker to pull those variables from the `gemini` process's environment into the container.

Most importantly, it includes the `DOCKER_HOST: ""` override in the `env` block. This is a critical fix for environments where `DOCKER_HOST` might be set to a remote Docker daemon (e.g., in your NSG project). This override forces the Gemini CLI to use the local Docker socket, ensuring the MCP container runs on your machine as intended.

```json
{
  "mcpServers": {
    "atlassian": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "--attach", "STDIN",
        "--attach", "STDOUT",
        "-e", "JIRA_URL",
        "-e", "JIRA_SSL_VERIFY",
        "-e", "JIRA_USERNAME",
        "-e", "JIRA_PERSONAL_TOKEN",
        "-e", "CONFLUENCE_URL",
        "-e", "CONFLUENCE_SSL_VERIFY",
        "-e", "CONFLUENCE_USERNAME",
        "-e", "CONFLUENCE_PERSONAL_TOKEN",
        "-e", "CONFLUENCE_SPACES_FILTER",
        "-e", "JIRA_PROJECT_FILTER",
        "-e", "MCP_VERBOSE",
        "-e", "MCP_LOGGING_STDOUT=false",
        "ghcr.io/sooperset/mcp-atlassian:latest"
      ],
      "env": {
        "DOCKER_HOST": ""
      }
    }
  }
}
```
*Note: The `cwd` key was found to be unnecessary in the final working configuration for interactive mode.*

---
## Alternative Configuration: Native Python Server

As an alternative to Docker, the MCP server can be run directly as a native Python process. This method avoids Docker-related complexities (like the non-interactive mode bug) and may offer better performance.

### Prerequisites
1.  The `mcp-atlassian` repository is cloned locally.
2.  The required Python dependencies are installed (e.g., in a virtual environment). The `run-mcp-atlassian.sh` script handles this for you.

### `settings.json` Configuration

This configuration executes the server's launcher script directly.

**Recommended:**
1.  Ensure the `run-mcp-atlassian.sh` script is executable (`chmod +x run-mcp-atlassian.sh`).
2.  Add the script's directory to your system's `PATH`, or move/symlink the script to a directory that is already in your `PATH` (e.g., `~/bin` or `/usr/local/bin`).

This allows you to use a simple command name in your `settings.json`, making it more portable.

```json
{
  "mcpServers": {
    "atlassian": {
      "command": "run-mcp-atlassian.sh",
      "args": [],
      "timeout": 10000,
      "description": "Atlassian Server (Native)"
    }
  }
}
```

**Alternative (Absolute Path):**

If you prefer not to modify your `PATH`, you can use the absolute path to the script. However, this makes the configuration less portable across different machines.

```json
{
  "mcpServers": {
    "atlassian": {
      "command": "/path/to/your/integrations/mcp-atlassian/run-mcp-atlassian.sh",
      "args": [],
      "timeout": 10000,
      "description": "Atlassian Server (Native)"
    }
  }
}
```

### Quick Setup with `gemini mcp add`

You can use the `gemini mcp add` command to quickly add this server to your settings.

Use the `--scope` flag to target the desired `settings.json` file (`user` for global, `project` for local).

```bash
# cd to this repo root directory

# To configure the global (user) settings:
gemini mcp add atlassian --scope user $PWD/run-mcp-atlassian.sh

# To configure the current project's settings:
gemini mcp add atlassian --scope project $PWD/run-mcp-atlassian.sh
```

This will generate the correct entry in your `settings.json` file.



## Required Environment Variables

For this integration to work, the following environment variables must be exported into your shell by `direnv`:

-   `JIRA_URL`
-   `JIRA_SSL_VERIFY`
-   `JIRA_USERNAME`
-   `JIRA_PERSONAL_TOKEN`
-   `CONFLUENCE_URL`
-   `CONFLUENCE_SSL_VERIFY`
-   `CONFLUENCE_USERNAME`
-   `CONFLUENCE_PERSONAL_TOKEN`
-   (and other optional variables)

For security, it is **highly recommended** to store sensitive values in 1Password.

## Setting Up `direnv` with `direnv-manager-1p.sh`

The required environment variables are provided by `direnv`. You can use the `direnv-manager-1p.sh` script from the `ai-workflow` project to generate the necessary `.envrc` file.

**Prerequisites:**
1.  The `direnv-manager-1p.sh` script is in your `PATH`.
2.  You have secrets stored in 1Password with titles prefixed by `envvar:` (e.g., `envvar:JIRA_PERSONAL_TOKEN`).

**Command:**

Run the following command in your project directory. It will create an `.envrc` file that:
1.  Fetches all secrets prefixed with `envvar:` from your "Employee" vault.
2.  Explicitly sets all the other required non-secret variables.

```bash
/path/to/direnv-manager-1p.sh --account zscaler.1password.com --vault Employee \
--env 'JIRA_URL=https://jira.corp.zscaler.com/' \
--env 'JIRA_SSL_VERIFY=false' \
--env 'JIRA_USERNAME=akomlik@zscaler.com' \
--env 'CONFLUENCE_URL=https://confluence.corp.zscaler.com/' \
--env 'CONFLUENCE_SSL_VERIFY=false' \
--env 'CONFLUENCE_USERNAME=akomlik@zscaler.com' \
--env 'CONFLUENCE_SPACES_FILTER=NET,HAP' \
--env 'JIRA_PROJECT_FILTER=NET' \
--env 'MCP_VERBOSE=false'
```

After running the command, approve the new configuration:
```bash
direnv allow
```
Your shell environment will now be correctly configured to launch the Atlassian MCP server.