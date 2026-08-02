# Use Python 3.12 slim image for smaller size
FROM python:3.12-slim

# Note: .dockerignore is symlinked to .gitignore for unified exclusion rules

# Set working directory
WORKDIR /app

# Install uv for faster dependency management
# https://github.com/astral-sh/uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_SYSTEM_PYTHON=1

# Copy dependency files and README first for better layer caching
COPY pyproject.toml README.md ./

# Copy the application source code (needed for editable install)
COPY src/ ./src/

# Install dependencies using uv
RUN uv pip install -e .

# Verify the installed MCP SDK still provides the module this project imports.
# mcp 2.x removed mcp.server.fastmcp, so an unpinned resolve silently produces
# an image that crash-loops at startup. Fail the build here instead, and print
# the resolved version so it's visible in the build logs.
RUN python -c "import importlib.metadata as m; print('Installed mcp version:', m.version('mcp'))" && \
    python -c "from mcp.server.fastmcp import FastMCP; print('mcp.server.fastmcp import OK')"

# Copy test files (optional, for testing in container)
COPY tests/ ./tests/
COPY pytest.ini ./

# Create directory for Garmin tokens
RUN mkdir -p /root/.garminconnect && \
    chmod 700 /root/.garminconnect

# Expose the HTTP port. The image defaults to stdio (Claude Desktop, Inspector);
# set GARMIN_MCP_TRANSPORT=streamable-http to serve over this port (e.g. in k8s).
# EXPOSE 8000

# Set the entrypoint to run the MCP server
ENTRYPOINT ["garmin-mcp"]

# Health check (optional - adjust based on your needs)
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#   CMD python -c "import sys; sys.exit(0)"
