# Use the official NGINX image from Docker Hub
FROM nginx:latest

# Remove the default NGINX welcome page (optional but recommended)
RUN rm /usr/share/nginx/html/*

# Copy your local static website files to the container's default HTML folder
COPY ./html /usr/share/nginx/html

# Copy a custom NGINX configuration file if you need custom routing
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

# Inform Docker that the container listens on port 80 at runtime
EXPOSE 80

# Start NGINX in the foreground so the Docker container stays active
CMD ["nginx", "-g", "daemon off;"]
