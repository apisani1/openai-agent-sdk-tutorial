"""Entry point for running the package as a module.

This file enables the package to be run directly with:
    python -m src.openai_agent_sdk_tutorial [--debug] [--log-file LOG_FILE]

Usage:
    python -m src.openai_agent_sdk_tutorial            # Normal mode
    python -m src.openai_agent_sdk_tutorial --debug    # Debug logging enabled
    python -m src.openai_agent_sdk_tutorial -l app.log # Log to file
"""

from .app import main


if __name__ == "__main__":
    main()
