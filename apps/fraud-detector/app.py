from flask import Flask, request
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource
import random

resource = Resource.create({"service.name": "fraud-detector"})

otlp_exporter = OTLPSpanExporter(endpoint="http://jaeger:4318/v1/traces")
provider = TracerProvider(resource=resource)
processor = SimpleSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("fraud-detector")

app = Flask(__name__)


@app.route("/")
def home():
    return "Fraud Detector Service - Use /check-fraud endpoint"


@app.route("/check-fraud")
def check_fraud():
    context = extract(request.headers)  # ← Extract traceparent
    with tracer.start_as_current_span("check-fraud", context=context) as span:
        fraud_score = random.uniform(0, 1)
        span.set_attribute("fraud.score", fraud_score)

        if fraud_score > 0.9:  # 10% fraud detection rate
            span.set_attribute("fraud.detected", True)
            print(f"Fraud detected! Score: {fraud_score:.3f}")
            return "Fraud detected", 403

        span.set_attribute("fraud.detected", False)
        print(f"No fraud. Score: {fraud_score:.3f}")
        return "OK", 200


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    print("Fraud Detector starting...")
    app.run(host="0.0.0.0", port=8080)
