@azure_development-get_code_gen_best_practices

# ARM64 Cassandra Docker Image for Local Development

This README provides instructions for building and running the custom Cassandra Docker image for ARM64 processors. This image is optimized for local development on ARM-based machines like Apple Silicon Macs or other ARM64 development environments.

## Building the Image

Build the custom Cassandra image using the following command:

```bash
docker build -t cassandra-arm64-local:1.0 -f cassandra-arm64-local.dockerfile .
```

## Running the Container

### Basic Usage

Run the container with default settings:

```bash
docker run -d --name cassandra-local -p 9042:9042 cassandra-arm64-local:1.0
```

### Recommended Setup with Persistent Storage

For development with persistent data storage:

```bash
# Create a volume for Cassandra data
docker volume create cassandra-data

# Run with volume mounted and all ports exposed
docker run -d --name cassandra-local \
  -p 9042:9042 \
  -p 7000:7000 \
  -p 7001:7001 \
  -p 7199:7199 \
  -v cassandra-data:/var/lib/cassandra \
  --restart unless-stopped \
  cassandra-arm64-local:1.0
```

## Connecting to Cassandra

### Using CQL Shell

```bash
docker exec -it cassandra-local cqlsh
```

### Check Cluster Status

```bash
docker exec -it cassandra-local nodetool status
```

### Connect from Applications

Connect to your Cassandra instance using:
- Host: `localhost`
- Port: `9042`
- Datacenter: `DC1-Local`

## Configuration

This image comes pre-configured with these settings:

- **MAX_HEAP_SIZE**: 1G
- **HEAP_NEWSIZE**: 256M
- **CLUSTER_NAME**: LocalDevCluster
- **DATACENTER**: DC1-Local
- **RACK**: Rack1

### Customizing Settings

Override any configuration using environment variables:

```bash
docker run -d --name cassandra-local \
  -p 9042:9042 \
  -e MAX_HEAP_SIZE=2G \
  -e CASSANDRA_CLUSTER_NAME=MyCustomCluster \
  cassandra-arm64-local:1.0
```

## Stopping and Removing

```bash
# Stop the container
docker stop cassandra-local

# Remove the container (data is preserved in volume)
docker rm cassandra-local

# Remove the image
docker rmi cassandra-arm64-local:1.0

# Remove the volume (will delete all data)
docker volume rm cassandra-data
```

## Integration with Azure

To use this image with Azure:

1. Build the image locally
2. Tag for Azure Container Registry:
   ```bash
   docker tag cassandra-arm64-local:1.0 myacr.azurecr.io/cassandra-arm64:1.0
   ```
3. Push to Azure Container Registry:
   ```bash
   az acr login --name myacr
   docker push myacr.azurecr.io/cassandra-arm64:1.0
   ```
4. Deploy to Azure Kubernetes Service (AKS) with ARM64 nodes:
   ```bash
   kubectl apply -f cassandra-deployment.yaml
   ```

## Troubleshooting

- **Container fails to start**: Check logs with `docker logs cassandra-local`
- **Memory issues**: Adjust MAX_HEAP_SIZE for your machine's capabilities
- **Connection refused**: Ensure ports are properly mapped

## Resources

- [Official Cassandra Documentation](https://cassandra.apache.org/doc/latest/)
- [ARM64v8 Cassandra on Docker Hub](https://hub.docker.com/r/arm64v8/cassandra/)
- [Azure ARM64 Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/arm-series)