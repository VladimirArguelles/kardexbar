enum RolUsuario {
  administrador('ADMINISTRADOR', 'Administrador General'),
  supervisor('SUPERVISOR', 'Supervisor de Barra'),
  bartender('BARTENDER', 'Bartender / Despachador'),
  cajero('CAJERO', 'Cajero');

  final String dbValue;
  final String label;
  const RolUsuario(this.dbValue, this.label);

  static RolUsuario fromString(String? value) {
    return RolUsuario.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => RolUsuario.bartender,
    );
  }
}

class Perfil {
  final String id;
  final String nombre;
  final String? apellido;
  final String? correo;
  final String? telefono;
  final RolUsuario rol;
  final bool activo;

  Perfil({
    required this.id,
    required this.nombre,
    this.apellido,
    this.correo,
    this.telefono,
    required this.rol,
    required this.activo,
  });

  String get nombreCompleto =>
      apellido != null && apellido!.isNotEmpty ? '$nombre $apellido' : nombre;

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Usuario',
      apellido: json['apellido'] as String?,
      correo: json['correo'] as String?,
      telefono: json['telefono'] as String?,
      rol: RolUsuario.fromString(json['rol'] as String?),
      activo: json['activo'] as bool? ?? true,
    );
  }
}
