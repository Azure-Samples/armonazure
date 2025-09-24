# Use the official ARM64 Cassandra image as the base
FROM arm64v8/cassandra:latest

# Add metadata information
LABEL maintainer="bbenz@microsoft.com"
LABEL description="Custom Cassandra image for local ARM64 development"
LABEL version="1.0"

# Set environment variables for Cassandra configuration
ENV MAX_HEAP_SIZE="1G"
ENV HEAP_NEWSIZE="256M"
ENV CASSANDRA_CLUSTER_NAME="LocalDevCluster"
ENV CASSANDRA_DC="DC1-Local"
ENV CASSANDRA_RACK="Rack1"

# Create and set permissions for Cassandra directories
RUN mkdir -p /var/lib/cassandra/data \
    && mkdir -p /var/lib/cassandra/commitlog \
    && mkdir -p /var/lib/cassandra/saved_caches \
    && chown -R cassandra:cassandra /var/lib/cassandra

# Create a simple initialization script
RUN echo '#!/bin/bash \n\
echo "Starting Cassandra for local ARM64 development" \n\
exec /docker-entrypoint.sh "$@"' > /custom-entrypoint.sh \
    && chmod +x /custom-entrypoint.sh

# Expose standard Cassandra ports
# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL native transport port
# 9160: Thrift client API
EXPOSE 7000 7001 7199 9042 9160

# Use our custom entrypoint script
ENTRYPOINT ["/custom-entrypoint.sh"]

# Default command (will be executed after entrypoint)
CMD ["cassandra", "-f"]