#!/bin/bash

######################
# This script was inspired by automation patterns from
# phitoduck/python-course-cookiecutter-v2, but is an independent implementation.
######################

set -e

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

######################
# ENVIRONMENT
######################

# Install core dependencies
function install {
    echo "Installing core dependencies..."
    poetry install --only main
}

# Install all development dependencies
function install:dev {
    echo "Installing development dependencies..."
    poetry install --with dev,test,lint,typing
}

function install:all {
    echo "Installing all dependencies..."
    poetry install --with dev,test,lint,typing --no-interaction
}

# Install specific dependency groups
function install:test {
    echo "Installing test dependencies..."
    poetry install --with test
}

function install:lint {
    echo "Installing linting dependencies..."
    poetry install --with lint
}

# Update all dependencies
function update {
    echo "Updating dependencies..."
    poetry update
}

# Create a new virtual environment
function venv {
    echo "Creating virtual environment..."

    # Manually deactivate conda environment if active
    if [ -n "$CONDA_DEFAULT_ENV" ]; then
        echo "Deactivating conda environment: $CONDA_DEFAULT_ENV"
        # Clean all conda-related variables
        unset CONDA_DEFAULT_ENV CONDA_PREFIX CONDA_PYTHON_EXE CONDA_PROMPT_MODIFIER
        # Restore original PATH (remove conda paths)
        if [ -n "$_CONDA_OLD_PATH" ]; then
            export PATH="$_CONDA_OLD_PATH"
        fi
    fi

    # Manually deactivate regular virtual environment if active
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "Deactivating virtual environment: $(basename $VIRTUAL_ENV)"
        # Clean all venv-related variables
        unset VIRTUAL_ENV PYTHONHOME
        # Restore original PATH (remove venv paths)
        if [ -n "$_OLD_VIRTUAL_PATH" ]; then
            export PATH="$_OLD_VIRTUAL_PATH"
        else
            # Fallback: try to remove common venv path patterns
            export PATH=$(echo "$PATH" | sed -E 's|[^:]*\.venv/bin:||g' | sed -E 's|:[^:]*\.venv/bin||g')
        fi
    fi

    # Ensure clean environment for Poetry (comprehensive cleanup)
    unset VIRTUAL_ENV POETRY_ACTIVE PYTHONHOME

    # Force zsh explicitly
    SHELL=/bin/zsh exec poetry shell
}

# Lock dependencies without installing them
function lock {
    echo "Locking dependencies..."
    poetry lock
}

