#==== BUILD ====#

FROM node:12.22.12-alpine AS builder


# set working directory
RUN mkdir /app
WORKDIR /app

# add `/usr/src/app/node_modules/.bin` to $PATH
ENV PATH=/app/node_modules/.bin:$PATH

# install and cache app dependencies
COPY ./package.json ./package-lock.json ./

RUN npm clean-install --verbose

# add app
COPY . .

# generate build
RUN npm run build

#==== RUNTIME ====#

FROM nginx:stable

EXPOSE 8080

ARG APP_USER=nginx

ENV API_URL=""
ENV APP_URL=""
ENV SSO_URL=""
ENV SSO_CLIENT_ID=""

# Remove existing Nginx configuration
RUN set -x \
    && rm -f /etc/nginx/conf.d/*

# Copy Nginx configuration for Angular app
COPY ./docker/angular.webapp.conf /etc/nginx/conf.d/

# set working directory
WORKDIR /usr/share/nginx/html

# copy artifact build from the 'build environment'
COPY --from=builder --chown=${APP_USER}:${APP_USER} /app/dist/sqp-frontend .

# copy entrypoint executable
COPY --chown=${APP_USER}:${APP_USER} docker/docker-entrypoint.sh /bin/

# add permissions
RUN chown -R ${APP_USER}:${APP_USER} /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html && \
    chown -R ${APP_USER}:${APP_USER} /var/cache/nginx && \
    chown -R ${APP_USER}:${APP_USER} /var/log/nginx && \
    chown -R ${APP_USER}:${APP_USER} /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R ${APP_USER}:${APP_USER} /var/run/nginx.pid && \
    chmod +x /bin/docker-entrypoint.sh

USER ${APP_USER}

ENTRYPOINT [ "/bin/docker-entrypoint.sh" ]


# run nginx
CMD ["nginx", "-g", "daemon off;"]
