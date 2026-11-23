import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';

/// Pantalla con formularios de Iniciar Sesión (Login) y Registro (Register)
/// 100% responsiva, sin desbordamientos en ningún tamaño de pantalla móvil
/// y con integración directa a las tablas auth.users, perfiles y vista usuarios.
class LoginRegisterScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginRegisterScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  // 0: Iniciar Sesión, 1: Registrarse
  int _tabIndex = 0;

  // Formulario Login
  final _formKeyLogin = GlobalKey<FormState>();
  final _emailLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();
  bool _obscurePasswordLogin = true;

  // Formulario Registro
  final _formKeyRegister = GlobalKey<FormState>();
  final _nombreRegisterController = TextEditingController();
  final _apellidoRegisterController = TextEditingController();
  final _emailRegisterController = TextEditingController();
  final _passwordRegisterController = TextEditingController();
  final _confirmPasswordRegisterController = TextEditingController();
  String _rolSeleccionado = 'BARTENDER';
  bool _obscurePasswordRegister = true;
  bool _obscureConfirmPasswordRegister = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _rolesDisponibles = [
    'BARTENDER',
    'CAJERO',
    'SUPERVISOR',
    'ADMINISTRADOR',
  ];

  @override
  void dispose() {
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _nombreRegisterController.dispose();
    _apellidoRegisterController.dispose();
    _emailRegisterController.dispose();
    _passwordRegisterController.dispose();
    _confirmPasswordRegisterController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarLogin() async {
    if (!_formKeyLogin.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailLoginController.text.trim();
    final password = _passwordLoginController.text;

    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.user != null) {
        // Consultar el perfil registrado en public.perfiles o public.usuarios
        try {
          await SupabaseConfig.client
              .from('perfiles')
              .select()
              .eq('id', response.user!.id)
              .maybeSingle();
        } catch (_) {}

        // Redirigir a la interfaz operativa de KardexBar
        widget.onLoginSuccess();
      } else {
        setState(() {
          _errorMessage =
              'No se pudo iniciar sesión. Verifique sus credenciales.';
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          _errorMessage =
              'Credenciales inválidas. Correo o contraseña incorrectos.';
        } else if (e.message.toLowerCase().contains('email not confirmed')) {
          _errorMessage = 'El correo electrónico no ha sido confirmado aún.';
        } else {
          _errorMessage = 'Error de autenticación: ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  Future<void> _ejecutarRegistro() async {
    if (!_formKeyRegister.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final nombre = _nombreRegisterController.text.trim();
    final apellido = _apellidoRegisterController.text.trim();
    final email = _emailRegisterController.text.trim();
    final password = _passwordRegisterController.text;

    final redirectUrl = kIsWeb
        ? Uri.base.toString().split('?')[0].split('#')[0]
        : 'https://vladimirarguelles.github.io/kardexbar/';

    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
        data: {'nombre': nombre, 'apellido': apellido, 'rol': _rolSeleccionado},
      );

      if (!mounted) return;

      final user = response.user;
      if (user != null) {
        // Asegurar inserción directa en public.perfiles
        try {
          await SupabaseConfig.client.from('perfiles').upsert({
            'id': user.id,
            'nombre': nombre,
            'apellido': apellido,
            'correo': email,
            'rol': _rolSeleccionado,
            'activo': true,
          });
        } catch (_) {
          // El trigger handle_new_user en Supabase asegura la creación automática
        }

        // Si la sesión quedó autenticada de inmediato, entrar directamente
        if (response.session != null) {
          widget.onLoginSuccess();
          return;
        }

        setState(() {
          _isLoading = false;
          _successMessage =
              '¡Cuenta registrada con éxito! Ya puedes iniciar sesión.';
          _tabIndex = 0; // Cambiar a pestaña de Login
          _emailLoginController.text = email;
          _passwordLoginController.clear();
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudo crear la cuenta. Intente nuevamente.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.message.toLowerCase().contains('already registered')) {
          _errorMessage =
              'Este correo ya se encuentra registrado. Inicie sesión.';
        } else {
          _errorMessage = 'Error al registrar: ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo oficial compacto
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/KardexBar-Logo.png',
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Acceso Seguro al Sistema',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selector de Pestaña: Login vs Registro (sin desbordamientos)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _tabIndex = 0;
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 9,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _tabIndex == 0
                                    ? AppTheme.primaryAmber
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.login,
                                      size: 16,
                                      color: _tabIndex == 0
                                          ? AppTheme.background
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'INICIAR SESIÓN',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: _tabIndex == 0
                                            ? AppTheme.background
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _tabIndex = 1;
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 9,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _tabIndex == 1
                                    ? AppTheme.primaryAmber
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1,
                                      size: 16,
                                      color: _tabIndex == 1
                                          ? AppTheme.background
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'REGISTRARSE',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: _tabIndex == 1
                                            ? AppTheme.background
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mensaje de Error
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorCoral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.errorCoral),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.errorCoral,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.errorCoral,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Mensaje de Éxito
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.successMint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.successMint),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.successMint,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(
                                color: AppTheme.successMint,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tarjeta con Formulario Activo (con padding adaptado a móviles)
                  Card(
                    color: AppTheme.surface,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 18.0,
                      ),
                      child: _tabIndex == 0
                          ? _buildFormularioLogin()
                          : _buildFormularioRegister(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Acceso rápido / Atajo operativo con FittedBox
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextButton.icon(
                        onPressed: () => widget.onLoginSuccess(),
                        icon: const Icon(
                          Icons.flash_on,
                          size: 16,
                          color: AppTheme.primaryAmber,
                        ),
                        label: const Text(
                          'Acceso rápido con Sede Principal',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Formulario de Iniciar Sesión (Login)
  Widget _buildFormularioLogin() {
    return Form(
      key: _formKeyLogin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'INICIAR SESIÓN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.primaryAmber,
            ),
          ),
          const SizedBox(height: 14),

          // Correo Electrónico
          TextFormField(
            controller: _emailLoginController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Correo electrónico *',
              hintText: 'ejemplo@kardexbar.com',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: AppTheme.primaryAmber,
                size: 18,
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Ingrese su correo electrónico';
              }
              if (!val.contains('@') || !val.contains('.')) {
                return 'Ingrese un correo electrónico válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Contraseña
          TextFormField(
            controller: _passwordLoginController,
            obscureText: _obscurePasswordLogin,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Contraseña *',
              hintText: '••••••••',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppTheme.primaryAmber,
                size: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordLogin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
                onPressed: () {
                  setState(
                    () => _obscurePasswordLogin = !_obscurePasswordLogin,
                  );
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Ingrese su contraseña';
              }
              if (val.length < 6) {
                return 'Mínimo 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Botón Iniciar Sesión
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _ejecutarLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAmber,
                foregroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppTheme.background,
                      ),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formulario de Registro (Register) - Apilado verticalmente sin filas estrechas
  Widget _buildFormularioRegister() {
    return Form(
      key: _formKeyRegister,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CREAR NUEVA CUENTA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.secondaryCyan,
            ),
          ),
          const SizedBox(height: 14),

          // Nombre (Campo completo vertical)
          TextFormField(
            controller: _nombreRegisterController,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Nombre *',
              hintText: 'Carlos',
              prefixIcon: Icon(
                Icons.person_outline,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Ingrese su nombre';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Apellido (Campo completo vertical)
          TextFormField(
            controller: _apellidoRegisterController,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Apellido',
              hintText: 'Pérez (opcional)',
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Correo Electrónico
          TextFormField(
            controller: _emailRegisterController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Correo electrónico *',
              hintText: 'usuario@kardexbar.com',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Ingrese un correo electrónico';
              }
              if (!val.contains('@') || !val.contains('.')) {
                return 'Ingrese un correo electrónico válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Selector de Rol
          DropdownButtonFormField<String>(
            initialValue: _rolSeleccionado,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Rol en la Barra *',
              prefixIcon: Icon(
                Icons.admin_panel_settings_outlined,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
            ),
            items: _rolesDisponibles.map((rol) {
              return DropdownMenuItem<String>(
                value: rol,
                child: Text(
                  rol,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _rolSeleccionado = val);
            },
          ),
          const SizedBox(height: 12),

          // Contraseña
          TextFormField(
            controller: _passwordRegisterController,
            obscureText: _obscurePasswordRegister,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Contraseña *',
              hintText: 'Mínimo 6 caracteres',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordRegister
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
                onPressed: () {
                  setState(
                    () => _obscurePasswordRegister = !_obscurePasswordRegister,
                  );
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Ingrese una contraseña';
              }
              if (val.length < 6) {
                return 'Debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Confirmar Contraseña
          TextFormField(
            controller: _confirmPasswordRegisterController,
            obscureText: _obscureConfirmPasswordRegister,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              labelText: 'Confirmar Contraseña *',
              hintText: 'Repita la contraseña',
              prefixIcon: const Icon(
                Icons.lock_clock_outlined,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPasswordRegister
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
                onPressed: () {
                  setState(
                    () => _obscureConfirmPasswordRegister =
                        !_obscureConfirmPasswordRegister,
                  );
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Confirme la contraseña';
              }
              if (val != _passwordRegisterController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Botón Registrarse
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _ejecutarRegistro,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryCyan,
                foregroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppTheme.background,
                      ),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'REGISTRARSE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
