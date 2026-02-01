"""Basic tests for openai-agent-sdk-tutorial."""


def test_import() -> None:
    """Test that the package can be imported."""
    import openai_agent_sdk_tutorial
    assert hasattr(openai_agent_sdk_tutorial, '__version__')


def test_version() -> None:
    """Test that version is defined."""
    from  openai_agent_sdk_tutorial import __version__
    assert __version__ is not None
    assert isinstance(__version__, str)
