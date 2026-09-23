/// QUÉ HACE:
/// Scripts JavaScript inyectados para gestión segura de credenciales,
/// guardado automático y autocompletado en formularios web.
/// 
/// CÓMO FUNCIONA:
/// Intercepta eventos submit y clics en formularios de login, enviando
/// los datos vía JavaScriptHandler 'nanoSaveCredential' y proveyendo
/// la función window.__nanoAutofill.
/// 
/// POR QUÉ:
/// Desacopla la lógica de autenticación web de la infraestructura multimedia y zoom,
/// manteniendo archivos modulares menores a 130 líneas.
class BrowserAuthScripts {
  /// Script inyectado para detectar inicios de sesión e interceptar formularios de autenticación
  static const String credentialManagerScript = """
  (function() {
    if (window.__nanoCredentialManagerInstalled) return;
    window.__nanoCredentialManagerInstalled = true;

    function extractAndSendCredentials(form) {
      try {
        let root = form || document;
        let passInput = root.querySelector('input[type="password"]');
        if (!passInput || !passInput.value) return;

        let password = passInput.value;
        let userInput = null;

        let inputs = Array.from(root.querySelectorAll('input:not([type="hidden"]):not([type="password"]):not([type="submit"]):not([type="button"])'));
        for (let inp of inputs) {
          let type = (inp.type || '').toLowerCase();
          let name = (inp.name || '').toLowerCase();
          let id = (inp.id || '').toLowerCase();
          let auto = (inp.autocomplete || '').toLowerCase();
          if (type === 'email' || auto.includes('username') || auto.includes('email') ||
              name.includes('user') || name.includes('email') || name.includes('login') ||
              id.includes('user') || id.includes('email') || id.includes('login')) {
            if (inp.value && inp.value.trim().length > 0) {
              userInput = inp;
              break;
            }
          }
        }

        if (!userInput && inputs.length > 0) {
          for (let i = inputs.length - 1; i >= 0; i--) {
            if (inputs[i].value && inputs[i].value.trim().length > 0) {
              userInput = inputs[i];
              break;
            }
          }
        }

        let username = userInput ? userInput.value.trim() : '';
        if (password.length > 0 && window.flutter_inappwebview) {
          let host = window.location.hostname || '';
          window.flutter_inappwebview.callHandler('nanoSaveCredential', host, username, password);
        }
      } catch(e) {}
    }

    document.addEventListener('submit', function(e) {
      extractAndSendCredentials(e.target);
    }, true);

    document.addEventListener('click', function(e) {
      let btn = e.target.closest('button, input[type="submit"], [role="button"]');
      if (btn) {
        let text = (btn.innerText || btn.value || '').toLowerCase();
        if (text.includes('log in') || text.includes('iniciar') || text.includes('sign in') ||
            text.includes('acceder') || text.includes('entrar') || text.includes('submit')) {
          let form = btn.closest('form');
          extractAndSendCredentials(form);
        }
      }
    }, true);

    window.__nanoAutofill = function(user, pass) {
      try {
        let passInput = document.querySelector('input[type="password"]');
        if (!passInput) return false;

        let root = passInput.closest('form') || document;
        let inputs = Array.from(root.querySelectorAll('input:not([type="hidden"]):not([type="password"]):not([type="submit"]):not([type="button"])'));
        let userInput = null;

        for (let inp of inputs) {
          let type = (inp.type || '').toLowerCase();
          let name = (inp.name || '').toLowerCase();
          let id = (inp.id || '').toLowerCase();
          let auto = (inp.autocomplete || '').toLowerCase();
          if (type === 'email' || auto.includes('username') || auto.includes('email') ||
              name.includes('user') || name.includes('email') || name.includes('login') ||
              id.includes('user') || id.includes('email') || id.includes('login')) {
            userInput = inp;
            break;
          }
        }
        if (!userInput && inputs.length > 0) {
          userInput = inputs[inputs.length - 1];
        }

        if (userInput && user) {
          userInput.value = user;
          userInput.dispatchEvent(new Event('input', { bubbles: true }));
          userInput.dispatchEvent(new Event('change', { bubbles: true }));
        }

        if (passInput && pass) {
          passInput.value = pass;
          passInput.dispatchEvent(new Event('input', { bubbles: true }));
          passInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
        return true;
      } catch(e) { return false; }
    };
  })();
  """;

  /// Genera la llamada Javascript para autocompletar credenciales específicas
  static String buildAutofillScript(String username, String password) {
    final u = username.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final p = password.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    return "if (window.__nanoAutofill) { window.__nanoAutofill('$u', '$p'); }";
  }
}
