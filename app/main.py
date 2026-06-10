"""A deliberately small FastAPI service.

The application is the cargo, not the point. This repository exists to
demonstrate the CI/CD pipeline that tests, scans, builds, signs, and
ships it.
"""

from fastapi import FastAPI

# The application object. FastAPI routes requests to the functions
# registered below and also serves interactive API docs at /docs.
app = FastAPI(title="secure-cicd-demo", version="1.0.0")


@app.get("/")
def root() -> dict[str, str]:
    """Return basic service metadata as JSON."""
    return {
        "service": "secure-cicd-demo",
        "message": "Hello from a pipeline-hardened container.",
    }


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe.

    The HEALTHCHECK instruction in the Dockerfile calls this endpoint to
    decide whether the container is healthy, and an orchestrator (or a
    human with curl) can do the same.
    """
    return {"status": "ok"}
