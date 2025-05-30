# Assistant Agent - Purchase
from pydantic import BaseModel, Field
import os
import logging
from vanilla_aiagents.agent import Agent
from vanilla_aiagents.conversation import LastNMessagesStrategy
from config import llm
from typing import Annotated, Optional
import requests

activation_agent = Agent(  
    id="Activation",
    system_message="""You are a support person that helps customer activate the service they purchased.
    
    You must be accurate and collect all necessary information to activate the service. Required information depends on the service.
    
    - Mobile Internet: Customer's phone number
    - All-in-One Bundle: Customer's phone number and home address
    - Home Internet: Customer's home address
    - Additional Mobile Data: Customer's phone number
    - Replacement SIM Card: Customer's home address and email
    
    IMPORTANT NOTES:
    - In any case, you must confirm the customer's identity before proceeding: ask for their full name and email address.
    - If you need additional internal information, ask other agents for help.
    - Before proceeding, make sure the customer accepts the terms and conditions of the service at https//aka.ms/sample-telco-tc.
    - At the end MUST sure to confirm activation to the user
    
    """,  
    llm=llm,  
    description="""Call this Agent if:
        - You need to activate a service or product Customer purchased
        - You need to activate a procedure that requires customer's personal information
        DO NOT CALL THIS AGENT IF:  
        - You need to fetch answers
        - You need to provide technical support""",  
    reading_strategy=LastNMessagesStrategy(10)
)


class CustomerData(BaseModel):
    full_name: Annotated[Optional[str], Field(description="The customer's full name")] = None
    email: Annotated[Optional[str], Field(description="The customer's email address")] = None
    phone_number: Annotated[Optional[str], Field(description="The customer's phone number")]= None
    address: Annotated[Optional[str], Field(description="The customer's address")] = None


class ServiceActivationData(BaseModel):
    service_sku: Annotated[str, Field(description="The SKU of service to activate")]
    customer: Annotated[CustomerData, Field(description="The customer information with full_name, email, phone_number, and address")]
    tc_accepted: Annotated[bool, Field(description="Whether the terms and conditions are accepted")]


LOGIC_APPS_URL = os.getenv("LOGIC_APPS_URL")
@activation_agent.register_tool(description="Queue service activation")
def queue_service_activation(
    payload: Annotated[ServiceActivationData, "The data required to activate the service"]
    ) -> str:
    logging.info(f"queue_service_activation{payload.model_dump_json(indent=2)}")
    
    try:
        requests.post(f"{LOGIC_APPS_URL}", json=payload.model_dump())
        return "OK"
    except Exception as e:
        return f"ERROR Failed to queue activation: {e}"