//! QUÉ: serializa conversaciones Llama 3 con su protocolo, no con ChatML.
//! CÓMO: usa roles saneados, eot_id y cabeceras declaradas en el GGUF.
//! POR QUÉ: mezclar protocolos produce etiquetas literales y pierde continuidad.

/// Solo activa la familia cuando el template real contiene sus cabeceras.
pub(super) fn matches(template: &str) -> bool {
    template.contains("start_header_id") && template.contains("end_header_id")
}

/// Separa sistema cacheable y turnos variables conservando el orden del diálogo.
pub(super) fn prompt_parts(
    system: &str,
    history: &[(String, String)],
    user: &str,
) -> (String, String) {
    let mut prefix = String::from("<|begin_of_text|>");
    if !system.is_empty() {
        prefix.push_str(&turn("system", system));
    }
    let mut dynamic = String::new();
    for (role, content) in history {
        dynamic.push_str(&turn(role, content));
    }
    dynamic.push_str(&turn("user", user));
    dynamic.push_str("<|start_header_id|>assistant<|end_header_id|>\n\n");
    (prefix, dynamic)
}

// Un cierre pertenece al turno completo; nunca se genera como contenido humano.
fn turn(role: &str, content: &str) -> String {
    format!("<|start_header_id|>{role}<|end_header_id|>\n\n{content}<|eot_id|>")
}
