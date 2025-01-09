from azure.cosmos import CosmosClient, PartitionKey, exceptions

class ConfigurationStore:
    def __init__(self, url, key, database_name, container_name):
        self.client = CosmosClient(url, credential=key)
        self.database_name = database_name
        self.container_name = container_name
        self.db = self.client.get_database_client(database=self.database_name)
        self.container = self.db.get_container_client(container=self.container_name)
        
    def get_service_status(self, service_sku):
        try:
            item = self.container.read_item(item=service_sku, partition_key="service")
            return item.get("status") or None
        except exceptions.CosmosResourceNotFoundError:
            return None
        
    def get_customer_status(self, service_sku, customer_code):
        try:
            item = self.container.read_item(item=customer_code, partition_key="customer")
            return item.get("services")[service_sku] or None if item is not None else "No data available"
        except exceptions.CosmosResourceNotFoundError:
            return None
