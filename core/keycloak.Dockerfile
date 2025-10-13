FROM quay.io/keycloak/keycloak:26.3

# Copy custom providers into the image to avoid host bind mounts
COPY keycloak-providers/*.jar /opt/keycloak/providers/
