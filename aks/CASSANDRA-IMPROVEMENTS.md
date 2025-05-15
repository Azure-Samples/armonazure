# Improved Cassandra Deployment for ARM64 on AKS

This directory contains improved Kubernetes deployment files for running Cassandra on Azure Kubernetes Service (AKS) with ARM64 nodes. These files incorporate best practices for running Cassandra on ARM64 architecture.

## Key Improvements

### 1. Using StatefulSet Instead of Deployment

The improved deployment uses a `StatefulSet` rather than a regular `Deployment`, which provides:
- Stable, unique network identifiers
- Stable, persistent storage
- Ordered, graceful deployment and scaling
- Ordered, graceful deletion and termination

### 2. Persistent Storage

- Added persistent volume claims for data durability
- Uses Azure Premium Storage for better performance
- Properly sized for Cassandra workloads (20GB per pod, adjustable)

### 3. Resource Optimization for ARM64

- CPU and memory requests and limits optimized for ARM64
- JVM settings configured for ARM64 architecture
- Read-ahead optimization (8KB as recommended for Cassandra)

### 4. Health Checks and Lifecycle Management

- Proper liveness and readiness probes
- Graceful shutdown with `nodetool drain`
- Adequate termination grace period (1800s)

### 5. Security Enhancements

- Runs as non-root user (cassandra:999)
- Proper security context settings
- Node affinity to ensure deployment on ARM64 nodes

### 6. Network Configuration

- Headless service for peer discovery
- All necessary ports exposed
- Clear port naming for easier management

## Recommended ARM64 Images

### Primary Recommendation: DataStax Cassandra ARM64

```yaml
image: datastax/cassandra-arm64:4.1.3
```

**Benefits:**
- Official DataStax distribution optimized for ARM64
- Better performance and stability on Azure ARM64 VMs
- Includes production-ready tools and utilities
- Regular security updates

### Alternative Options:

1. **Bitnami Cassandra (ARM64 support)**
   ```yaml
   image: bitnami/cassandra:4.1.1-debian-11-r22
   ```
   - Production-ready Cassandra with good ARM64 support
   - Simplified configuration
   - Well-maintained with security patches

2. **Official ARM64v8 Cassandra**
   ```yaml
   image: arm64v8/cassandra:4.1
   ```
   - Pure ARM64 build of Apache Cassandra
   - Lightweight container optimized for ARM architecture
   - Direct from the official arm64v8 repository

## Other Interesting ARM64 Demos for Azure

Consider these alternative demos for showcasing ARM64 capabilities on Azure:

1. **Java Spring Boot Application**
   ```yaml
   image: eclipse-temurin:17-jre-jammy
   ```
   - Demonstrates Java performance on ARM64
   - Low memory footprint
   - Excellent price-performance ratio

2. **NGINX with ARM64 Optimizations**
   ```yaml
   image: arm64v8/nginx:1.25
   ```
   - Shows web server performance on ARM64
   - Optimized for network throughput
   - Great for demonstrating high-concurrency workloads

3. **PostgreSQL on ARM64**
   ```yaml
   image: arm64v8/postgres:15
   ```
   - Database performance comparison
   - Alternative to Cassandra for relational workloads
   - Good for benchmarking IOPS on ARM64

4. **Redis on ARM64**
   ```yaml
   image: arm64v8/redis:7.0
   ```
   - In-memory data store optimized for ARM64
   - Excellent for demonstrating memory bandwidth advantages
   - Low-latency workload showcase

## Usage Instructions

1. Apply the ConfigMap:
   ```bash
   kubectl apply -f cassandra-config.yaml
   ```

2. Deploy the Cassandra StatefulSet:
   ```bash
   kubectl apply -f improved-cassandra-statefulset.yaml
   ```

3. Create the Cassandra Service:
   ```bash
   kubectl apply -f improved-cassandra-service.yaml
   ```

4. Monitor the Cassandra deployment:
   ```bash
   kubectl get pods -l app=cassandra
   ```

5. Once all pods are running, verify the cluster status:
   ```bash
   kubectl exec -it cassandra-0 -- nodetool status
   ```
