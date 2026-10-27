part of 'catalog_models.dart';

// Alternativas GGUF verificadas contra revisiones y SHA del publicador.
// RAM estimada: estos archivos todavía requieren mediciones en el OPPO.
const _catalogEntries3 = <LmCatalogEntry>[
  // Qwen oficial: 428730208 bytes; Q4_0 reduce pesos, no garantiza rapidez.
  LmCatalogEntry(
    'Qwen2.5-0.5B-Instruct (GGUF Q4_0)',
    '0.5B',
    'Q4_0',
    0.40,
    0.8,
    'qwen2.5-0.5b-instruct-q4_0.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/6dd44a1fb35d11b5d1b28902876ce3cc9e882d0e/qwen2.5-0.5b-instruct-q4_0.gguf',
    '7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.gguf,
  ),

  // Qwen oficial: 1066227232 bytes; conserva una alternativa CPU explícita.
  LmCatalogEntry(
    'Qwen2.5-1.5B-Instruct (GGUF Q4_0)',
    '1.5B',
    'Q4_0',
    0.99,
    1.5,
    'qwen2.5-1.5b-instruct-q4_0.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/dd26da440ef0330c47919d1ecae0966d24022222/qwen2.5-1.5b-instruct-q4_0.gguf',
    'dcd819ff094852c38faba6873d8ff0c9d51eadb2844539e52042ae5d647bbfdb',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.gguf,
  ),

  // Meta Llama, conversión comunitaria de bartowski: 773025920 bytes.
  LmCatalogEntry(
    'Llama-3.2-1B-Instruct (GGUF Q4_0)',
    '1.2B',
    'Q4_0',
    0.72,
    1.2,
    'Llama-3.2-1B-Instruct-Q4_0.gguf',
    'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/7080af622111fe07bb6ce039f744cdb78aaf4973/Llama-3.2-1B-Instruct-Q4_0.gguf',
    'fa0390e7c043f89ae1847bd6682d748041a99d4ef3de0e0b27d33b6af97a8be8',
    template: ChatTemplate.llama,
    tier: ModelTier.deep,
    backendType: ModelBackendType.gguf,
  ),
];
