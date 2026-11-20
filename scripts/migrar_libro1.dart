// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

const String supabaseUrl = 'https://raqmozfiuyoctylzxnms.supabase.co';
const String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhcW1vemZpdXlvY3R5bHp4bm1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODA1MjcsImV4cCI6MjExMDQ1NjUyN30.8QwLZODpwJQfoIBg1J8HyFwR4mkvX8X12XL-UhQzozU';

final uuid = const Uuid();

Future<dynamic> postRest(String endpoint, dynamic data, {bool upsert = false}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('$supabaseUrl/rest/v1/$endpoint');
    final req = await client.postUrl(uri);
    req.headers.set('apikey', supabaseKey);
    req.headers.set('Authorization', 'Bearer $supabaseKey');
    req.headers.set('Content-Type', 'application/json');
    if (upsert) {
      req.headers.set('Prefer', 'resolution=merge-duplicates,return=representation');
    } else {
      req.headers.set('Prefer', 'return=representation');
    }
    req.add(utf8.encode(jsonEncode(data)));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (body.isEmpty) return [];
      return jsonDecode(body);
    } else {
      throw Exception('HTTP ${resp.statusCode} en $endpoint: $body');
    }
  } finally {
    client.close();
  }
}

Future<dynamic> patchRest(String endpoint, dynamic data) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('$supabaseUrl/rest/v1/$endpoint');
    final req = await client.patchUrl(uri);
    req.headers.set('apikey', supabaseKey);
    req.headers.set('Authorization', 'Bearer $supabaseKey');
    req.headers.set('Content-Type', 'application/json');
    req.add(utf8.encode(jsonEncode(data)));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    return body;
  } finally {
    client.close();
  }
}

Future<dynamic> getRest(String endpoint) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('$supabaseUrl/rest/v1/$endpoint');
    final req = await client.getUrl(uri);
    req.headers.set('apikey', supabaseKey);
    req.headers.set('Authorization', 'Bearer $supabaseKey');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(body);
    } else {
      throw Exception('HTTP ${resp.statusCode} en $endpoint: $body');
    }
  } finally {
    client.close();
  }
}

double parseNum(dynamic val, [double def = 0.0]) {
  if (val == null) return def;
  final s = val.toString().replaceAll(r'$', '').replaceAll(' ', '').replaceAll(',', '.').trim();
  return double.tryParse(s) ?? def;
}

String parseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return DateTime.now().toIso8601String().substring(0, 10);
  final parts = raw.trim().split('/');
  if (parts.length == 3) {
    final d = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    final y = parts[2];
    return '$y-$m-$d';
  }
  return DateTime.now().toIso8601String().substring(0, 10);
}

String cleanProductName(String rawName, String origen) {
  var name = rawName.trim();
  if (name.isEmpty && origen.contains('DESCOLCHE')) {
    return 'DESCOLCHE';
  }
  if (name.contains('1/4/2026')) {
    if (name.startsWith('1/2')) {
      return '1/2 CAJA CERVEZA';
    }
    return 'CAJA CERVEZA';
  }
  return name;
}

double getFactorUnidades(String productName) {
  final upper = productName.toUpperCase();
  if (upper.contains('1/2 BALDE')) return 5.0;
  if (upper.contains('BALDE')) return 10.0;
  if (upper.contains('1/2 CAJA')) return 18.0;
  if (upper.contains('CAJA')) return 36.0;
  return 1.0;
}

