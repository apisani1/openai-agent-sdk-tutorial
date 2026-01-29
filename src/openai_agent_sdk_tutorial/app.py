import argparse
from typing import Any

import gradio as gr
from dotenv import (
    find_dotenv,
    load_dotenv,
)
from openai_agent_sdk_tutorial.agent import run_agent
from openai_agent_sdk_tutorial.util import configure_logging


load_dotenv(find_dotenv(), override=True)


# Gradio chat interface function requires 2 parameters: message and history
# but history is managed by the OpenAI Agent SDK instead of Gradio
async def chat(message: str, history: Any) -> str:  # pylint: disable=unused-arguments
    return await run_agent(message)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OpenAI Agent SDK Tutorial Chat Client",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--debug",
        "-d",
        action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()
    configure_logging(level="DEBUG" if args.debug else "INFO")
    gr.ChatInterface(chat).launch()


if __name__ == "__main__":
    main()
