# Acceso Google y diseño Frost de Nano

Fecha: 18 de octubre de 2026, America/Bogota.

## Implementación

El botón del acceso llama directamente a AuthController.continueWithGoogle.
No presenta cuentas escritas a mano ni sustituye OAuth por el acceso local.
Cancelar el selector conserva la pantalla y permite reintentar; no navega como éxito.
El estado de carga evita operaciones simultáneas y se libera al terminar.

GoogleSignInIdentityProvider utiliza google_sign_in 7.2.0, exige un Client ID web
válido y una cuenta con identificador, correo y token devueltos por el SDK.
Una inicialización fallida se retira de la caché para permitir reintento. La caché
se asocia al cliente, no a todos los adaptadores de prueba indistintamente.

LocalAuthAdapter espera a restaurar la sesión anterior antes de guardar la nueva.
Guarda la sesión antes de anunciarla como actual. GoogleAccountRepository incorpora
una escritura estricta del perfil autenticado y la procedencia identityVerified.
La migración de correos sintéticos antiguos no borra una identidad OAuth auténtica
por coincidir con una cadena de correo heredada.

El perfil de cuenta se almacena localmente. El nombre FirestoreAccountAdapter se
conserva por compatibilidad; esta implementación no sincroniza un perfil con Firestore.
Iniciar sesión no concede por sí mismo permisos de Drive, Gmail o sincronización.

## Diseño

El usuario aprobó la referencia Frost con el búho y los tonos azules. La ilustración
se generó como recurso sin textos ni botones y se copió a
`nanoMOBILE/flutter_app/assets/nano/login_frost_owl.png`.

FrostLoginSurface limita el tema azul al acceso. FrostOwlArtwork usa una imagen
estática con decodificación de ancho 1000 y degradados de borde, sin temporizadores
ni filtros de desenfoque. FrostLoginButton conserva semántica y comportamiento
Material sobre el degradado. LoginPageLayout conserva el desplazamiento y las
dos columnas cuando el ancho disponible lo permite. Los controles permanecen reales.

## Registro Google Cloud

Se creó el proyecto Nano, ID `nano-512019`, número `581501993088`.
No se vinculó una cuenta de facturación ni se contrató un servicio de pago.
El usuario autorizó el correo eememeai@gmail.com para soporte/contacto y aceptó
la Política de Datos del Usuario de los Servicios de las APIs de Google.

Clientes creados y verificados en la consola:

- Nombre: Nano Android.
- Paquete: dev.nanoai.mobile.
- SHA-1 de la firma de desarrollo usada para estas compilaciones locales:
  CC:6D:0A:A8:3F:3C:F5:3B:26:6A:43:90:05:F3:37:E4:64:DB:B1:0A.
- Android: `581501993088-g5l89oec8j0ocriiu1t9coj3em6chft4.apps.googleusercontent.com`.
- Web (Nano Web Identity): `581501993088-gmge7djilg6k1698vc87nt3ssfcd5n9j.apps.googleusercontent.com`.
- GoogleOAuthConfiguration conserva el ID Web público como valor predeterminado.
  NANO_GOOGLE_SERVER_CLIENT_ID permite sustituirlo expresamente en otra distribución.
- El Client ID es público. No debe confundirse con una API key ni incluirse un
  client_secret en el APK, las pruebas o los registros.

La creación de ambos clientes fue autorizada por el usuario. El secreto Web no se
guardó, descargó ni incorporó al APK. No se añadieron redirecciones u orígenes ficticios.
El proyecto permanece en modo Prueba; no se publicó para el público general.
La consola confirmó `eememeai@gmail.com` como único usuario de prueba. Se corrigió
la clasificación del cliente Android para acceso humano, sin marca de agente IA.
La selección real de cuenta en el teléfono sigue pendiente; crear credenciales y
compilar no demuestra por sí mismo un acceso exitoso.
Una firma distinta, como la firma de Play Store, requiere su registro correspondiente.

## Evidencia y límites

Antes de la instrucción de no ejecutar más pruebas: 23 pruebas aprobadas, sobre estado de cuenta, repositorio, configuración faltante,
reintentos del SDK, cancelación, conservación del perfil verificado, restauración
de sesión y distribución visual en tres tamaños. Análisis de los archivos cambiados
sin problemas detectados.

Los SDKs/identidades de las pruebas unitarias son dependencias de prueba explícitas,
no implementaciones usadas en producción. Esto no demuestra un acceso real a Google.
No se ejecutó integración contra el paquete principal ni se desinstaló la app durante
estas comprobaciones.

Después de esa instrucción no se ejecutaron más pruebas automatizadas. La revisión
posterior es manual y la compilación sirve para producir el APK actualizado.
La vista `build/login_portrait.png` es un render de Flutter anterior a esa instrucción,
no una captura del teléfono. La evidencia de clientes está en
`build/google_oauth_clients_created.png`.

## Compilación e instalación final

Se compiló fullSideload release correctamente (288,2 segundos, 101,9 MB).
Se instaló con actualización conservadora `adb install -r`, resultado Success,
sin desinstalar ni borrar los datos actuales. Android registra la actualización
el 18 de octubre de 2026 a las 14:51:03 en VGL7MVFMDYQG8T55.
SHA-256 del APK: `1D5E68C2219C8AA3B187A7F10FD1646683D2AB88D42EC87960537A9AD84029A8`.
No se forzó cierre de sesión para capturar el diseño ni se ejecutó un acceso
Google en nombre del usuario. La confirmación de cuenta en el dispositivo queda pendiente.

Documentación oficial consultada:

- [Configuración Android de google_sign_in](https://pub.dev/packages/google_sign_in_android).
- [Registro Android con Google](https://codelabs.developers.google.com/sign-in-with-google-android).
- [Planes gratuitos y acceso social](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).
- [Política de datos de las APIs de Google](https://developers.google.com/terms/api-services-user-data-policy).
