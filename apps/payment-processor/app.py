from flask import Flask, request
import os
import requests
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract, inject
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased
from opentelemetry.trace import Status, StatusCode

resource = Resource.create({"service.name": "payment-processor"})
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
tracer = trace.get_tracer("payment-processor")

app = Flask(__name__)


@app.route("/")
def home():
    return "Payment Processor Service - Use /process-payment endpoint"


@app.route("/process-payment")
def process_payment():
    context = extract(request.headers)
    with tracer.start_as_current_span("process-payment", context=context) as root_span:
        headers = {}
        inject(headers)

        # --- SUB-SPAN 1: FRAUD CHECK ---
        with tracer.start_as_current_span("check-fraud-logic") as sub_span:
            try:
                res = requests.get(
                    "http://fraud-detector:8080/check-fraud", headers=headers, timeout=5
                )
                sub_span.set_attribute("fraud.service.status", res.status_code)
                if res.status_code != 200:
                    sub_span.set_status(Status(StatusCode.ERROR))
                    return "Blocked", 403
            except Exception as e:
                sub_span.record_exception(e)
                return "Fraud Service Down", 503

        # --- SUB-SPAN 2: BALANCE VERIFICATION ---
        with tracer.start_as_current_span("verify-balance-logic") as sub_span:
            # You can add logic here that isn't just an HTTP call
            # e.g., some complex calculation before the request
            res = requests.get(
                "http://account-service:8080/verify-balance", headers=headers, timeout=5
            )
            if res.status_code != 200:
                sub_span.set_status(Status(StatusCode.ERROR))
                return "Insufficient Funds", 402

        with tracer.start_as_current_span("send-notification") as sub_span:
            try:
                res = requests.get(
                    "http://notification-service:8080/send-notification",
                    headers=headers,
                )
                if res.status_code != 200:
                    sub_span.set_status(Status(StatusCode.ERROR))
                    return "Notification Service Down", 403
            except Exception as e:
                sub_span.record_exception(e)
                return "Notification Service Down", 503

        return "Success", 200


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    print("Payment Processor starting...")
    app.run(host="0.0.0.0", port=8080)
