FROM quay.io/keycloak/keycloak:26.3

# Enable health and metrics endpoints
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Copy custom providers into the image to avoid host bind mounts
COPY keycloak-providers/*.jar /opt/keycloak/providers/

# Copy secrets2env helper script with execute permissions
COPY --chmod=755 secrets2env.sh /usr/local/bin/secrets2env.sh
