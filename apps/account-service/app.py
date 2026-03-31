from flask import Flask, request
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource
import random
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

resource = Resource.create({"service.name": "account-service"})

otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-collector-agent.default.svc.cluster.local:4317"
    # endpoint="http://jaeger.jaeger.svc.cluster.local:4318/v1/traces"
)
sampler = TraceIdRatioBased(0.1)
provider = TracerProvider(resource=resource, sampler=sampler)
processor = SimpleSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("account-service")

app = Flask(__name__)


@app.route("/")
def home():
    return "Account Service - Use /verify-balance endpoint"


@app.route("/verify-balance")
def verify_balance():
    context = extract(request.headers)  # ← Extract traceparent
    with tracer.start_as_current_span("verify-balance", context=context) as span:
        balance = random.uniform(50, 500)
        required = 103.00  # $100.50 + $2.50 fee

        span.set_attribute("balance", balance)
        span.set_attribute("required", required)

        if balance < required or random.random() < 0.15:  # 15% failure rate
            span.set_attribute("sufficient", False)
            print(f"Insufficient balance: ${balance:.2f} < ${required:.2f}")
            return "Insufficient balance", 402

        span.set_attribute("sufficient", True)
        print(f"Balance verified: ${balance:.2f}")
        return "OK", 200


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    print("Account Service starting...")
    app.run(host="0.0.0.0", port=8080)
