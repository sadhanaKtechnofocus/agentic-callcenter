import os
from vanilla_aiagents.llm import AzureOpenAILLM

llm = AzureOpenAILLM({
    "azure_deployment": os.getenv("AZURE_OPENAI_MODEL"),
    "azure_endpoint": os.getenv("AZURE_OPENAI_ENDPOINT"),
    "api_key": os.getenv("AZURE_OPENAI_KEY"),
    "api_version": os.getenv("AZURE_OPENAI_API_VERSION"),
})
