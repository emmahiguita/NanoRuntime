/** Conservative file-derived labels; never imply unverified runtime capabilities. */
export function describeModel(model = {}) {
  if (model.catalog) {
    const c=model.catalog;
    return {title:c.title,type:'Multimodal · integración parcial',use:c.use+' '+c.note,parameters:c.parameters,quantization:c.quantization,source:'Ficha del catálogo: '+c.repo+'. La instalación no certifica compatibilidad con Nano.'};
  }
  const name = String(model.name || '').replace(/\.gguf$/i, '');
  const lower = name.toLowerCase();
  const parameters = name.match(/(?:^|[-_])(\d+(?:\.\d+)?)[bB](?=[-_]|$)/)?.[1];
  const quantization = name.match(/(?:^|[-_])(Q\d(?:_[A-Z0-9]+)*|IQ\d(?:_[A-Z0-9]+)*|F16|BF16|F32)$/i)?.[1]?.toUpperCase();
  let type = 'Tipo sin confirmar';
  let use = 'El archivo no permite confirmar su especialidad. Consulta su ficha de origen antes de usarlo.';
  if (/embed|bge-|e5-|nomic-embed/.test(lower)) {
    type = 'Embeddings'; use = 'Representación de texto para búsqueda semántica. La generación de vectores no está integrada en este panel.';
  } else if (/mmproj|projector/.test(lower)) {
    type = 'Proyector multimodal'; use = 'Archivo auxiliar de un modelo de visión; no funciona como modelo de conversación independiente.';
  } else if (/vision|llava|(?:^|[-_])vl(?:[-_]|$)/.test(lower)) {
    type = 'Multimodal'; use = 'El nombre indica un modelo de visión y texto. Este panel no confirma soporte de imágenes en el runtime.';
  } else if (/coder|code-/.test(lower)) {
    type = 'Texto · código'; use = 'Orientado a explicar, completar y revisar código; no ejecuta programas por sí mismo.';
  } else if (/deepseek-r1|qwq|reason/.test(lower)) {
    type = 'Texto · razonamiento'; use = 'Orientado a respuestas con razonamiento. La calidad y la velocidad dependen del modelo y del equipo.';
  } else if (/instruct|chat/.test(lower)) {
    type = 'Texto · instrucciones'; use = 'Conversación, redacción, resumen y respuestas a instrucciones. No incorpora acceso web ni herramientas por sí mismo.';
  }
  return {title:name, type, use, parameters:parameters ? `${parameters}B parámetros` : 'Parámetros sin confirmar', quantization:quantization || 'Cuantización sin confirmar', source:'Tipo y especialidad inferidos del nombre del archivo.'};
}
