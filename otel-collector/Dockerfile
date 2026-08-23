FROM busybox:stable-musl AS tools

FROM otel/opentelemetry-collector-contrib:0.115.1
COPY --from=tools /bin/busybox /bin/busybox
COPY --from=tools /bin/wget /bin/wget
COPY otel-collector-config.yaml /etc/otelcol/otel-collector-config.yaml
