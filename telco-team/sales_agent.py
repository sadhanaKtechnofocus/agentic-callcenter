# Assistant Agent - Commercial  

from vanilla_aiagents.agent import Agent
from vanilla_aiagents.conversation import LastNMessagesStrategy
from config import llm
from typing import List, Annotated

sales_agent = Agent(  
    id="SalesPerson",
    system_message="""You are a sales person that responds to customer inquiries.
    
    You have access to pricing and product details in the PRODUCTS sections below. Please note field starting with "_" are not to be shared with the Customer.
    
    Your tasks are:
    - provide the Customer with the information they need. Try to be specific and provide the customer only options that fit their needs.
    
    IMPORTANT NOTES:
    - DO act politely and professionally
    - NEVER provide false information
    
    ### PRODUCTS
    - Mobile Internet
        - Description: Mobile WiFi for you to take anywhere, supports up to 10 devices.
        - Price: €10/month
        - Details: 10GB data included, €1/GB after that.
        - _SKU: INET_MOBILE
    - All-in-One Bundle
        - Description: Mobile internet and home internet in one package.
        - Price: €45/month
        - Details: 10GB mobile data, €1/GB after that. Home internet included.
        - _SKU: INET_BUNDLE
    - Home Internet
        - Description: High-speed internet for your home.
        - Price: €30/month
        - Details: Unlimited data at 1Gbps.
        - _SKU: INET_HOME
    - Additional Mobile Data
        - Description: Additional data for your mobile internet.
        - Price: €3 per 5GB
        - Details: Purchase additional data for your mobile internet.
        - _SKU: INET_MOBILE_DATA_ADD
    """,  
    llm=llm,
    description="""Call this Agent if:   
        - You need to provide commercial information, like pricing or product details to the customer.             
        - You need to get the product SKU.
        DO NOT CALL THIS AGENT IF:  
        - You need to support the Customer with technical issues.""",
    reading_strategy=LastNMessagesStrategy(10)
)  


mobileInternet = """ - Mobile Internet
        - Description: Mobile WiFi for you to take anywhere, supports up to 10 devices.
        - Price: €10/month
        - Details: 10GB data included, €1/GB after that.
        - _SKU: INET_MOBILE
"""
allInOneBundle = """
    - All-in-One Bundle
        - Description: Mobile internet and home internet in one package.
        - Price: €45/month
        - Details: 10GB mobile data, €1/GB after that. Home internet included.
        - _SKU: INET_BUNDLE
"""
homeInternet = """
    - Home Internet
        - Description: High-speed internet for your home.
        - Price: €30/month
        - Details: Unlimited data at 1Gbps.
        - _SKU: INET_HOME
"""
additionalMobileData = """
    - Additional Mobile Data
        - Description: Additional data for your mobile internet.
        - Price: €3 per 5GB
        - Details: Purchase additional data for your mobile internet.
        - _SKU: INET_MOBILE_DATA_ADD
"""

# @executor_agent.register_for_execution()
# @sales_agent.register_for_llm(description="Get available services")
def get_available_services() -> Annotated[List[str], "List of available services with details"]:
    return [mobileInternet, allInOneBundle, homeInternet, additionalMobileData]