// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_cloudfront_suppression.dart';

const _tracerName = 'dartastic_otel_libs_cloudfront';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Wraps an AWS CloudFront management API call (CreateInvalidation,
/// GetDistribution, etc.) in a CLIENT span.
Future<T> tracedCloudfront<T>({
  required String operation,
  required String distributionId,
  required Future<T> Function() invoke,
  int? pathCount,
}) async {
  if (cloudfrontInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'rpc.system': 'aws-api',
    'rpc.service': 'CloudFront',
    'rpc.method': operation,
    'aws.cloudfront.distribution.id': distributionId,
  };
  if (pathCount != null) {
    m['aws.cloudfront.invalidation.path_count'] = pathCount;
  }

  final span = _tracer().startSpan(
    'cloudfront $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
