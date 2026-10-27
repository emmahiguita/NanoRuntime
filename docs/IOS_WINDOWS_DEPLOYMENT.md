# Guía de Compilación y Despliegue de Nano iOS desde Windows

Esta guía detalla el procedimiento oficial y probado para compilar, firmar e instalar **Nano iOS** en un iPhone físico utilizando únicamente una máquina con **Windows**.

---

## 1. La Arquitectura de Solución (Windows + CI/CD en la Nube)

Apple restringe el compilador de iOS (Xcode, `actool`, `codesign` y `gen_snapshot` de Flutter AOT) para ejecutarse exclusivamente sobre el kernel Darwin (macOS).

Para solucionar esto sin comprar una Mac, se utiliza el flujo estándar de la industria:
1. **Edición y pruebas**: Se realizan en Windows.
2. **Compilación en la nube (Gratis)**: Un flujo de GitHub Actions con máquina macOS compila el proyecto y genera el paquete `.ipa` sin firma.
3. **Instalación y firma en Windows**: Mediante **Sideloadly** o **AltStore**, se firma con el Apple ID gratuito del usuario y se instala por USB o Wi-Fi en el iPhone.

---

## 2. Requisitos Previos en Windows

1. **iTunes para Windows**:
   - Descargar la versión instalador tradicional (`.exe`) directamente desde Apple (NO desde Microsoft Store):
   - [Descargar iTunes para Windows (64-bit)](https://www.apple.com/itunes/download/win64)
   - *Razón*: Proporciona los controladores de dispositivo USB oficiales (`Apple Mobile Device Support`).

2. **iCloud para Windows**:
   - Descargar la versión tradicional (`.exe`) de Apple:
   - [Descargar iCloud para Windows](https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA32-F410-4252-8903-296A95A38A68/iCloudSetup.exe)
   - *Razón*: Proporciona los servicios de red y autenticación Bonjour necesarios para la comunicación segura con el iPhone.

3. **Sideloadly** (Recomendado):
   - Descargar e instalar desde [sideloadly.io](https://sideloadly.io/).

---

## 3. Paso 1: Generar el archivo `.ipa` en GitHub Actions

1. Sube tus cambios al repositorio con `git push origin master`.
2. Ve a tu repositorio en GitHub y haz clic en la pestaña **Actions**.
3. Selecciona el flujo de trabajo **`Build iOS (NanoAI)`**.
4. Haz clic en **Run workflow** (o espera que termine si se activó por el push).
5. Al finalizar (tarda ~3-4 minutos), haz clic en la ejecución completada y descarga el artefacto **`NanoAI-iOS-IPA`** (archivo ZIP que contiene `NanoAI.ipa`).

---

## 4. Paso 2: Configurar el iPhone (iOS 16, 17 o 18)

1. **Activar Modo Desarrollador**:
   - En tu iPhone, ve a **Ajustes** > **Privacidad y seguridad**.
   - Desplázate hasta el final y entra en **Modo de desarrollador**.
   - Activa el interruptor y pulsa **Reiniciar**.
   - Al encenderse, desbloquea y confirma **Activar** e ingresa tu código de desbloqueo.

---

## 5. Paso 3: Firmar e Instalar desde Windows con Sideloadly

1. Conecta tu iPhone a la PC con cable USB.
2. En la pantalla del iPhone, si aparece *"¿Confiar en este ordenador?"*, pulsa **Confiar** e introduce tu código.
3. Abre **Sideloadly** en Windows. Verás el nombre de tu iPhone en el selector de dispositivos.
4. Arrastra el archivo `NanoAI.ipa` descargado a la ventana de Sideloadly.
5. En el campo **Apple ID**, escribe tu correo de cuenta de Apple.
6. Haz clic en el botón **Start**.
   - Si te pide la contraseña de tu Apple ID o el código de verificación en dos pasos (2FA), ingrésalo.
   - Sideloadly gestionará con los servidores de Apple un certificado de desarrollo personal gratuito (`Personal Team`) y firmará la app.
7. Cuando la barra marque **Done**, Nano AI aparecerá instalado en la pantalla de inicio de tu iPhone.

---

## 6. Paso 4: Primera Apertura en el iPhone

1. Al pulsar el icono de Nano por primera vez, iOS mostrará un aviso de *"Desarrollador empresarial/no fiable"*.
2. Ve a **Ajustes** > **General** > **VPN y gestión de dispositivos**.
3. En la sección *App de desarrollador*, pulsa sobre tu **Apple ID**.
4. Pulsa **Confiar en "[Tu Apple ID]"** y confirma.
5. ¡Listo! Abre **Nano AI**. El asistente Búho, la interfaz Glass, chat, visión y herramientas nativas estarán completamente operativos.

> [!NOTE]
> Las aplicaciones firmadas con Apple ID gratuito duran 7 días. Con Sideloadly abierto en tu PC en la misma red Wi-Fi, la app se renueva automáticamente en segundo plano sin perder datos ni configuraciones.
