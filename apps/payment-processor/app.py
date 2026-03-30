from flask import Flask, request
import requests
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract, inject
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

resource = Resource.create({"service.name": "payment-processor"})

otlp_exporter = OTLPSpanExporter(
    endpoint="http://jaeger.jaeger.svc.cluster.local:4318/v1/traces"
)
sampler = TraceIdRatioBased(0.1)
provider = TracerProvider(resource=resource, sampler=sampler)
processor = SimpleSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("payment-processor")

app = Flask(__name__)


@app.route("/")
def home():
    return "Payment Processor Service - Use /process-payment endpoint"


@app.route("/process-payment")
def process_payment():
    context = extract(request.headers)  # ← Extract traceparent
    with tracer.start_as_current_span("process-payment", context=context):
        # Step 1: Check for fraud
        headers = {}
        inject(headers)  # ← Inject traceparent for downstream service
        fraud_response = requests.get(
            "http://fraud-detector:8080/check-fraud", headers=headers
        )
        if fraud_response.status_code != 200:
            print("Payment blocked - fraud detected")
            return "Payment blocked: Fraud detected", 403

        # Step 2: Verify account balance
        balance_response = requests.get(
            "http://account-service:8080/verify-balance", headers=headers
        )
        if balance_response.status_code != 200:
            print("Payment failed - insufficient balance")
            return "Payment failed: Insufficient balance", 402

        # Step 3: Send notification
        requests.get(
            "http://notification-service:8080/send-notification", headers=headers
        )

        print("Payment processed successfully")
        return "Payment processed successfully", 200


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    print("Payment Processor starting...")
    app.run(host="0.0.0.0", port=8080)
