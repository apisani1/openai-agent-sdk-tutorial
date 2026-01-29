# OpenAI Agent SDK Tutorial

Educational project demonstrating the [OpenAI Agent SDK](https://github.com/openai/openai-agents-python). Provides working examples of agents, tools, and guardrails with comprehensive inline documentation.

## Project Structure

```
src/openai_agent_sdk_tutorial/
├── app.py           # Main entry point - CLI and Gradio chat interface
├── agent.py         # Agent configuration
├── tool.py          # Function tools and agents-as-tools
├── guardrail.py     # Input/output guardrails for agents
├── hook.py          # Hooks implementations
└── util.py          # Logging configuration
```

## Requirements

- Python 3.10+
- OpenAI API key

## Installation

```bash
# Clone the repository
git clone https://github.com/apisani1/openai-agent-sdk-tutorial.git
cd openai-agent-sdk-tutorial

# Install dependencies
poetry install
```

## Running the Application

```bash
export OPENAI_API_KEY="your-key"

# Run with Gradio chat interface
python src/openai_agent_sdk_tutorial/app.py

# Run with debug logging
python src/openai_agent_sdk_tutorial/app.py --debug
```

## Development

```bash
# Install dev dependencies
make install-dev

# Format and lint
make check

# Run tests
make test
```
