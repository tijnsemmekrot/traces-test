from flask import Flask, request
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource

resource = Resource.create({"service.name": "notification-service"})

otlp_exporter = OTLPSpanExporter(endpoint="http://jaeger:4318/v1/traces")
provider = TracerProvider(resource=resource)
processor = SimpleSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("notification-service")

app = Flask(__name__)


@app.route("/")
def home():
    return "Notification Service - Use /send-notification endpoint"


@app.route("/send-notification")
@trace.tracer.start_as_current_span("send-notification")
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
