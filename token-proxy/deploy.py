import logging
from truefoundry.deploy import (
    NodeSelector,
    Build,
    PythonBuild,
    Service,
    Port,
    Resources,
    Pip,
    LocalSource,
)

logging.basicConfig(level=logging.INFO)

service = Service(
    name="token-router-proxy",
    image=Build(
        build_source=LocalSource(),
        build_spec=PythonBuild(
            python_version="3.11",
            build_context_path="./",
            requirements_path="",
            python_dependencies=Pip(
                requirements_path="requirements.txt",
                pip_packages=["fastapi", "uvicorn", "httpx", "tiktoken"],
            ),
            command="uvicorn main:app --host 0.0.0.0 --port 8000",
        ),
    ),
    resources=Resources(
        cpu_request=0.2,
        cpu_limit=1.0,
        memory_request=256,
        memory_limit=512,
        ephemeral_storage_request=500,
        ephemeral_storage_limit=500,
        node=NodeSelector(capacity_type="on_demand"),
    ),
    env={
        "GATEWAY_URL": "tfy-secret://slayzsloth:atlas-secret:GATEWAY_URL",
        "GATEWAY_API_KEY": "tfy-secret://slayzsloth:atlas-secret:GATEWAY_API_KEY",
        "SMALL_THRESHOLD": "4096",
        "SMALL_MODEL": "openai/gpt-4o",
        "LARGE_MODEL": "anthropic/claude-opus-4-5",
    },
    ports=[
        Port(
            port=8000,
            protocol="TCP",
            expose=True,
            app_protocol="http",
            host="13.202.247.205.nip.io",
            path="/token-router-proxy-atlas-8000/",
        )
    ],
    replicas=1.0,
)


service.deploy(workspace_fqn="atlas-cluster:atlas", wait=False)