String classifyCategory(String productName) {
  final upper = productName.toUpperCase();
  if (upper.contains('CERVEZA') || upper.contains('BALDE') || upper.contains('CAJA')) {
    return 'Cervezas';
  }
  if (upper.contains('MOJITO') ||
      upper.contains('COLADA') ||
      upper.contains('DAIQUIRI') ||
      upper.contains('MARGARITA') ||
      upper.contains('COSMOPOLITAN') ||
      upper.contains('AZUL') ||
      upper.contains('GRINCH') ||
      upper.contains('NEMO') ||
      upper.contains('PANTERA') ||
      upper.contains('VIBRA') ||
      upper.contains('COCTEL') ||
      upper.contains('TEQUILA SUNRISE') ||
      upper.contains('TINTO') ||
      upper.contains('BESO') ||
      upper.contains('SANGRIA') ||
      upper.contains('CUBA LIBRE')) {
    return 'Cócteles de Autor';
  }
  if (upper.contains('WHISKY') ||
      upper.contains('RON') ||
      upper.contains('VODKA') ||
      upper.contains('TEQUILA') ||
      upper.contains('VINO') ||
      upper.contains('CAROREÑA')) {
    return 'Licores & Destilados';
  }
  if (upper.contains('JUGO') ||
      upper.contains('LIMONADA') ||
      upper.contains('NESTEA') ||
      upper.contains('MALTEADA')) {
    return 'Sin Alcohol & Jugos';
  }
  if (upper.contains('DESCOLCHE') || upper.contains('DESCORCHE')) {
    return 'Servicios & Descorche';
  }
  if (upper.contains('HELADO') || upper.contains('SNACK')) {
    return 'Snacks';
  }
  return 'Otros';
}

String getInsumoNameForProduct(String productName) {
  final upper = productName.toUpperCase();
  if (upper.contains('BALDE CERVEZA ZULIA/POLAR')) return 'CERVEZA ZULIA/POLAR';
  if (upper.contains('BALDE CERVEZA POLAR NEGRA')) return 'CERVEZA POLAR NEGRA';
  if (upper.contains('BALDE CERVEZA POLAR LIGHT')) return 'CERVEZA POLAR LIGHT';
  if (upper.contains('BALDE CERVEZA SOLERA')) return 'CERVEZA SOLERA';
  if (upper.contains('BALDE CERVEZA LIGTH/NEGRA')) return 'CERVEZA POLAR LIGHT';
  if (upper.contains('BALDE CERVEZA RESERVACION')) return 'CERVEZA ZULIA';
  if (upper.contains('BALDE CERVEZA ZULIA')) return 'CERVEZA ZULIA';
  if (upper.contains('1/2 BALDE CERVEZA')) return 'CERVEZA ZULIA';
  if (upper.contains('1/2 CAJA CERVEZA')) return 'CERVEZA ZULIA';
  if (upper.contains('CAJA CERVEZA')) return 'CERVEZA ZULIA';
  return productName;
}

