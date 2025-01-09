import base64
import json
import os
from typing import Optional
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import logging
from azure.identity import DefaultAzureCredential

from vanilla_aiagents.remote.remote import RemoteAskable, RESTConnection
from vanilla_aiagents.workflow import Workflow, WorkflowInput
from vanilla_aiagents.conversation import Conversation
from conversation_store import ConversationStore
from utils.voice_utils import whisper_client

conversation_router = APIRouter(prefix="/conversation")


# Model for a message
class Message(BaseModel):
    conversation_id: str
    id: str
    name: str
    role: str
    content: str


# A helper class that store and retrieve messages by conversation from an Azure Cosmos DB
key = DefaultAzureCredential()
db = ConversationStore(
    url=os.getenv("COSMOSDB_ENDPOINT"),
    key=key,
    database_name=os.getenv("COSMOSDB_DATABASE"),
    container_name=os.getenv("COSMOSDB_CONTAINER")
)


# Get all messages by conversation
@conversation_router.get("/{conversation_id}")
def get_messages(conversation_id: str):
    """Get all messages for a conversation."""
    conv = db.get_conversation(conversation_id) or []
    return conv.get("messages", [])


class MediaRequest(BaseModel):
    mimeType: str
    data: str


class MessageRequest(BaseModel):
    message: str
    media: Optional[list[MediaRequest]] = None


remote_connection = RESTConnection(url=os.getenv("TEAM_REMOTE_URL"))
# remote_connection = GRPCConnection(url=os.getenv("TEAM_REMOTE_URL"))
remote = RemoteAskable(id="telco-team", connection=remote_connection)


@conversation_router.post("/{conversation_id}")
def send_message(conversation_id: str, request: MessageRequest):
    """Send a message to an existing conversation."""
    
    # start_trace(collection=f"chat-{conversation_id}")
    
    conversation = Conversation(messages=[], variables={})
    history = db.get_conversation(conversation_id)
    if history is not None:
        conversation.messages = history["messages"]
        conversation.variables = history["variables"]
    message = _preprocess_request(request)
    
    history_count = len(conversation.messages)
        
    workflow = Workflow(askable=remote, conversation=conversation)
    
    result = workflow.run(message)
    
    if "error" in result:
        raise Exception("Error in workflow")
    
    db.save_conversation(conversation_id, workflow.conversation)
    
    # delta = len(workflow.conversation.messages) - history_count
    
    new_messages = workflow.conversation.messages[history_count:]
    
    return new_messages

@conversation_router.post("/{conversation_id}/stream")
def send_message_stream(conversation_id: str, request: MessageRequest):
    
    conversation = Conversation(messages=[], variables={})
    history = db.get_conversation(conversation_id)
    if history is not None:
        conversation.messages = history["messages"]
        conversation.variables = history["variables"]
    message = _preprocess_request(request)
    
    logging.info(f"Starting conversation {conversation_id}")
        
    workflow = Workflow(askable=remote, conversation=conversation)
    
    def _stream():
        for mark, content in workflow.run_stream(message):
            json_string = json.dumps([mark, content])
            logging.info(json_string)                   
            yield json_string + "\n" # NEW LINE DELIMITED JSON
            
        # Clean converation messages and keep only content, name and role fields
        conversation.messages = [{"content": m["content"], "name": m["name"] if "name" in m else None, "role": m["role"]} for m in conversation.messages]
        db.save_conversation(conversation_id, workflow.conversation)
    
    return StreamingResponse(_stream(), media_type="text/event-stream")

def _preprocess_request(input_message: MessageRequest):
    if input_message.media is None:
        return input_message.message
    else:
        new_input = WorkflowInput(input_message.message)
        for m in input_message.media:
            if "audio" in m.mimeType:
                transcription = whisper_client.audio.transcriptions.create(
                    model="whisper",
                    file=input_message.media.data
                )
                new_input.text = transcription.text
            elif "image" in m.mimeType:
                m.data
                image_bytes = base64.b64decode(m.data)
                new_input.add_image_bytes(image_bytes)
        
        return new_input