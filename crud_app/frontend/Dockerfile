FROM nginx:stable-alpine

# Install envsubst (gettext) for runtime env templating
RUN apk add --no-cache gettext

# Create app directory
WORKDIR /usr/share/nginx/html

# Copy static frontend files
COPY . /usr/share/nginx/html/

# Add entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
