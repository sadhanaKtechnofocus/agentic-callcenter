import os
import logging
import json
import subprocess
from azure.identity import AzureDeveloperCliCredential
from azure.cosmos import CosmosClient
from dotenv import load_dotenv
from rich.logging import RichHandler


logging.basicConfig(level=logging.WARNING, format="%(message)s", datefmt="[%X]", handlers=[RichHandler(rich_tracebacks=True)])
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def load_azd_env():
    """Get path to current azd env file and load file using python-dotenv"""
    result = subprocess.run("azd env list -o json", shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        raise Exception("Error loading azd env")
    env_json = json.loads(result.stdout)
    env_file_path = None
    for entry in env_json:
        if entry["IsDefault"]:
            env_file_path = entry["DotEnvPath"]
    if not env_file_path:
        raise Exception("No default azd env file found")
    logger.info(f"Loading azd env from {env_file_path}")
    load_dotenv(env_file_path, override=True)


def main():

    load_azd_env()

    credential = AzureDeveloperCliCredential(tenant_id=os.environ["AZURE_TENANT_ID"], process_timeout=60)

    cosmos_uri = os.environ["COSMOSDB_ENDPOINT"]
    cosmos_db_name = os.environ["COSMOSDB_DATABASE"]
    cosmos_container_name = os.environ["COSMOSDB_CONFIG_CONTAINER"]

    client = CosmosClient(cosmos_uri, credential=credential)
    database = client.get_database_client(cosmos_db_name)
    container = database.get_container_client(cosmos_container_name)

    # Seed with sample data
    logger.info("Seeding CosmosDB with sample data")
    seed_data = [
        {
            "id": "INET_MOBILE",
            "partition_key": "service",
            "status": "No issues"
        },
        {
            "id": "INET_HOME",
            "partition_key": "service",
            "status": "DEGRADED"
        },
        {
            "id": "INET_BUNDLE",
            "partition_key": "service",
            "status": "No issues"
        },
        {
            "id": "1234",
            "partition_key": "customer",
            "services": {
                "INET_MOBILE": "Monthly data limit exceeded",
                "INET_BUNDLE": "No issues detected",
                "INET_HOME": "Router offline"
            }
        },
    ]
    
    for item in seed_data:
        container.upsert_item(item)


if __name__ == "__main__":
    main()
