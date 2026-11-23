import 'package:flutter_test/flutter_test.dart';
import 'package:kardexbar/features/comandas/models/comanda_model.dart';
import 'package:kardexbar/features/comandas/models/ticket_escaneado_model.dart';

void main() {
  group('TicketEscaneado Model Tests', () {
    final mockCatalogo = [
      ProductoBarra(
        id: 'uuid-balde-zulia',
        nombre: 'BALDE POLAR-ZULIA',
        categoria: 'Baldes',
        precioVenta: 10.0,
      ),
      ProductoBarra(
        id: 'uuid-mojito',
        nombre: 'MOJITO CUBANO',
        categoria: 'Cócteles',
        precioVenta: 5.0,
      ),
      ProductoBarra(
        id: 'uuid-polar-pilsen',
        nombre: 'POLAR PILSEN',
        categoria: 'Cervezas',
        precioVenta: 1.5,
      ),
    ];

    test('parsea correctamente ítem vinculado con ID directo', () {
      final json = {
        'producto_id': 'uuid-balde-zulia',
        'nombre_detectado': 'B. ZULIA',
        'cantidad': 2,
      };

      final item = ItemTicketEscaneado.fromJson(json, catalogo: mockCatalogo);

      expect(item.productoId, 'uuid-balde-zulia');
      expect(item.nombreDetectado, 'B. ZULIA');
      expect(item.cantidad, 2.0);
      expect(item.estaVinculado, isTrue);
      expect(item.productoSugerido?.nombre, 'BALDE POLAR-ZULIA');
      expect(item.productoSugerido?.precioVenta, 10.0);
    });

    test('resuelve coincidencia por nombre si producto_id es nulo', () {
      final json = {
        'producto_id': null,
        'nombre_detectado': 'MOJITO CUBANO',
        'cantidad': 1,
      };

      final item = ItemTicketEscaneado.fromJson(json, catalogo: mockCatalogo);

      expect(item.productoId, 'uuid-mojito');
      expect(item.estaVinculado, isTrue);
      expect(item.productoSugerido?.nombre, 'MOJITO CUBANO');
    });

    test('marca no vinculado cuando no existe en el catálogo', () {
      final json = {
        'producto_id': null,
        'nombre_detectado': 'BEBIDA INEXISTENTE',
        'cantidad': 1,
      };

      final item = ItemTicketEscaneado.fromJson(json, catalogo: mockCatalogo);

      expect(item.productoId, isNull);
      expect(item.estaVinculado, isFalse);
      expect(item.productoSugerido, isNull);
    });

    test('parsea TicketEscaneadoResult con metadatos completos', () {
      final json = {
        'numero_ticket': 'TK-0089',
        'cliente': 'MESA 4',
        'mesero': 'ILARIO MEDINA',
        'items': [
          {
            'producto_id': 'uuid-polar-pilsen',
            'nombre_detectado': 'PILSEN',
            'cantidad': 3,
          },
          {
            'producto_id': 'uuid-mojito',
            'nombre_detectado': 'MOJITO',
            'cantidad': 1,
          },
        ],
      };

      final result =
          TicketEscaneadoResult.fromJson(json, catalogo: mockCatalogo);

      expect(result.numeroTicket, 'TK-0089');
      expect(result.cliente, 'MESA 4');
      expect(result.mesero, 'ILARIO MEDINA');
      expect(result.items.length, 2);
      expect(result.items[0].productoSugerido?.nombre, 'POLAR PILSEN');
      expect(result.items[0].cantidad, 3.0);
      expect(result.items[1].productoSugerido?.nombre, 'MOJITO CUBANO');
    });
  });
}
