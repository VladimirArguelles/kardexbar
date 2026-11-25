import 'package:flutter_test/flutter_test.dart';
import 'package:kardexbar/features/comandas/models/comanda_model.dart';

void main() {
  group('Comanda.fromJson', () {
    test('parsea detalles desde comanda_detalles (esquema actual)', () {
      final json = <String, dynamic>{
        'id': 'cmd-1',
        'numero_ticket': 'CMD-0001',
        'fecha': '2026-11-24T22:10:00Z',
        'nombre_cliente': 'Carlos',
        'sede_id': 'sede-1',
        'precio_total': 10.5,
        'estado': 'REGISTRADA',
        'comanda_detalles': [
          {
            'id': 'det-1',
            'comanda_id': 'cmd-1',
            'producto_barra_id': 'pb-1',
            'nombre_producto': 'Cuba Libre',
            'cantidad': 2,
            'precio_unitario': 5.25,
            'ronda': 1,
          },
        ],
      };

      final comanda = Comanda.fromJson(json);

      expect(comanda.nombreCliente, 'Carlos');
      expect(comanda.precioTotal, 10.5);
      expect(comanda.detalles.length, 1);
      expect(comanda.detalles.first.productoBarraId, 'pb-1');
      expect(comanda.detalles.first.nombreProducto, 'Cuba Libre');
      expect(comanda.detalles.first.cantidad, 2.0);
      expect(comanda.detalles.first.subtotal, 10.5);
    });

    test('parsea detalles desde detalle_comandas (registros históricos)', () {
      final json = <String, dynamic>{
        'id': 'b3de8a24-3cde-4e0f-8334-2b57086141d2',
        'numero_ticket': 'CMD-HIST-02001',
        'fecha': '2026-08-01',
        'nombre_cliente': null,
        'cliente': 'GUIDO',
        'sede_id': '',
        'precio_total': '7.20',
        'estado': 'CERRADA',
        'comanda_detalles': <dynamic>[],
        'detalle_comandas': [
          {
            'id': 'c0f940e7-2b8d-486e-b485-225c6fe4374f',
            'comanda_id': 'b3de8a24-3cde-4e0f-8334-2b57086141d2',
            'producto_id': '3db1fc55-f0e1-4a99-bacd-6dbd51b355fd',
            'cantidad': '6.00',
            'precio_unitario': '1.20',
            'productos': {'nombre': 'Cerveza zulia/polar'},
          },
        ],
      };

      final comanda = Comanda.fromJson(json);

      expect(comanda.nombreCliente, 'GUIDO');
      expect(comanda.precioTotal, 7.20);
      expect(comanda.detalles.length, 1);
      expect(
        comanda.detalles.first.productoBarraId,
        '3db1fc55-f0e1-4a99-bacd-6dbd51b355fd',
      );
      expect(comanda.detalles.first.nombreProducto, 'Cerveza zulia/polar');
      expect(comanda.detalles.first.cantidad, 6.0);
      expect(comanda.detalles.first.precioUnitario, 1.20);
      expect(comanda.detalles.first.subtotal, closeTo(7.20, 0.001));
    });
  });
}