void main() async {
  print('======================================================');
  print('FASE 2: MIGRACIÓN DE Libro1.csv A SUPABASE');
  print('======================================================');

  final csvFile = File('scripts/Libro1.csv');
  if (!csvFile.existsSync()) {
    print('ERROR: No se encontró scripts/Libro1.csv');
    return;
  }

  final lines = await csvFile.readAsLines(encoding: utf8);
  print('Líneas totales en CSV: ${lines.length}');
  final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
  print('Registros de datos: ${dataLines.length}');

  // 1. Cargar Categorías y Canales de Supabase
  final catsRaw = await getRest('categorias?select=id,nombre');
  final Map<String, String> catMap = {};
  for (var c in (catsRaw as List)) {
    catMap[c['nombre'] as String] = c['id'] as String;
  }
  print('Categorías en BD: ${catMap.keys.toList()}');

  final canalesRaw = await getRest('canales_origen?select=id,codigo,nombre');
  final Map<String, String> canalMap = {};
  for (var c in (canalesRaw as List)) {
    canalMap[c['codigo'] as String] = c['id'] as String;
  }
  print('Canales en BD: ${canalMap.keys.toList()}');

  // 2. Extraer productos e insumos únicos del CSV
  final Map<String, Map<String, dynamic>> insumosDef = {};
  final Map<String, Map<String, dynamic>> productosDef = {};

  for (final line in dataLines) {
    final cols = line.split(';');
    if (cols.length < 7) continue;

    final origen = cols[6].trim();
    final rawProd = cols[2].trim();
    final prodName = cleanProductName(rawProd, origen);
    if (prodName.isEmpty) continue;

    final precio = parseNum(cols[4]);
    final factor = getFactorUnidades(prodName);
    final catNombre = classifyCategory(prodName);
    final insumoNombre = getInsumoNameForProduct(prodName);

    if (!insumosDef.containsKey(insumoNombre.toUpperCase())) {
      insumosDef[insumoNombre.toUpperCase()] = {
        'nombre': insumoNombre,
        'codigo': 'INS-${insumoNombre.replaceAll(' ', '-').replaceAll('/', '-').toUpperCase()}-${uuid.v4().substring(0, 4)}',
        'unidad_medida': 'UND',
        'categoria_id': catMap[catNombre] ?? catMap['Otros'],
        'stock_actual': 100.0,
        'stock_minimo': 10.0,
        'agotado': false,
      };
    }

    if (!productosDef.containsKey(prodName.toUpperCase())) {
      productosDef[prodName.toUpperCase()] = {
        'nombre': prodName,
        'codigo': 'PROD-${prodName.replaceAll(' ', '-').replaceAll('/', '-').toUpperCase()}-${uuid.v4().substring(0, 4)}',
        'precio': precio,
        'factor_unidades': factor,
        'categoria_id': catMap[catNombre] ?? catMap['Otros'],
        'insumo_nombre': insumoNombre,
        'activo': true,
      };
    }
  }

  // 3. Upsert Insumos en Supabase
  final existingInsumos = await getRest('insumos?select=id,nombre');
  final Map<String, String> insumoIdMap = {};
  for (var i in (existingInsumos as List)) {
    final n = (i['nombre'] as String).trim().toUpperCase();
    insumoIdMap[n] = i['id'] as String;
  }

  final List<Map<String, dynamic>> nuevosInsumos = [];
  for (var entry in insumosDef.entries) {
    if (!insumoIdMap.containsKey(entry.key)) {
      nuevosInsumos.add(entry.value);
    }
  }

  if (nuevosInsumos.isNotEmpty) {
    print('Insertando ${nuevosInsumos.length} insumos nuevos...');
    final created = await postRest('insumos', nuevosInsumos);
    for (var c in (created as List)) {
      final n = (c['nombre'] as String).trim().toUpperCase();
      insumoIdMap[n] = c['id'] as String;
    }
  }
  print('Insumos listos en memoria: ${insumoIdMap.length}');

  // 4. Upsert Productos en Supabase
  final existingProds = await getRest('productos?select=id,nombre,codigo');
  final Map<String, String> prodIdMap = {};
  for (var p in (existingProds as List)) {
    final n = (p['nombre'] as String).trim().toUpperCase();
    prodIdMap[n] = p['id'] as String;
  }

  final List<Map<String, dynamic>> productosToInsert = [];
  for (var entry in productosDef.entries) {
    final insumoNombre = (entry.value['insumo_nombre'] as String).toUpperCase();
    final insumoId = insumoIdMap[insumoNombre];

    if (prodIdMap.containsKey(entry.key)) {
      final existingId = prodIdMap[entry.key]!;
      await patchRest('productos?id=eq.$existingId', {
        'factor_unidades': entry.value['factor_unidades'],
        'insumo_id': insumoId,
        'categoria_id': entry.value['categoria_id'],
        if ((entry.value['precio'] as double) > 0) 'precio': entry.value['precio'],
      });
    } else {
      final item = Map<String, dynamic>.from(entry.value);
      item.remove('insumo_nombre');
      item['insumo_id'] = insumoId;
      productosToInsert.add(item);
    }
  }

  if (productosToInsert.isNotEmpty) {
    print('Insertando ${productosToInsert.length} productos nuevos...');
    final created = await postRest('productos', productosToInsert);
    for (var c in (created as List)) {
      final n = (c['nombre'] as String).trim().toUpperCase();
      prodIdMap[n] = c['id'] as String;
    }
  }
  print('Productos listos en memoria: ${prodIdMap.length}');

  // 5. Cargar Comandas existentes
  print('\nCargando comandas existentes...');
  final existingComandasRaw = await getRest('comandas?select=id,fecha,cliente,origen_excel_raw,dia_semana,mesero');
  final Map<String, String> comandaIdMap = {};
  for (var c in (existingComandasRaw as List)) {
    final k = '${c['fecha']}|${c['cliente']}|${c['origen_excel_raw']}|${c['dia_semana']}|${c['mesero'] ?? ''}';
    comandaIdMap[k] = c['id'] as String;
  }
  print('Comandas existentes encontradas: ${comandaIdMap.length}');

  // 6. Clasificar registros
  final List<Map<String, dynamic>> auditoriaRows = [];
  final List<Map<String, dynamic>> mermaRows = [];
  final List<Map<String, dynamic>> rawSalesRows = [];

  for (var i = 0; i < dataLines.length; i++) {
    final line = dataLines[i];
    final cols = line.split(';');
    if (cols.length < 7) continue;

    final fecha = parseDate(cols[0]);
    final cliente = cols[1].trim();
    final rawProd = cols[2].trim();
    final origen = cols[6].trim();
    final prodName = cleanProductName(rawProd, origen);
    final cant = parseNum(cols[3], 1.0);
    final precio = parseNum(cols[4]);
    final total = parseNum(cols[5]);
    final diaSemana = cols.length > 7 ? cols[7].trim() : '';
    final mesero = cols.length > 10 ? cols[10].trim() : '';
    final cantCaja = cols.length > 11 ? parseNum(cols[11]) : 0.0;
    final cantBarra = cols.length > 12 ? parseNum(cols[12]) : 0.0;
    final totalDif = cols.length > 14 ? parseNum(cols[14]) : 0.0;

    final productoId = prodIdMap[prodName.toUpperCase()];
    final insumoNombre = getInsumoNameForProduct(prodName).toUpperCase();
    final insumoId = insumoIdMap[insumoNombre];

    if (origen == 'DIFERENCIAS_CERVEZAS') {
      auditoriaRows.add({
        'fecha': fecha,
        'cliente': cliente.isNotEmpty ? cliente : 'CLIENTE DIFERENCIA',
        'mesero': mesero.isNotEmpty ? mesero : 'MESERO/CAJERO',
        'producto_id': productoId,
        'precio_unitario': precio,
        'cant_caja': cantCaja,
        'cant_barra': cantBarra,
        'total_diferencia': totalDif > 0 ? totalDif : (cantBarra - cantCaja) * precio,
        'observacion': 'Importado de Libro1.csv - DIFERENCIAS_CERVEZAS',
      });
    } else if (origen == 'MERMAS_CERVEZAS') {
      if (insumoId != null) {
        mermaRows.add({
          'insumo_id': insumoId,
          'tipo_movimiento': 'MERMA',
          'cantidad': cant,
          'destino': 'Barra Principal',
          'motivo': 'Merma registrada - $cliente ($diaSemana)',
          'fecha': '${fecha}T12:00:00Z',
        });
      }
    } else {
      rawSalesRows.add({
        'fecha': fecha,
        'cliente': cliente.isNotEmpty ? cliente : 'CLIENTE BARRA',
        'producto_id': productoId,
        'prod_name': prodName,
        'cantidad': cant,
        'precio_unitario': precio,
        'total': total > 0 ? total : cant * precio,
        'origen': origen,
        'dia_semana': diaSemana,
        'mesero': mesero,
      });
    }
  }

  // 7. Si no hay registros de auditoria aún en BD, insertarlos
  final existingAuditoria = await getRest('auditoria_diferencias?select=id&limit=5');
  if ((existingAuditoria as List).isEmpty && auditoriaRows.isNotEmpty) {
    print('Insertando auditoria_diferencias (${auditoriaRows.length} registros)...');
    await postRest('auditoria_diferencias', auditoriaRows);
    print('✓ Auditoría diferencias insertada.');
  }

  // 8. Agrupar ventas en comandas
  final Map<String, List<Map<String, dynamic>>> comandaGroups = {};
  for (var item in rawSalesRows) {
    final key = '${item['fecha']}|${item['cliente']}|${item['origen']}|${item['dia_semana']}|${item['mesero']}';
    comandaGroups.putIfAbsent(key, () => []).add(item);
  }

  String resolveCanalId(String origen) {
    if (origen.contains('T_PELUCHE')) return canalMap['T_PELUCHE'] ?? canalMap['REGULAR']!;
    if (origen.contains('T_TRABAJADORES')) return canalMap['T_TRABAJADORES'] ?? canalMap['REGULAR']!;
    if (origen.contains('CUMPLEAÑEROS')) return canalMap['CUMPLEANOS'] ?? canalMap['REGULAR']!;
    if (origen.contains('RESERVACIONES')) return canalMap['RESERVACIONES'] ?? canalMap['REGULAR']!;
    if (origen.contains('COMBOS')) return canalMap['COMBOS'] ?? canalMap['REGULAR']!;
    if (origen.contains('DESCOLCHE')) return canalMap['DESCORCHE'] ?? canalMap['REGULAR']!;
    return canalMap['REGULAR']!;
  }

  final List<Map<String, dynamic>> comandasToInsert = [];
  final List<Map<String, dynamic>> detallesToInsert = [];
  int ticketCounter = 1000;

  for (var entry in comandaGroups.entries) {
    final items = entry.value;
    final first = items.first;
    final groupKey = entry.key;

    String comandaId;
    if (comandaIdMap.containsKey(groupKey)) {
      comandaId = comandaIdMap[groupKey]!;
    } else {
      comandaId = uuid.v4();
      ticketCounter++;

      double totalComanda = 0.0;
      for (var it in items) {
        totalComanda += (it['total'] as double);
      }

      final canalId = resolveCanalId(first['origen'] as String);

      comandasToInsert.add({
        'id': comandaId,
        'numero_ticket': 'TICK-${first['fecha'].toString().replaceAll('-', '')}-$ticketCounter',
        'fecha': first['fecha'],
        'dia_semana': first['dia_semana'],
        'cliente': first['cliente'],
        'canal_id': canalId,
        'origen_excel_raw': first['origen'],
        'mesero': (first['mesero'] as String).isNotEmpty ? first['mesero'] : null,
        'metodo_pago': 'EFECTIVO_USD',
        'subtotal': totalComanda,
        'descuento': 0.0,
        'total': totalComanda,
      });
      comandaIdMap[groupKey] = comandaId;
    }

    for (var it in items) {
      final pName = it['prod_name'] as String;
      final factor = getFactorUnidades(pName);
      final cant = it['cantidad'] as double;
      final pUnit = it['precio_unitario'] as double;
      final tLinea = it['total'] as double;

      detallesToInsert.add({
        'id': uuid.v4(),
        'comanda_id': comandaId,
        'producto_id': it['producto_id'],
        'cantidad': cant,
        'unidades_descontadas': cant * factor,
        'precio_unitario': pUnit,
        'total_linea': tLinea,
      });
    }
  }

  if (comandasToInsert.isNotEmpty) {
    print('Insertando ${comandasToInsert.length} comandas nuevas...');
    for (var i = 0; i < comandasToInsert.length; i += 100) {
      final end = (i + 100 < comandasToInsert.length) ? i + 100 : comandasToInsert.length;
      final chunk = comandasToInsert.sublist(i, end);
      await postRest('comandas', chunk);
      stdout.write('\rProgreso comandas: $end / ${comandasToInsert.length}');
    }
    print('\n✓ Comandas insertadas.');
  }

  // 9. Batch insert de detalle_comandas
  print('\nInsertando ${detallesToInsert.length} detalles de comanda en lotes de 100...');
  for (var i = 0; i < detallesToInsert.length; i += 100) {
    final end = (i + 100 < detallesToInsert.length) ? i + 100 : detallesToInsert.length;
    final chunk = detallesToInsert.sublist(i, end);
    await postRest('detalle_comandas', chunk);
    stdout.write('\rProgreso detalle_comandas: $end / ${detallesToInsert.length}');
  }
  print('\n✓ Todos los detalles de comanda fueron insertados con éxito.');

  print('\n======================================================');
  print('¡MIGRACIÓN COMPLETADA EXITOSAMENTE!');
  print('- Auditoría diferencias: ${auditoriaRows.length} registros');
  print('- Mermas: ${mermaRows.length} registros');
  print('- Comandas: ${comandaIdMap.length} registros');
  print('- Líneas de venta: ${detallesToInsert.length} registros');
  print('======================================================');
}
