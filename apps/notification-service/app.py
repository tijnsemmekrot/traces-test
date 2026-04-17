from flask import Flask, request
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

resource = Resource.create({"service.name": "notification-service"})
os.environ["OTEL_EXPORTER_OTLP_CERTIFICATE"] = ""
os.environ["OTEL_EXPORTER_OTLP_INSECURE"] = "true"

# otlp_exporter = OTLPSpanExporter(
#     # endpoint="http://otel-collector-agent.default.svc.cluster.local:4317"
#     endpoint="http://jaeger.jaeger.svc.cluster.local:4318/v1/traces"
# )

otlp_exporter = OTLPSpanExporter(
    endpoint="https://apm-apm-http.elastic-stack.svc:8200/v1/traces",
    headers={"Authorization": "Bearer my-super-secret-token"},
)

sampler = TraceIdRatioBased(0.1)
provider = TracerProvider(resource=resource, sampler=sampler)
processor = SimpleSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("notification-service")

app = Flask(__name__)


@app.route("/")
def home():
    return "Notification Service - Use /send-notification endpoint"


@app.route("/send-notification")
def send_notification():
    context = extract(request.headers)  # ← Extract traceparent
    with tracer.start_as_current_span("send-notification", context=context) as span:
        span.set_attribute("notification.channel", "email")
        print("Notification sent")
        return "Notification sent", 200


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    print("Notification Service starting...")
    app.run(host="0.0.0.0", port=8080)
