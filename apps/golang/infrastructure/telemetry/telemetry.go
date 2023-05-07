package telemetry

import (
	"benchmark/config"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/jaeger"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

const (
	environment = "production"
	id          = 1
)

// Setup returns an OpenTelemetry TracerProvider configured to use
// the Jaeger exporter that will send spans to the provided url. The returned
// TracerProvider will also use a Resource configured with all the information
// about the application.
func Setup() (*sdktrace.TracerProvider, error) {
	// Create the Jaeger exporter

	exp, err := jaeger.New(
		jaeger.WithAgentEndpoint(jaeger.WithAgentHost(config.ConfigObj.OpenTelemetry.AgentHost), jaeger.WithAgentPort(config.ConfigObj.OpenTelemetry.AgentPort)),
	)
	if err != nil {
		return nil, err
	}
	tp := sdktrace.NewTracerProvider(
		// Always be sure to batch in production.
		sdktrace.WithBatcher(exp),
		// Record information about this application in a Resource.
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String(config.ConfigObj.App.Name),
			attribute.String("environment", environment),
			attribute.Int64("ID", id),
		)),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))

	return tp, nil
}
