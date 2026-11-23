// Supabase Edge Function: parse-comanda-ticket
// KardexBar - Escaneo inteligente de tickets y comandas de caja mediante Gemini Vision
// Compatible con Deno runtime en Supabase Functions

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(handler: (req: Request) => Promise<Response> | Response): void;
};

interface ProductoCatalogo {
  id: string;
  nombre: string;
  precio?: number;
  precio_venta?: number;
  categoria?: string;
}

interface RequestBody {
  imageBase64?: string;
  mimeType?: string;
  productos?: ProductoCatalogo[];
}

interface ItemComandaDetectado {
  producto_id: string | null;
  nombre_detectado: string;
  cantidad: number;
}

interface ComandaTicketParsed {
  numero_ticket: string | null;
  cliente: string | null;
  mesero: string | null;
  items: ItemComandaDetectado[];
}

/**
 * Genera encabezados CORS dinámicos permitiendo solicitudes desde
 * arguelles.github.io, localhost y entornos web/móviles.
 */
function getCorsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin');
  let allowOrigin = '*';

  if (origin) {
    if (
      origin.includes('arguelles.github.io') ||
      origin.includes('localhost') ||
      origin.includes('127.0.0.1')
    ) {
      allowOrigin = origin;
    }
  }

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
  };
}

Deno.serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req);

  // Manejo de solicitudes de pre-vuelo (preflight CORS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({
        error: `Método ${req.method} no permitido. Utiliza POST.`,
      }),
      {
        status: 405,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }

  try {
    // 1. Validar variable de entorno de Gemini API
    const rawApiKey = Deno.env.get('GEMINI_API_KEY');
    const geminiApiKey = rawApiKey?.trim().replace(/^["']|["']$/g, '');
    if (!geminiApiKey || geminiApiKey.length < 10) {
      return new Response(
        JSON.stringify({
          error:
            'La variable de entorno GEMINI_API_KEY no está configurada o es inválida en el proyecto de Supabase.',
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // 2. Parsear y validar cuerpo de la petición
    let body: RequestBody;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({
          error: 'El cuerpo de la petición debe ser un objeto JSON válido.',
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    if (!body.imageBase64 || typeof body.imageBase64 !== 'string') {
      return new Response(
        JSON.stringify({
          error:
            "Parámetro requerido 'imageBase64' no fue suministrado o es inválido.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // 3. Limpiar base64 y normalizar mimeType
    let cleanBase64 = body.imageBase64.trim();
    let mimeType = body.mimeType || 'image/jpeg';

    const dataUriPrefixMatch = cleanBase64.match(
      /^data:([a-zA-Z0-9]+\/[a-zA-Z0-9+.-]+);base64,(.+)$/s
    );

    if (dataUriPrefixMatch) {
      if (!body.mimeType) {
        mimeType = dataUriPrefixMatch[1];
      }
      cleanBase64 = dataUriPrefixMatch[2].trim();
    } else {
      cleanBase64 = cleanBase64.replace(/^data:[^;]+;base64,/, '').trim();
    }

    cleanBase64 = cleanBase64.replace(/\s/g, '');

    if (!cleanBase64) {
      return new Response(
        JSON.stringify({
          error:
            "El contenido de 'imageBase64' se encuentra vacío tras la limpieza.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // 4. Formatear el catálogo de productos disponibles para la instrucción
    const productos: ProductoCatalogo[] = Array.isArray(body.productos)
      ? body.productos
      : [];

    const catalogoTexto = productos
      .map((p) => {
        const precio = p.precio ?? p.precio_venta ?? 0;
        const cat = p.categoria ? ` [${p.categoria}]` : '';
        return `- ID: "${p.id}", Nombre: "${p.nombre}"${cat}, Precio: ${precio}`;
      })
      .join('\n');

    // 5. Construir prompt para Gemini Vision
    const prompt = `Eres un asistente de visión artificial de alta precisión para el sistema de control de bar "KardexBar".
Tu objetivo es analizar minuciosamente la fotografía adjunta de un ticket, comanda impresa o nota de barra física de caja, e interpretar los productos solicitados cruzándolos con el catálogo oficial disponible.

INSTRUCCIONES DE EXTRACCIÓN Y NORMALIZACIÓN:
1. "numero_ticket":
   - Busca el número de folio, correlativo, número de ticket o comanda (ejemplos: "00123", "#45", "TICKET 12").
   - Devuelve solo el string identificador o null si no se visualiza ninguno.

2. "cliente":
   - Extrae el nombre del cliente o identificación de mesa si está escrito como cliente (ejemplos: "Mesa 4", "Juan Gómez", "Barra Principal").
   - Devuelve el string o null si no existe.

3. "mesero":
   - Extrae el nombre o código del mesero, cajero o bartender (ejemplos: "Ilario Medina", "Mesero: Pedro").
   - Devuelve el string o null si no se visualiza.

4. "items":
   - Lista ordenada de todos los productos identificados en el ticket.
   - "nombre_detectado": Texto exacto o abreviado como aparece escrito en la comanda (ejemplos: "B. ZULIA", "MOJITO", "2 POLAR PILSEN", "ST").
   - "cantidad": Cantidad numérica positiva de unidades (ejemplo: 1, 2, 4.5). Si no especifica cantidad, asume 1.
   - "producto_id": UUID del producto coincidente en el CATÁLOGO OFICIAL DE KARDEXBAR provisto abajo.
     * REGLAS CRÍTICAS DE INTERPRETACIÓN DE ABREVIATURAS Y JERGA DE BAR:
       - "B. ZULIA", "BALDE ZULIA", "BALDE DE ZULIA", "B-ZULIA" -> Asignar al UUID de "BALDE POLAR-ZULIA" (o el balde Polar Zulia del catálogo).
       - "MOJITO", "MOJITO CUBANO", "MOJ" -> Asignar al UUID de "MOJITO CUBANO".
       - "P. VERDE", "POLAR PILSEN", "PILSEN", "PILSNER" -> Cerveza Polar Pilsen.
       - "P. LIGHT", "POLAR LIGHT", "LIGHT", "AZUL" -> Cerveza Polar Light.
       - "ST", "S.T.", "SANTA TERESA", "RON SANTA TERESA" -> Ron Santa Teresa correspondiente.
       - "SOLERA VERDE", "SOLERA AZUL", "SOLERA IPA" -> Coincidencia con Solera correspondiente.
       - "AGUA", "AGUA MINERAL" -> Producto agua del catálogo.
       - Relaciona fonética y semánticamente con los nombres del catálogo.
       - Si un ítem detectado NO coincide de ninguna forma con algún producto del catálogo, coloca "producto_id": null.

CATÁLOGO DE PRODUCTOS DISPONIBLES EN KARDEXBAR:
${catalogoTexto || '(Sin productos en el catálogo)'}

IMPORTANTE:
Debes responder ESTRICTAMENTE con un objeto JSON válido con la siguiente estructura:
{
  "numero_ticket": string | null,
  "cliente": string | null,
  "mesero": string | null,
  "items": [
    {
      "producto_id": string | null,
      "nombre_detectado": string,
      "cantidad": number
    }
  ]
}`;

    // 6. Consultar Google Gemini Vision API con bucle de modelos y tolerancia a fallos
    const geminiPayload = {
      contents: [
        {
          parts: [
            {
              inlineData: {
                mimeType: mimeType,
                data: cleanBase64,
              },
            },
            {
              text: prompt,
            },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.1,
      },
    };

    const modelsToTry = [
      'gemini-3.8-flash',
      'gemini-3.8-flash-lite',
      'gemini-flash-latest',
      'gemini-3.0-flash',
    ];
    const maxPasses = 2;
    let geminiResponse: Response | null = null;
    let lastErrorText = '';
    let lastStatusCode = 500;
    let successfulModel = '';

    modelLoop: for (let pass = 1; pass <= maxPasses; pass++) {
      for (let i = 0; i < modelsToTry.length; i++) {
        const model = modelsToTry[i];
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`;

        try {
          const res = await fetch(geminiUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(geminiPayload),
          });

          if (res.ok) {
            geminiResponse = res;
            successfulModel = model;
            console.log(
              `[parse-comanda-ticket] Petición exitosa a Gemini Vision con modelo: ${model} (en pasada ${pass}/${maxPasses})`
            );
            break modelLoop;
          }

          lastStatusCode = res.status;
          lastErrorText = await res.text();
          console.warn(
            `[parse-comanda-ticket] Intento con modelo ${model} (pasada ${pass}) falló con status ${res.status}:`,
            lastErrorText
          );

          // Si es 404, 429, 500, 503 o indica saturación/modelo no disponible, reintentar con el siguiente
          const shouldRetry =
            res.status === 404 ||
            res.status === 429 ||
            res.status === 500 ||
            res.status === 503 ||
            lastErrorText.includes('is no longer available') ||
            lastErrorText.includes('not found') ||
            lastErrorText.includes('Resource has been exhausted') ||
            lastErrorText.includes('Overloaded') ||
            lastErrorText.includes('Internal error') ||
            lastErrorText.includes('high demand');

          if (shouldRetry) {
            const isLastAttempt =
              pass === maxPasses && i === modelsToTry.length - 1;
            if (!isLastAttempt) {
              console.log(
                `[parse-comanda-ticket] Esperando 1200ms antes del siguiente reintento...`
              );
              await new Promise((resolve) => setTimeout(resolve, 1200));
              continue;
            }
          }

          // Si es error 400 definitivo que no sea por modelo no disponible, no reintentar
          if (
            res.status === 400 &&
            !lastErrorText.includes('is no longer available')
          ) {
            break modelLoop;
          }
        } catch (fetchErr) {
          console.error(
            `[parse-comanda-ticket] Error de red al consultar ${model}:`,
            fetchErr
          );
          lastErrorText =
            fetchErr instanceof Error ? fetchErr.message : String(fetchErr);

          const isLastAttempt =
            pass === maxPasses && i === modelsToTry.length - 1;
          if (!isLastAttempt) {
            await new Promise((resolve) => setTimeout(resolve, 1200));
          }
        }
      }
    }

    if (!geminiResponse) {
      let parsedError = lastErrorText;
      try {
        const errJson = JSON.parse(lastErrorText);
        if (errJson.error?.message) {
          parsedError = errJson.error.message;
        }
      } catch (_) {}

      return new Response(
        JSON.stringify({
          error: `Error Gemini Vision API (${lastStatusCode}): ${parsedError}`,
          details: lastErrorText,
        }),
        {
          status:
            lastStatusCode >= 400 && lastStatusCode < 500
              ? 400
              : 502,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    const geminiJson = await geminiResponse.json();
    const candidate = geminiJson.candidates?.[0];
    const rawGeneratedText = candidate?.content?.parts?.[0]?.text;

    if (!rawGeneratedText) {
      return new Response(
        JSON.stringify({
          error: 'Gemini no generó contenido para la comanda analizada.',
          details: geminiJson,
        }),
        {
          status: 502,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // 7. Parsear y normalizar el JSON retornado
    let cleanJsonString = rawGeneratedText.trim();
    if (cleanJsonString.startsWith('```')) {
      cleanJsonString = cleanJsonString
        .replace(/^```(?:json)?\s*/i, '')
        .replace(/\s*```$/, '');
    }

    let parsedResult: any;
    try {
      parsedResult = JSON.parse(cleanJsonString);
    } catch (parseError) {
      console.error(
        'Fallo al parsear respuesta JSON de Gemini:',
        cleanJsonString,
        parseError
      );
      return new Response(
        JSON.stringify({
          error: 'La respuesta de Gemini no pudo ser procesada como JSON válido.',
          raw: rawGeneratedText,
        }),
        {
          status: 502,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // Estructura estrictamente tipada
    const normalizedResponse: ComandaTicketParsed = {
      numero_ticket:
        typeof parsedResult.numero_ticket === 'string' &&
        parsedResult.numero_ticket.trim().length > 0
          ? parsedResult.numero_ticket.trim()
          : null,
      cliente:
        typeof parsedResult.cliente === 'string' &&
        parsedResult.cliente.trim().length > 0
          ? parsedResult.cliente.trim()
          : null,
      mesero:
        typeof parsedResult.mesero === 'string' &&
        parsedResult.mesero.trim().length > 0
          ? parsedResult.mesero.trim()
          : null,
      items: Array.isArray(parsedResult.items)
        ? parsedResult.items.map((item: any) => ({
            producto_id:
              typeof item.producto_id === 'string' &&
              item.producto_id.trim().length > 0
                ? item.producto_id.trim()
                : null,
            nombre_detectado: String(
              item.nombre_detectado ?? item.nombre ?? 'Producto no identificado'
            ).trim(),
            cantidad:
              typeof item.cantidad === 'number' && item.cantidad > 0
                ? item.cantidad
                : parseFloat(item.cantidad) > 0
                ? parseFloat(item.cantidad)
                : 1,
          }))
        : [],
    };

    return new Response(JSON.stringify(normalizedResponse), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  } catch (error) {
    console.error('Error no controlado en parse-comanda-ticket:', error);
    return new Response(
      JSON.stringify({
        error: 'Ocurrió un error inesperado al procesar la comanda.',
        details: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});
