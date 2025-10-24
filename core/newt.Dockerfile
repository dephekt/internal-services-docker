FROM fosrl/newt:1.5.2

# Copy secrets2env helper script with execute permissions
COPY --chmod=755 secrets2env.sh /usr/local/bin/secrets2env.sh

