// QUÉ: recursos originales FeatherCore con transparencia alfa comprobada.
// CÓMO: cada significado resuelve un PNG propio declarado en assets/nano/.
// POR QUÉ: navegación y catálogo comparten identidad sin duplicar significados.
part of 'feather_core_icon.dart';

const _featherCoreAssets = <FeatherCoreType, String>{
  FeatherCoreType.documents: 'assets/nano/feather_ocr_document.png',
  FeatherCoreType.automation: 'assets/nano/feather_navigation_automation.png',
  FeatherCoreType.models: 'assets/nano/feather_navigation_models.png',
  FeatherCoreType.terminal: 'assets/nano/feather_navigation_terminal.png',
  FeatherCoreType.settings: 'assets/nano/feather_navigation_settings.png',
};
