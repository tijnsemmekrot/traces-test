ARG IMAGEVERSION=9.3.0
FROM docker.elastic.co/elastic-agent/elastic-agent-wolfi:${IMAGEVERSION}
USER root
RUN apk update && \
  apk upgrade && \
  rm -rf /var/cache/apk/*
USER elastic-agent

