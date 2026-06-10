"""Tests for the two API endpoints.

TestClient drives the FastAPI app in-process: no server is started and no
network is used, so these run fast and identically on a laptop and in CI.
"""

from fastapi.testclient import TestClient

from app.main import app

# One shared client for all tests in this module.
client = TestClient(app)


def test_root_returns_service_metadata():
    # The root endpoint should respond 200 and identify the service.
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "secure-cicd-demo"


def test_health_reports_ok():
    # The health endpoint is what the container HEALTHCHECK relies on,
    # so its exact shape is pinned down here.
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
