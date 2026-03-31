from flask import Flask
import requests
import time
import os
import random
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor, ConsoleSpanExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import inject
from opentelemetry.sdk.resources import Resource
from opentelemetry.trace import Status, StatusCode
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

resource = Resource.create({"service.name": "payment-requester", "team": "PMSO"})

# otlp_exporter = ConsoleSpanExporter()
otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-collector-agent.default.svc.cluster.local:4317"
    # endpoint="http://jaeger.jaeger.svc.cluster.local:4318/v1/traces"
)

sampler = TraceIdRatioBased(0.1)
provider = TracerProvider(resource=resource, sampler=sampler)
processor = SimpleSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("payment-requester")

app = Flask(__name__)

PAYMENT_PROCESSOR_URL = os.getenv(
    "PAYMENT_PROCESSOR_URL", "http://payment-processor:8080"
)


@app.route("/")
def home():
    return "Payment Requester Service - Use /request-payment to send a payment request"


@app.route("/request-payment")
def request_payment():
    with tracer.start_as_current_span("request-payment") as span:
        span.set_attributes({"HTTP.method": "GET", "HTTP.url": PAYMENT_PROCESSOR_URL})

        headers = {}
        inject(headers)

        span.add_event("Sending request to payment processor")

        response = requests.get(
            f"{PAYMENT_PROCESSOR_URL}/process-payment",
            headers=headers,
            timeout=5,
        )

        span.add_event("Received response from payment processor")

        if response:
            span.set_status(Status(StatusCode.OK))
        else:
            span.set_status(Status(StatusCode.ERROR))
        return f"Response from payment processor: {response.text}\n", 200
        # span.record_exception()


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    print("Payment Requester starting...")
    print(f"Will send requests to: {PAYMENT_PROCESSOR_URL}")
    app.run(host="0.0.0.0", port=8080)