# Create a new Jupyter kernel for the current project
function kernel {
    echo "Installing Jupyter kernel..."
    PYTHON_VERSION=$(poetry run python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PROJECT_NAME=$(poetry version | cut -d' ' -f1)
    poetry run python -m ipykernel install --user \
        --name="$PROJECT_NAME" \
        --display-name="Python $PYTHON_VERSION ($PROJECT_NAME)"
}

# Remove the Jupyter kernel for the current project
function remove:kernel {
    echo "Removing Jupyter kernel..."
    PROJECT_NAME=$(poetry version | cut -d' ' -f1)
    poetry run jupyter kernelspec remove "$PROJECT_NAME" -y
}

# Export requirements.txt files
function requirements {
    echo "Exporting requirements.txt..."
    if ! poetry export --help >/dev/null 2>&1; then
        echo "Installing poetry-plugin-export..."
        poetry self add poetry-plugin-export
    fi
    poetry export -f requirements.txt --output requirements.txt --without-hashes
    poetry export -f requirements.txt --with dev,test,lint,typing --output requirements-dev.txt --without-hashes
    echo "Requirements files created successfully"
}

######################
# LINTING AND FORMATTING
######################

# Helper function to get Python files
function get:python:files {
    echo "./src/openai_agent_sdk_tutorial/"
}

function get:python:files:diff {
    git diff --name-only --diff-filter=d main | grep -E '\.py$|\.ipynb$' || echo ""
}

function get:python:files:tests {
    echo "tests/"
}

# Individual linting functions
function lint:mypy {
    echo "Running mypy..."
    PYTHON_FILES="${1:-$(get:python:files)}"
    MYPY_CACHE="${2:-.mypy_cache}"

    if [ ! -z "$PYTHON_FILES" ]; then
        mkdir -p "$MYPY_CACHE"
        poetry run mypy $PYTHON_FILES --cache-dir "$MYPY_CACHE"
    else
        echo "No Python files to check with mypy."
    fi
}

function lint:flake8 {
    echo "Running flake8..."
    PYTHON_FILES="${1:-$(get:python:files)}"

    if [ ! -z "$PYTHON_FILES" ]; then
        poetry run flake8 $PYTHON_FILES
    else
        echo "No Python files to check with flake8."
    fi
}

function lint:pylint {
    echo "Running pylint..."
    PYTHON_FILES="${1:-$(get:python:files)}"

    if [ ! -z "$PYTHON_FILES" ]; then
        poetry run pylint $PYTHON_FILES
    else
        echo "No Python files to check with pylint."
    fi
}

# Main linting function
function lint {
    lint:mypy
    lint:flake8
    lint:pylint
}

# Run all linters on changed files
function lint:diff {
    PYTHON_FILES=$(get:python:files:diff)
    echo "Running linters on changed files..."
    lint:mypy "$PYTHON_FILES" ".mypy_cache_diff"
    lint:flake8 "$PYTHON_FILES"
    lint:pylint "$PYTHON_FILES"
}

# Run all linters on test files
function lint:tests {
    PYTHON_FILES=$(get:python:files:tests)
    echo "Running linters on test files..."
    lint:mypy "$PYTHON_FILES" ".mypy_cache_test"
    lint:flake8 "$PYTHON_FILES"
    lint:pylint "$PYTHON_FILES"
}

# Individual formatting functions
function format:black {
    echo "Running black..."
    PYTHON_FILES="${1:-$(get:python:files)}"

    if [ ! -z "$PYTHON_FILES" ]; then
        poetry run black $PYTHON_FILES
    else
        echo "No Python files to format with black."
    fi
}

function format:isort {
    echo "Running isort..."
    PYTHON_FILES="${1:-$(get:python:files)}"

    if [ ! -z "$PYTHON_FILES" ]; then
        poetry run isort $PYTHON_FILES
    else
        echo "No Python files to format with isort."
    fi
}

# CI-specific formatting checks (don't modify files)
function format:check:black {
    echo "Checking code formatting with black..."
    PYTHON_FILES="${1:-$(get:python:files)}"

    if [ ! -z "$PYTHON_FILES" ]; then
        poetry run black --check --diff $PYTHON_FILES
    else
        echo "No Python files to check with black."
    fi
}

function format:check:isort {
    echo "Checking import sorting with isort..."
    PYTHON_FILES="${1:-$(get:python:files)}"

    if [ ! -z "$PYTHON_FILES" ]; then
        poetry run isort --check-only --diff $PYTHON_FILES
    else
        echo "No Python files to check with isort."
    fi
}


# Main formatting function
function format {
    format:black
    format:isort
}

# Combined format checking (for CI)
function format:check {
    format:check:black
    format:check:isort
}

# Run formatters on changed files
function format:diff {
    PYTHON_FILES=$(get:python:files:diff)
    echo "Running formatters on changed files..."
    format:black "$PYTHON_FILES"
    format:isort "$PYTHON_FILES"
}

# Run formatters on test files
function format:tests {
    PYTHON_FILES=$(get:python:files:tests)
    echo "Running formatters on test files..."
    format:black "$PYTHON_FILES"
    format:isort "$PYTHON_FILES"
}

# Combined check
function check {
    # Note: This applies formatting (for local development)
    install:all
    format
    lint
    tests
}

# Combined check for CI (format check + lint + test)
function check:ci {
    format:check
    lint
    tests
}

# Pre-commit check
function pre:commit {
    format:diff
    lint:diff
    tests
}

######################
# TESTING
######################

# Run tests
function tests {
    echo "Running tests..."
    TEST_FILE="${1:-$(get:python:files:tests)}"
    shift || true
    poetry run pytest "$TEST_FILE" "$@"
}

# Run tests with coverage
function tests:cov {
    echo "Running tests with coverage..."
    TEST_FILE="${1:-$(get:python:files:tests)}"
    shift || true
    poetry run pytest "$TEST_FILE" --cov=openai_agent_sdk_tutorial  --cov-report=term "$@"
}

# Run tests in verbose mode
function tests:verbose {
    echo "Running tests in verbose mode..."
    TEST_FILE="${1:-$(get:python:files:tests)}"
    shift || true
    poetry run pytest "$TEST_FILE" -v "$@"
}

# Run tests that match a specific pattern
function tests:pattern {
    if [ -z "$1" ]; then
        echo "Usage: test:pattern <pattern> [test_file]"
        return 1
    fi
    PATTERN="$1"
    TEST_FILE="${2:-$(get:python:files:tests)}"
    echo "Running tests matching pattern $PATTERN..."
    poetry run pytest "$TEST_FILE" -k "$PATTERN"
}

# Run a specific test file
function tests:file {
    if [ -z "$1" ]; then
        echo "Usage: test:file <file> [pytest_args...]"
        return 1
    fi
    FILE="$1"
    shift
    echo "Running tests from file $FILE..."
    poetry run pytest "$FILE" "$@"
}

# Generate coverage report
function coverage {
    echo "Generating coverage report..."
    poetry run coverage report
    poetry run coverage html
    echo "HTML coverage report generated in htmlcov/"
}

# Help for pytest options
function help:test {
    echo '====== Pytest Options ======'
    echo ''
    echo 'Usage: tests [test_file] [pytest_args...]'
    echo ''
    echo 'Common pytest options:'
    echo '  -v, --verbose           Show more detailed output'
    echo '  -x, --exitfirst         Stop on first failure'
    echo '  --pdb                   Start the Python debugger on errors'
    echo '  -m MARK                 Only run tests with specific markers'
    echo '  -k EXPRESSION           Only run test files that match expression'
    echo '  --log-cli-level=INFO    Show log messages in the console'
    echo '  --cov=PACKAGE           Measure code coverage for a package'
    echo '  --cov-report=html       Generate HTML coverage report'
    echo ''
    echo 'Examples:'
    echo '  ./run.sh tests tests/ -v'
    echo '  ./run.sh tests:pattern "test_async"'
    echo '  ./run.sh tests:file tests/test_example.py -v'
    echo '  ./run.sh tests:cov tests/unit/ --cov-report=html -v'
    echo ''
    echo 'Specialized test functions:'
    echo '  tests:verbose            Run tests with verbose output'
    echo '  tests:cov                Run tests with coverage report'
    echo '  tests:pattern <pattern>  Run test files matching pattern'
    echo '  tests:file <file>        Run tests in specific file'
}

######################
# CLEANUP
######################

# Clean build artifacts
function clean {
    echo "Cleaning build artifacts..."
    rm -rf dist/ build/ *.egg-info/ .pytest_cache .mypy_cache* .coverage coverage.xml htmlcov/ docs/_build/

    # Clean cache directories safely (avoid virtual environments)
    find . -type d -name "__pycache__" -not -path "*env/*" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -not -path "*env/*" -exec rm {} + 2>/dev/null || true
}

######################
# HELP
######################

# print all functions in this file
function help {
    echo "$0 <task> <args>"
    echo ""
    echo "====== openai-agent-sdk-tutorial Development Tool ======"
    echo ""
    echo "Environment:"
    echo "  install              - Install core dependencies"
    echo "  install:dev          - Install all development dependencies"
    echo "  install:test         - Install test dependencies"
    echo "  install:lint         - Install linting dependencies"
    echo "  install:all          - Install all dependencies"
    echo "  update               - Update dependencies"
    echo "  venv                 - Create and activate virtual environment"
    echo "  lock                 - Lock dependencies"
    echo "  kernel               - Create Jupyter kernel"
    echo "  remove:kernel        - Remove Jupyter kernel"
    echo "  requirements         - Export requirements.txt files"
    echo ""
    echo "Linting & Formatting:"
    echo "  format               - Run all formatters (applies changes)"
    echo "  format:check         - Check formatting without changes (CI)"
    echo "  format:diff          - Run formatters on changed files"
    echo "  format:tests         - Run formatters on test files"
    echo "  lint                 - Run all linters"
    echo "  lint:diff            - Run linters on changed files"
    echo "  lint:tests           - Run linters on test files"
    echo "  check                - Run format + lint + test (applies changes)"
    echo "  check:ci             - Run format check + lint + test (CI)"
    echo "  pre:commit           - Run format and lint on changed files"
    echo ""
    echo "Testing:"
    echo "  tests [file] [args]   - Run tests"
    echo "  tests:cov             - Run tests with coverage"
    echo "  tests:verbose         - Run tests in verbose mode"
    echo "  tests:pattern <pat>   - Run tests matching pattern"
    echo "  tests:file <file>     - Run specific test file"
    echo "  coverage              - Generate coverage report"
    echo "  help:tests            - Show detailed test help"
    echo ""
    echo "Cleanup:"
    echo "  clean                - Clean build artifacts"
    echo ""
    echo "Available functions:"
    compgen -A function | grep -v "^get:" | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time ${@:-help}
