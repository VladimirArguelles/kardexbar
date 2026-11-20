// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const String supabaseUrl = 'https://raqmozfiuyoctylzxnms.supabase.co';
const String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhcW1vemZpdXlvY3R5bHp4bm1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODA1MjcsImV4cCI6MjExMDQ1NjUyN30.8QwLZODpwJQfoIBg1J8HyFwR4mkvX8X12XL-UhQzozU';

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
      return jsonDecode(body);
    } else {
      throw Exception('HTTP ${resp.statusCode}: $body');
    }
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
      throw Exception('HTTP ${resp.statusCode}: $body');
    }
  } finally {
    client.close();
  }
}

void main() async {
  print('Testing Supabase REST connection...');
  final cats = await getRest('categorias?select=id,nombre');
  print('Categorias encontradas: ${cats.length}');
  final canales = await getRest('canales_origen?select=id,codigo,nombre');
  print('Canales encontrados: ${canales.length}');
}
