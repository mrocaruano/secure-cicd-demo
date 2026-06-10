# =============================================================================
# Container image for the FastAPI service.
#
# This is a multi-stage build. The first stage ("builder") installs the
# Python dependencies. The second stage copies only the installed packages
# and the application code, so the final image contains no pip cache, no
# build leftovers, and nothing that is not needed at runtime. A smaller
# image is a smaller attack surface.
#
# The base image is pinned by digest, not by tag. A tag like "3.13-slim" is
# a moving pointer that the publisher can repoint at any time; a sha256
# digest names one exact immutable image. Dependabot (docker ecosystem)
# opens a pull request whenever a newer digest exists, so the pin stays
# fresh without ever being mutable.
# =============================================================================

# ---- Stage 1: builder. Installs dependencies into an isolated prefix. ----
FROM python:3.13-slim@sha256:4d96149461c3d03a5c8b2774494768e25142904fa1a6c210310675454b38b40f AS builder

# All work in this stage happens in /build.
WORKDIR /build

# Copy only the requirements file first. Docker caches each instruction, so
# as long as requirements.txt does not change, the slow dependency install
# below is reused from cache on every rebuild.
COPY requirements.txt .

# Install the pinned dependencies into /install instead of the system
# location. That prefix is copied wholesale into the final image below.
# --no-cache-dir keeps pip's download cache out of the layer.
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: the final runtime image. Starts clean from the same base. ----
FROM python:3.13-slim@sha256:4d96149461c3d03a5c8b2774494768e25142904fa1a6c210310675454b38b40f

# Create a dedicated unprivileged account to run the service. If the app is
# ever compromised through a request, the attacker lands in a process that
# cannot install packages, write outside the app directory, or touch root
# owned files. --system creates it without a login shell or home directory.
RUN groupadd --system app && useradd --system --gid app --no-create-home app

# The application lives in /app.
WORKDIR /app

# Bring in the installed Python packages from the builder stage.
# /usr/local is where the python image looks for installed packages.
COPY --from=builder /install /usr/local

# Copy the application source. Only app/ is copied: no tests, no git
# history, no workflow files (also see .dockerignore).
COPY app/ ./app/

# Every instruction after this line, and the running container itself,
# executes as the unprivileged user instead of root.
USER app

# Document the port the service listens on.
EXPOSE 8000

# Tell the container runtime how to check that the service is actually
# serving requests: call the /health endpoint every 30 seconds. The check
# uses Python's standard library so no extra tools (like curl) need to be
# installed into the image.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# The process the container runs: the uvicorn ASGI server hosting the app.
# 0.0.0.0 makes it listen on the container's network interface so mapped
# ports work from outside the container.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
