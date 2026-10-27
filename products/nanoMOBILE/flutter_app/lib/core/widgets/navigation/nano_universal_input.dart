import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_input_tool_context.dart';
import 'nano_input_tool_controls.dart';
export 'nano_input_tool_controls.dart';
export 'nano_input_tool_context.dart';

part 'nano_universal_input_config.dart';
part 'nano_universal_input_notifier.dart';
part 'nano_input_scope.dart';
part 'nano_input_scope_state.dart';

/// Contrato compartido: cada módulo conserva su editor y su propietario.
typedef UniversalInputSubmitHandler = void Function(String text);
