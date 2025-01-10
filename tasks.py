from invoke import task

@task
def start_chat(c):
    c.run("cd ui && python -m chainlit run -w chat.py")

@task
def start_api(c, port=3000):
    c.run(f"cd api && python -m uvicorn api:app --reload --host 0.0.0.0 --port {port}")

@task
def start_host(c, port=7000):
    c.run(f"cd telco-team && python -m vanilla_aiagents.remote.run_host --source-dir . --host 0.0.0.0 --port {port}")
