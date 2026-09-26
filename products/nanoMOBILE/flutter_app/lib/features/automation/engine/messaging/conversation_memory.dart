// conversation_memory.dart
//
// QUÉ HACE:
// Módulo orquestador de memoria conversacional lógica y persistente (WA-MEM-08).
// Exporta los modelos, contratos e implementaciones de almacenamiento.
//
// CÓMO FUNCIONA:
// - Aísla el estado por ConversationKey para evitar contaminación entre chats.
// - Re-exporta `conversation_memory_models.dart` y `conversation_memory_store.dart`.
// - Vincula las partes internas `conversation_memory_core.dart`, `conversation_memory_hydration.dart`
//   y `sqlite_conversation_memory_store.dart`.
//
// POR QUÉ:
// Mantiene retrocompatibilidad del 100% con todos los importadores del repositorio
// dividiendo un archivo monolítico de 799 líneas en unidades cohesivas de menos de 200 líneas (SOLID - SRP).

library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/automation_db_store_client.dart';
import '../storage/conversation_cleanup_client.dart';
import 'conversation_agent.dart';
import 'conversation_assignment_store.dart';
import 'conversation_memory_models.dart';
import 'conversation_memory_store.dart';
import 'conversation_persistence_queue.dart';
import 'incoming_message.dart';

export 'conversation_memory_models.dart';
export 'conversation_memory_store.dart';

part 'conversation_memory_core.dart';
part 'conversation_memory_cleanup.dart';
part 'conversation_memory_entries.dart';
part 'conversation_memory_hydration.dart';
part 'conversation_memory_obligations.dart';
part 'shared_prefs_conversation_memory_store.dart';
part 'sqlite_conversation_memory_store.dart';
