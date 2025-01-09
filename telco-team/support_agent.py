from vanilla_aiagents.agent import Agent
from vanilla_aiagents.conversation import LastNMessagesStrategy
from config import llm
from typing import Annotated
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from azure.identity import DefaultAzureCredential
from azure.core.credentials import AzureKeyCredential
import os

key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
credential = DefaultAzureCredential() if key is None or key == "" else AzureKeyCredential(key)
search_client = SearchClient(
    endpoint=os.getenv("AZURE_SEARCH_ENDPOINT"),
    index_name=os.getenv("AZURE_SEARCH_INDEX"),
    credential=credential
)

technical_support_agent = Agent(  
    id="TechnicalSupport",
    system_message="""You are a technical support agent that responds to customer inquiries.
    
    Your task are:
    - Query first the knowledge base to gather possible solutions. DO NOT provide any solution outside of the knowledge base.
    - Verify if there any known issues with the service the customer is using.
    - Check remote telemetry data to identify potential issues with customer's device. Be sure to ask customer code first.
    - Provide the customer with possible solutions to the issue
        - When the service status is OK, reply the customer and suggest to restart the device.
        - When the service status is DEGRADED, apologize to the customer and kindly ask them to wait for the issue to be resolved.
        - Open an internal ticket if the issue cannot be resolved immediately.
    
    Make sure to act politely and professionally.
    """,  
    llm=llm,  
    description="""Call this Agent if:
        - You need to solve technical issues.
        - You need to check the service status.
        - You need to check the customer's telemetry data.
        - Customer is facing issues with the service.

        DO NOT CALL THIS AGENT IF: 
        - You need to respond to commercial inquiries.
        - You need to activate a service the customer purchased.
        - You need to end the conversation with the customer.
        """,
    reading_strategy=LastNMessagesStrategy(10)
)

from configuration_store import ConfigurationStore
from azure.identity import DefaultAzureCredential
configuration_store = ConfigurationStore(
    url=os.getenv("COSMOSDB_ENDPOINT"),
    key=DefaultAzureCredential(),
    database_name=os.getenv("COSMOSDB_DATABASE"),
    container_name="configuration"
)

@technical_support_agent.register_tool(description="Get the service status, values can be INET_MOBILE, INET_BUNDLE, INET_HOME")
def get_service_status(
    service_sku: Annotated[str, "The SKU of the service to check status for"]
    ) -> Annotated[str, "Status of the specified service"]:
    
    # Assert that the service SKU is valid
    assert service_sku in ["INET_MOBILE", "INET_BUNDLE", "INET_HOME"], f"Invalid service SKU: {service_sku}"
    
    return configuration_store.get_service_status(service_sku) or "No issues detected"

@technical_support_agent.register_tool(description="Get the customer telemetry")
def check_customer_telemetry(
    service_sku: Annotated[str, "The SKU of the service to check status for, values can be INET_MOBILE, INET_BUNDLE, INET_HOME"],
    customerCode: Annotated[str, "The customer code to check telemetry for"]
    ) -> Annotated[str, "Telemetry summary for the specified customer"]:
    
    # Assert that the service SKU is valid
    assert service_sku in ["INET_MOBILE", "INET_BUNDLE", "INET_HOME"], f"Invalid service SKU: {service_sku}"
        
    return configuration_store.get_customer_status(service_sku, customerCode) or "No issues detected"
    
import requests
import logging
@technical_support_agent.register_tool(description="File an internal ticket")
def open_internal_ticket(
    service_sku: Annotated[str, "The SKU of the service the customer is using"],
    customerCode: Annotated[str, "The customer code"],
    issue: Annotated[str, "The description of the issue"]
    ) -> Annotated[str, "Status of the creation of the internal ticket"]:
    
    url = os.getenv("OPENTICKET_LOGIC_APPS_URL")
    logging.info(f"open_internal_ticket: {service_sku}, {customerCode}, {issue}")
    
    try:
        response = requests.post(url, json={
            "service_sku": service_sku,
            "customerCode": customerCode,
            "issue": issue
        })
        response.raise_for_status()
        return "OK"
    except requests.exceptions.RequestException as e:
        logging.error(f"Error occurred while filing internal ticket: {e}")
        return f"Error: Failed to file internal ticket {e}"

@technical_support_agent.register_tool(description="Query the knowledge base")
def query_knowledge_base(query: Annotated[str, "The query to search in the knowledge base"]) -> Annotated[str, "Relevant documentation from the knowledge base"]:
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=1, fields="text_vector", exhaustive=True)
    search_results = search_client.search(
        search_text=query,  
        vector_queries= [vector_query],
        select=["title", "chunk_id", "chunk"],
        top=5
    )
    
    # Chunk id has format {parent_id}_pages_{page_number}
    
    sources_formatted = "\n".join([f'# Source "{document["title"]}" - Page {document["chunk_id"].split("_")[-1]}\n{document["chunk"]}' for document in search_results])
    
    return sources_formatted