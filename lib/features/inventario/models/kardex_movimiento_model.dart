/// Modelo de Registro de Movimiento en Kardex
class KardexMovimiento {
  final String id;
  final DateTime fecha;
  final String insumoId;
  final String? insumoNombre;
  final double? insumoCostoUnitario;
  final String sedeOrigenId;
  final String? sedeDestinoId;
  final String tipoMovimiento;
  final double cantidad;
  final String? beneficiarioOMotivo;
  final String? referenciaId;

  KardexMovimiento({
    required this.id,
    required this.fecha,
    required this.insumoId,
    this.insumoNombre,
    this.insumoCostoUnitario,
    required this.sedeOrigenId,
    this.sedeDestinoId,
    required this.tipoMovimiento,
    required this.cantidad,
    this.beneficiarioOMotivo,
    this.referenciaId,
  });

  factory KardexMovimiento.fromJson(Map<String, dynamic> json) {
    final insumoObj = json['insumos_inventario'] as Map<String, dynamic>?;
    return KardexMovimiento(
      id: json['id'] as String,
      fecha: json['fecha'] != null
          ? DateTime.tryParse(json['fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      insumoId: json['insumo_id'] as String? ?? '',
      insumoNombre: insumoObj != null ? insumoObj['nombre'] as String? : null,
      insumoCostoUnitario: insumoObj != null
          ? double.tryParse(insumoObj['costo_unitario']?.toString() ?? '0') ??
                0.0
          : 0.0,
      sedeOrigenId: json['sede_origen_id'] as String? ?? '',
      sedeDestinoId: json['sede_destino_id'] as String?,
      tipoMovimiento: json['tipo_movimiento'] as String? ?? 'MOVIMIENTO',
      cantidad: double.tryParse(json['cantidad']?.toString() ?? '0') ?? 0.0,
      beneficiarioOMotivo: json['beneficiario_o_motivo'] as String?,
      referenciaId: json['referencia_id'] as String?,
    );
  }
}
