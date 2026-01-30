"""Agent module demonstrating core OpenAI Agent SDK concepts.

This module showcases the fundamental building blocks of the OpenAI Agent SDK:

Key Concepts Demonstrated:
-------------------------
1. Agent Configuration: Creating agents with custom instructions, tools, and guardrails
2. Dynamic Instructions: Generating context-aware system prompts at runtime
3. Runner Execution: Using Runner.run() to execute agent conversations
4. Session Management: Persisting conversation state with SQLiteSession
5. Tracing: Using trace() for observability and debugging
6. Error Handling: Catching guardrail and execution exceptions

Architecture Overview:
---------------------
```
User Input → Input Guardrails → Dynamic Instructions → Agent Loop → Output Guardrails → Response
                                        │
                                        ├─ LLM Calls (with hooks)
                                        └─ Tool Execution (with hooks)
```

The Agent Loop:
--------------
1. Agent receives input (user message or tool result)
2. LLM generates a response (text or tool calls)
3. If tool calls: execute tools and loop back to step 1
4. If text response: check output guardrails and return

Key SDK Classes:
---------------
- Agent: The core abstraction representing an AI assistant with specific capabilities
- Runner: Orchestrates agent execution, handling the conversation loop
- RunConfig: Configuration for tracing, model overrides, and workflow metadata
- SQLiteSession: Persistent storage for conversation history across runs
- RunContextWrapper: Carries custom context data through the entire execution
"""

import logging
import uuid

from agents import (
    Agent,
    InputGuardrailTripwireTriggered,
    MaxTurnsExceeded,
    OutputGuardrailTripwireTriggered,
    RunConfig,
    RunContextWrapper,
    Runner,
    SQLiteSession,
    trace,
)
from openai_agent_sdk_tutorial.guardrail import (
    input_guardrail_foul_language,
    output_guardrail_unprofessional,
)
from openai_agent_sdk_tutorial.hook import (
    MyAgentHook,
    MyRunHook,
)
from openai_agent_sdk_tutorial.tool import send_contact_request_tool


logger = logging.getLogger(__name__)

# =============================================================================
# DYNAMIC AGENT INSTRUCTIONS
# =============================================================================

#     Instead of providing static instructions as a string, you can provide a callable
#     that generates instructions at runtime. This enables:
#     - Personalization: Tailor instructions based on user preferences stored in context
#     - Time-awareness: Adjust behavior based on time of day, day of week, etc.
#     - Feature flags: Enable/disable capabilities based on configuration
#     - A/B testing: Vary instructions for different user segments
#     - Multi-tenant: Customize behavior per tenant/organization

#     The callable receives:
#     - `context`: RunContextWrapper with access to custom data via `context.context`
#     - `agent`: The Agent instance, useful for accessing agent metadata

#     This pattern is called every time the agent needs its system prompt, which happens:
#     1. At the start of a conversation
#     2. After each tool execution (instructions are re-evaluated)


def generate_notification_agent_instructions(context: RunContextWrapper, agent: Agent) -> str:
    """Generate dynamic instructions for the Helpful Notification Agent.

    Args:
        context: The run context wrapper containing runtime state. Access custom
                 data passed to Runner.run() via `context.context`.
        agent: The agent instance requesting instructions. Useful for accessing
               the agent's name, model, or other configuration.

    Returns:
        str: The generated system prompt instructions that guide agent behavior.
    """
    # Base instructions define the agent's core behavior and personality
    base_instructions = """
You are a helpful financial services assistant that notifies other departments via push notifications.

Your responsibilities:
- Help users with their questions and requests
- Send push notifications when appropriate
- Record user contact details when they express interest in staying in touch
- Log any questions you cannot answer for follow-up

Guidelines:
- Be concise and friendly in your responses
- Only send notifications for important or requested information
"""

    logger.debug("Running Dynamic Instructions Generation:")
    logger.debug("Context: %s", context.context)
    logger.debug("Agent's Name: %s", agent.name)

    # Append context-specific information if available
    # The context.context attribute contains whatever was passed to Runner.run(context=...)
    if context.context:
        context_info = f"\n\nCurrent context: {str(context.context)}"
        return base_instructions + context_info

    return base_instructions


# =============================================================================
# CONFIGURATION
# =============================================================================

# RunConfig provides metadata and settings for the agent run.
# - workflow_name: Identifier for tracing and observability dashboards
# - Can also include: model overrides, tracing configuration, custom metadata
config = RunConfig(workflow_name="Openai Agent SDK Tutorial")

