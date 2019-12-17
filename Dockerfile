FROM alpine AS build-tools

# Install build tools
RUN apk add --no-cache --virtual .build-deps                         \
        build-base                                                   \
        gnupg                                                        \
        pcre-dev                                                     \
        wget                                                         \
        zlib-dev

FROM build-tools AS retrieve

# Define build argument for version
ARG VERSION
ENV VERSION ${VERSION:-1.17.0}

# Retrieve and verify Nginx source
RUN wget -q http://nginx.org/download/nginx-${VERSION}.tar.gz   --no-check-certificate  && \
    wget -q http://nginx.org/download/nginx-${VERSION}.tar.gz.asc --no-check-certificate

# Extract archive
RUN tar xf nginx-${VERSION}.tar.gz

FROM retrieve As build

WORKDIR nginx-${VERSION}

# Build and install nginx
RUN ./configure                                                      \
        --with-ld-opt="-static"                                      \
        --with-http_sub_module                                    	 \
		--without-http_gzip_module 								  && \
    make install                                                  && \
    strip /usr/local/nginx/sbin/nginx							   
	
FROM alpine

WORKDIR /usr/local/nginx/html

# Customise static content, and configuration
COPY --from=build /usr/local/nginx /usr/local/nginx
COPY assets /usr/local/nginx/html/
COPY nginx.conf /usr/local/nginx/conf/

# Symlink access and error logs to /dev/stdout and /dev/stderr,
# in order to make use of Docker's logging mechanism
RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log            && \
    ln -sf /dev/stderr /usr/local/nginx/logs/error.log

RUN touch /run/nginx.pid  /var/run/nginx.pid && mkdir -p /var/log/nginx /var/lib/nginx && \
    chmod -R 777 /run/nginx.pid /var/run/nginx.pid /var/log/nginx /var/lib/nginx /usr/local/nginx 

RUN chgrp -R 0 /run/nginx.pid /var/run/nginx.pid /var/log/nginx /var/lib/nginx /usr/local/nginx  && \
    chmod -R g=u /run/nginx.pid /var/run/nginx.pid /var/log/nginx /var/lib/nginx /usr/local/nginx 

# Install mysql client for checking the DB
RUN apk update && \
    apk add mysql-client
	
# Add entrypoint script
COPY docker-entrypoint.sh /

# Expose port
EXPOSE 8080

# Define entrypoint and default parameters
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]

USER 1001
