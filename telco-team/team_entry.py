from typing import Dict, List, Tuple
from vanilla_aiagents.team import Team
from user_proxy_agent import user_proxy_agent
from sales_agent import sales_agent
from activation_agent import activation_agent
from planner_agent import planner_agent
from support_agent import technical_support_agent
from config import llm

system_message_manager="""
    You are the overall manager of the group chat. 
    You can see all the messages and intervene if necessary. 
    You can also send system messages to the group chat. 
    
    If you need human or user input, you can ask Customer for more information.
    NEVER call Customer immediately after Executor
    """
team = Team(
    id="telco-team",
    description="A group chat with multiple agents",
    members=[user_proxy_agent, planner_agent, sales_agent, activation_agent, technical_support_agent],
    llm=llm, 
    stop_callback=lambda msgs: "terminate" in msgs[-1].get("content", "").lower(),
)
