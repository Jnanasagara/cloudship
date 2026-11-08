# Start with official Python 3.11 on a minimal Debian Bookworm image.
FROM python:3.11-slim-bookworm

# Avoid creating Python bytecode cache files inside the container.
ENV PYTHONDONTWRITEBYTECODE=1

# Send Python output immediately so container logs appear promptly.
ENV PYTHONUNBUFFERED=1

# Use /app as the working directory for subsequent instructions.
WORKDIR /app

# Copy the runtime lock before application code so dependency installation can be cached.
COPY requirements.txt ./

# Install hash-verified runtime dependencies and check their compatibility.
RUN python -m pip install --no-cache-dir --require-hashes -r requirements.txt && python -m pip check

# Create a dedicated Linux user and group for running CloudShip.
RUN groupadd --gid 10001 cloudship && useradd --uid 10001 --gid cloudship --no-create-home --shell /usr/sbin/nologin cloudship

# Copy the application package into /app/app.
COPY app/ ./app/

# Run subsequent instructions and the application as this non-root user.
USER 10001:10001

# Default to port 8000 and normal healthy behavior; runtime settings can override these.
ENV UVICORN_PORT=8000 \
    ALLOW_FAILURE_DEMO=false \
    SIMULATE_UNHEALTHY=false

# Document the default application port; this does not publish it on the host.
EXPOSE 8000

# Start the application factory, listening on all container network interfaces.
CMD ["python", "-m", "uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0"]