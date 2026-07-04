/// Servicio de eventos WebSocket (Centrifugo OSS v6).
///
/// Recibe eventos en tiempo real de 8 canales.
/// No usa JSON-RPC — solo lectura de eventos broadcast.
library;

import 'dart:async';

/// Tipos de eventos WebSocket del daemon BOS.
enum WsEventType {
  sagaStart,
  sagaOk,
  sagaFail,
  stepStart,
  stepOk,
  stepFail,
  healthUpdate,
  reload,
  reconcile,
  fichaStateChanged,
  systemAlert,
  releaseAvailable,
  releaseApplied,
}

/// Evento WebSocket recibido del daemon.
class WsEvent {
  final WsEventType type;
  final String? ficha;
  final String? step;
  final String? message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const WsEvent({
    required this.type,
    this.ficha,
    this.step,
    this.message,
    required this.timestamp,
    this.data,
  });
}

/// Servicio de eventos WebSocket.
///
/// En una implementación completa, este servicio se conecta a Centrifugo
/// y distribuye eventos a los BLoCs correspondientes vía StreamControllers.
/// Por ahora, escucha eventos del mismo WebSocket JSON-RPC (modo híbrido).
class WsService {
  final _eventController = StreamController<WsEvent>.broadcast();
  final _alertsController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream de eventos del sistema.
  Stream<WsEvent> get events => _eventController.stream;

  /// Stream de alertas del sistema.
  Stream<Map<String, dynamic>> get alerts => _alertsController.stream;

  /// Procesa un mensaje recibido del WebSocket.
  void handleMessage(Map<String, dynamic> raw) {
    final typeStr = raw['type'] as String?;
    if (typeStr == null) return;

    final event = WsEvent(
      type: _parseType(typeStr),
      ficha: raw['ficha'] as String?,
      step: raw['step'] as String?,
      message: raw['message'] as String?,
      timestamp: raw['timestamp'] != null
          ? DateTime.tryParse(raw['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      data: raw['data'] as Map<String, dynamic>?,
    );

    _eventController.add(event);

    // Alertas del sistema
    if (event.type == WsEventType.systemAlert && event.data != null) {
      _alertsController.add(event.data!);
    }
  }

  WsEventType _parseType(String type) {
    switch (type) {
      case 'saga_start':
        return WsEventType.sagaStart;
      case 'saga_ok':
        return WsEventType.sagaOk;
      case 'saga_fail':
        return WsEventType.sagaFail;
      case 'step_start':
        return WsEventType.stepStart;
      case 'step_ok':
        return WsEventType.stepOk;
      case 'step_fail':
        return WsEventType.stepFail;
      case 'health_update':
        return WsEventType.healthUpdate;
      case 'reload':
        return WsEventType.reload;
      case 'reconcile':
        return WsEventType.reconcile;
      case 'ficha_state_changed':
        return WsEventType.fichaStateChanged;
      case 'system_alert':
        return WsEventType.systemAlert;
      case 'release_available':
        return WsEventType.releaseAvailable;
      case 'release_applied':
        return WsEventType.releaseApplied;
      default:
        return WsEventType.healthUpdate;
    }
  }

  void dispose() {
    _eventController.close();
    _alertsController.close();
  }
}
