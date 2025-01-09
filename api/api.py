from fastapi import FastAPI
from dotenv import load_dotenv
import logging

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.gzip import GZipMiddleware
from starlette_gzip_request import GZipRequestMiddleware
from utils.log_utils import setup_logger

load_dotenv(override=True)
logging.basicConfig(level=logging.INFO)
logging.getLogger("azure").setLevel(logging.WARNING)
setup_logger()

app = FastAPI()
# Enable GZip compression for response
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(GZipRequestMiddleware)

# FastAPI global configuration
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    logging.error(f"Unprocessable request: {request} {exc}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )

from routers.conversation import conversation_router
app.include_router(conversation_router)

from routers.integration import integration_router
app.include_router(integration_router)