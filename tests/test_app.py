import pytest
from fastapi.testclient import TestClient
from app.main import create_app

def test_root_returns_service_message():
    with TestClient(create_app()) as client:
        response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {
        "service": "cloudship",
        "message": "CloudShip running",
    }

def test_health_reports_healthy():
    with TestClient(create_app()) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

def test_version_reports_configured_release(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "test-abc123")

    with TestClient(create_app()) as client:
        response = client.get("/version")

    assert response.status_code == 200
    assert response.json() == {
        "service": "cloudship",
        "version": "test-abc123",
    }

def test_version_defaults_to_local_dev(monkeypatch):
    monkeypatch.delenv("APP_VERSION", raising=False)

    with TestClient(create_app()) as client:
        response = client.get("/version")
    
    assert response.status_code == 200
    assert response.json() == {
        "service": "cloudship",
        "version": "local-dev",
    }

def test_unhealthy_simulation_requires_permission(monkeypatch):
    monkeypatch.setenv("SIMULATE_UNHEALTHY", "true")
    monkeypatch.delenv("ALLOW_FAILURE_DEMO", raising=False)

    with pytest.raises(
        ValueError,
        match="SIMULATE_UNHEALTHY requires ALLOW_FAILURE_DEMO=true",
    ):
        create_app()

def test_health_reports_unhealthy_when_demo_enabled(monkeypatch):
    monkeypatch.setenv("ALLOW_FAILURE_DEMO", "true")
    monkeypatch.setenv("SIMULATE_UNHEALTHY", "true")

    with TestClient(create_app()) as client:
        response = client.get("/health")

    assert response.status_code == 503
    assert response.json() == {"status": "unhealthy"}

def test_demo_permission_alone_keeps_app_healthy(monkeypatch):
    monkeypatch.setenv("ALLOW_FAILURE_DEMO", "true")
    monkeypatch.delenv("SIMULATE_UNHEALTHY", raising=False)

    with TestClient(create_app()) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_explicitly_disabled_demo_keeps_app_healthy(monkeypatch):
    monkeypatch.setenv("ALLOW_FAILURE_DEMO", "false")
    monkeypatch.setenv("SIMULATE_UNHEALTHY", "false")

    with TestClient(create_app()) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}