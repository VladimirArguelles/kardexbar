enum TipoMovimientoKardex {
  entrada('ENTRADA', 'Recepción de Insumos'),
  merma('MERMA', 'Registro de Merma'),
  traspasoSede2('TRASPASO_SEDE_2', 'Traslado a Sede 2'),
  venta('VENTA', 'Venta / Comanda'),
  agotado('AGOTADO', 'Declarado Agotado');

  final String dbValue;
  final String label;
  const TipoMovimientoKardex(this.dbValue, this.label);

  static TipoMovimientoKardex fromString(String? value) {
    return TipoMovimientoKardex.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => TipoMovimientoKardex.entrada,
    );
  }
}

class MovimientoKardex {
  final String id;
  final String insumoId;
  final String? insumoNombre;
  final TipoMovimientoKardex tipoMovimiento;
  final double cantidad;
  final String? motivo;
  final String? destino;
  final DateTime fecha;
  final String? referenciaComandaId;

  MovimientoKardex({
    required this.id,
    required this.insumoId,
    this.insumoNombre,
    required this.tipoMovimiento,
    required this.cantidad,
    this.motivo,
    this.destino,
    required this.fecha,
    this.referenciaComandaId,
  });

  factory MovimientoKardex.fromJson(Map<String, dynamic> json) {
    return MovimientoKardex(
      id: json['id'] as String,
      insumoId: json['insumo_id'] as String,
      insumoNombre: json['insumos'] != null
          ? (json['insumos']['nombre'] as String?)
          : (json['insumo_nombre'] as String?),
      tipoMovimiento:
          TipoMovimientoKardex.fromString(json['tipo_movimiento'] as String?),
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] as String?,
      destino: json['destino'] as String?,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      referenciaComandaId: json['referencia_comanda_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'insumo_id': insumoId,
      'tipo_movimiento': tipoMovimiento.dbValue,
      'cantidad': cantidad,
      'motivo': motivo,
      'destino': destino,
      'fecha': fecha.toIso8601String(),
      if (referenciaComandaId != null)
        'referencia_comanda_id': referenciaComandaId,
    };
  }
}