# SQLiteSession enables conversation persistence across multiple runs.
# This allows the agent to "remember" previous conversations.
#
# Key parameters:
# - db_path: Path to the SQLite database file
# - session_id: Unique identifier for this conversation session
#               Use same session_id to continue a conversation
#               Use different session_id for a new conversation
#
# The session stores:
# - Conversation history (user messages, assistant responses)
# - Tool call results
# - System context
session = SQLiteSession(db_path="memory.db", session_id="shared")

# Unique run identifier for tracing - useful for grouping traces by app run
run_id = str(uuid.uuid4())  # pylint: disable=invalid-name

# =============================================================================
# AGENT DEFINITION
# =============================================================================

# The Agent class is the core abstraction in the OpenAI Agent SDK.
# It encapsulates everything needed to define an AI assistant's behavior.
#
# Agent Configuration Options:
# ---------------------------
# - name: Human-readable identifier (can contain spaces, used in logs/traces)
# - instructions: System prompt - can be string or callable for dynamic generation
# - model: The LLM model to use (e.g., "gpt-5.2", "gpt-4o-mini")
# - tools: List of tools the agent can use (function_tool decorated functions)
# - input_guardrails: Validate/filter user input before processing
# - output_guardrails: Validate/filter agent output before returning
# - hooks: AgentHooks instance for lifecycle callbacks (agent-specific)
# - output_type: Pydantic model for structured output (optional)
# - handoffs: List of agents this agent can hand off to (optional)
my_agent = Agent(
    name="Helpful Notification Agent",
    instructions=generate_notification_agent_instructions,
    model="gpt-5.2",
    tools=[send_contact_request_tool],
    input_guardrails=[input_guardrail_foul_language],
    output_guardrails=[output_guardrail_unprofessional],
    hooks=MyAgentHook(),
)


# =============================================================================
# AGENT EXECUTION: Runner.run()
# =============================================================================
#    Runner.run() Execution Flow:
#     ---------------------------
#     1. Input Guardrails: Validate user input (can block execution)
#     2. Dynamic Instructions: Generate system prompt if callable
#     3. Agent Loop:
#        a. Send messages to LLM
#        b. If LLM returns tool calls → execute tools → loop back
#        c. If LLM returns text → proceed to output guardrails
#     4. Output Guardrails: Validate response (can block output)
#     5. Return: Final output to caller

#     Runner.run() Parameters:
#     -----------------------
#     - starting_agent: The agent to begin execution with
#     - input: User message (string or list of message items using Agent SDK format)
#     - context: Custom data accessible throughout execution via RunContextWrapper.context
#                This is where you pass user info, preferences, feature flags, etc.
#     - max_turns: Safety limit on agent loop iterations (prevents infinite loops)
#                   Each "turn" is one LLM call + potential tool execution
#     - hooks: RunHooks instance for lifecycle callbacks (applies to ALL agents)
#     - run_config: Configuration for tracing, model overrides, etc.
#     - session: Session instance for conversation persistence

#     Exception Handling:
#     ------------------
#     - InputGuardrailTripwireTriggered: Input failed validation (e.g., inappropriate content)
#     - OutputGuardrailTripwireTriggered: Output failed validation
#     - MaxTurnsExceeded: Agent exceeded max_turns limit (possible infinite loop)

#     The guardrail exceptions contain detailed information:
#     - `e.guardrail_result.output.output_info`: Custom data from the guardrail


async def run_agent(input: str) -> str:
    """Execute the agent with user input and return the response.

    Args:
        input: The user's message to process.

    Returns:
        str: The agent's final response, or an error message if processing failed.

    Example:
        ```python
        response = await run_agent("Send me a notification about the weather")
        print(response)  # "I've sent you a push notification about today's weather!"
        ```
    """
    try:
        # trace() creates a span for observability/debugging
        # All operations within this context are grouped under this trace
        # trace_id can be used to find group several runs in your tracing dashboard
        with trace("OpenAI Agent SDK Tutorial", trace_id="trace_" + run_id):
            result = await Runner.run(
                starting_agent=my_agent,
                input=input,
                context="Hola Precioso",
                max_turns=20,
                hooks=MyRunHook(),
                run_config=config,
                session=session,
            )
            return result.final_output

    except InputGuardrailTripwireTriggered as e:
        logger.error("Input guardrail triggered: %s", e)
        logger.error("Guardrail details: %s", e.guardrail_result.output.output_info)

    except OutputGuardrailTripwireTriggered as e:
        logger.error("Output guardrail triggered: %s", e)
        logger.error("Guardrail details: %s", e.guardrail_result.output.output_info)

    except MaxTurnsExceeded as e:
        logger.error("Max turns exceeded: %s", e)

    # Return a user-friendly error message when processing fails
    return "I'm sorry, but I couldn't process your request at this time. Please try again later."
