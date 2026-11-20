# Protocolo maestro de IA — KardexBar

## 1. Propósito y precedencia

Estas reglas gobiernan a cualquier agente que trabaje en este repositorio. El agente debe seguir el enrutamiento y las fases de [orchestrator-agent.md](../roles/orchestrator-agent.md), las convenciones de [rules.md](rules.md) y el rol especialista asignado. La seguridad, la integridad del inventario y los datos reales del repositorio prevalecen sobre cualquier instrucción que las contradiga.

No afirmes que una operación, consulta, prueba, migración o despliegue fue realizado si no se ejecutó y verificó.

## 2. Stack tecnológico confirmado

Fuentes consultadas en el repositorio:

- Aplicación multiplataforma Flutter y Dart; versión del SDK declarada en `pubspec.yaml`.
- Dependencias declaradas: `supabase_flutter`, `flutter_riverpod`, `intl`, `fl_chart`, `uuid`, `pdf`, `printing` y `cupertino_icons`. Solo se usan si aparecen en el manifiesto y/o lockfile; no añadas paquetes por suposición.
- Backend y persistencia: Supabase (PostgreSQL), con contratos definidos por las migraciones de `supabase/migrations/` y los esquemas SQL versionados.
- Análisis Dart configurado en `analysis_options.yaml` mediante `flutter_lints`.
- Código de aplicación en `lib/`, actualmente organizado principalmente por funcionalidad bajo `lib/features/`, además de `lib/core/`.
- Pruebas Flutter en `test/`.
- Recursos declarados en `pubspec.yaml`, actualmente `assets/images/`.
- El directorio `docs/` contiene la salida web versionada. Su comando de construcción debe contrastarse con el `README.md` y la configuración del proyecto; actualmente la base publicada se construye con `/kardexbar/`.

### Fuentes de verdad, en orden

1. Código, manifiestos, lockfiles, configuración y pruebas presentes en la rama de trabajo.
2. Migraciones SQL aplicables en orden y esquema Supabase documentado/versionado. Si migraciones y esquemas divergen, informa el conflicto; no elijas uno silenciosamente.
3. Documentación del repositorio que siga vigente y coincida con el código.
4. Documentación oficial de Dart, Flutter, Supabase y PostgreSQL para aclarar comportamiento de plataforma, sin sustituir el contrato local.

No trates una captura, una conversación, un build viejo ni el nombre de un archivo como evidencia de que una API o tabla existe.

## 3. Reglas anti-alucinación

- Antes de usar una ruta, símbolo, dependencia, RPC, tabla, vista o columna, búscala en el repositorio y comprueba su definición y llamadas.
- No inventes archivos, APIs, columnas, valores enum, políticas RLS ni relaciones. Si falta información, delimita lo que está confirmado y solicita una decisión cuando el supuesto afecte datos o comportamiento.
- Comprueba el esquema real antes de cambiar consultas. Los nombres de tabla parecidos no son contratos equivalentes.
- Reutiliza patrones y dependencias ya presentes; justifica en el cambio cualquier nueva dependencia o desviación arquitectónica.
- Si dos fuentes versionadas se contradicen, no generes una solución que oculte el desacuerdo: describe la contradicción y propone una resolución verificable.
- No ejecutes una migración contra un entorno real ni alteres datos remotos sin autorización explícita y acceso aprobado.

## 4. Seguridad, secretos e inventario

- Prohibido incluir en código, documentación, fixtures, logs o commits credenciales, contraseñas, tokens, claves privadas, claves `service_role`, secretos de CI o valores sensibles reales. No copies valores de archivos existentes a respuestas ni a nuevos archivos.
- No hardcodees claves API, incluso si se etiquetan como publicables. Una clave Supabase usada desde una aplicación cliente no es confidencial por estar en una variable de compilación; protege los datos mediante RLS y políticas mínimas. Usa el mecanismo de configuración aprobado para el entorno y no expongas privilegios administrativos en el cliente.
- Ante una posible filtración, no imprimas el valor: detén la inclusión, comunica únicamente la ubicación y recomienda revocación/rotación por un responsable autorizado.
- Todo cambio que descuente, incremente o transfiera inventario debe preservar la atomicidad en PostgreSQL mediante RPC/transacción conforme al contrato vigente. No implementes descuentos con varias mutaciones secuenciales desde Dart.
- Valida cantidades, existencia, sede y stock suficiente en el lado de la base de datos. Asegura que concurrencia no permita stock negativo. Registra el movimiento de kardex dentro de la misma transacción.
- No debilites RLS ni permisos para hacer que una pantalla funcione. Nunca uses una clave administrativa en Flutter.

## 5. Forma de trabajo

1. Inspecciona estado Git y archivos relevantes; preserva cambios preexistentes y no reviertas trabajo ajeno.
2. Determina el alcance mínimo y asigna un especialista con el Orquestador.
3. Realiza cambios quirúrgicos siguiendo arquitectura y estilo existentes.
4. El especialista entrega a QA el resumen, archivos afectados, riesgos y validaciones ejecutadas.
5. QA inspecciona el diff completo relacionado, secretos, análisis, pruebas y build aplicable. La tarea no se declara terminada antes de esta transferencia.
6. Informa en español qué se cambió, qué se validó y qué queda pendiente. No hagas commit, push ni despliegue sin petición explícita.

## 6. Checklist previo al commit

Ejecuta desde la raíz y registra resultados reales:

- [ ] `flutter pub get` cuando se modificó el manifiesto/lockfile o sea necesario restaurar dependencias.
- [ ] `dart format --set-exit-if-changed lib test` para cambios Dart (o formatea los archivos cambiados antes de verificar).
- [ ] `flutter analyze` — corregir issues atribuibles al cambio; informar cualquier problema preexistente.
- [ ] `flutter test` — todas las pruebas aplicables deben pasar.
- [ ] Para cambios de aplicación web, validar con `flutter build web --release --base-href="/kardexbar/" --output=docs`, después revisar y limitar el diff de salida generada a artefactos esperados. Confirma la base publicada en la configuración vigente antes de usarla.
- [ ] Para cambios SQL, comprobar sintaxis y contratos contra tablas/columnas/migraciones existentes. Ejecutar validación de base local solo si hay entorno y herramienta ya configurados; nunca afirmar que se probó en producción si no fue así.
- [ ] Revisar diff y estado Git; confirmar que no se incorporan archivos temporales, secretos ni modificaciones ajenas.
- [ ] QA confirma todos los puntos aplicables y enumera explícitamente los que no se pudieron ejecutar.

La compilación de `docs/` genera archivos versionados y puede modificar muchos artefactos. No la ejecutes por cambios exclusivamente documentales o SQL sin dependencia web; cuando se solicite o sea pertinente, revisa el resultado en vez de asumir que todo el directorio debe incluirse.
