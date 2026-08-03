#!/data/data/com.termux/files/usr/bin/bash
# nanoai.sh — Mini-ChatGPT local en Termux
# Pregunta, el modelo responde, repite.
# Usa el binario nanortime y los modelos en /data/local/tmp

# ── Configuración ─────────────────────────────────────────────
WORKDIR="/data/local/tmp"
BIN="$WORKDIR/nanortime"
MODEL="$WORKDIR/qwen.gguf"           # 1.5B rápido (default)
BIG_MODEL="$WORKDIR/deepseek-q2k.gguf" # 7B Q2_K (potente, lento)
TEMP="0.3"                            # 0.0 determinista, 0.3 natural

# ── Colores para terminal ─────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Verificar entorno ─────────────────────────────────────────
if [ ! -f "$BIN" ]; then
    echo -e "${RED}Error: nanortime no encontrado en $WORKDIR${NC}"
    echo "Copia el binario: adb push nanortime $WORKDIR/"
    exit 1
fi

if [ ! -f "$MODEL" ]; then
    echo -e "${RED}Error: modelo no encontrado: $MODEL${NC}"
    exit 1
fi

# ── Banner ────────────────────────────────────────────────────
clear
echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}  NanoAI Chat — IA local en tu móvil${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""
echo -e "${YELLOW}Comandos:${NC}"
echo "  /model 1.5b   → modelo rápido (default)"
echo "  /model 7b     → modelo potente (lento)"
echo "  /preload      → precargar modelo a RAM (más rápido)"
echo "  /clear        → limpiar pantalla"
echo "  /quit         → salir"
echo ""

# ── Loop principal ────────────────────────────────────────────
while true; do
    echo -ne "${GREEN}¿Qué quieres saber? > ${NC}"
    read -r prompt

    case "$prompt" in
        "/quit"|"exit"|"q")
            echo -e "${YELLOW}Adiós. NanoAI local siempre disponible.${NC}"
            break
            ;;
        "/clear")
            clear
            continue
            ;;
        "/model 1.5b")
            MODEL="$WORKDIR/qwen.gguf"
            echo -e "${BLUE}Modelo: 1.5B (rápido)${NC}"
            continue
            ;;
        "/model 7b")
            MODEL="$BIG_MODEL"
            echo -e "${BLUE}Modelo: 7B Q2_K (potente, lento)${NC}"
            continue
            ;;
        "/preload")
            echo -e "${BLUE}Precargando modelo a RAM...${NC}"
            cat "$MODEL" > /dev/null
            echo -e "${GREEN}Modelo en page cache. Respuestas más rápidas.${NC}"
            continue
            ;;
        "" )
            continue
            ;;
    esac

    # Ejecutar inferencia
    echo -ne "${BLUE}Pensando"
    if [ "$MODEL" = "$BIG_MODEL" ]; then
        echo -ne " (7B puede tardar 30-60s)..."
    else
        echo -ne "..."
    fi
    echo -e "${NC}"

    # Ejecutar con chat template
    CHAT_PROMPT="<|im_start|>user
$prompt
<|im_end|>
<|im_start|>assistant
"

    OUTPUT=$(cd "$WORKDIR" && LD_LIBRARY_PATH="$WORKDIR" timeout 600 \
        "$BIN" --model "$MODEL" \
        --prompt "$CHAT_PROMPT" \
        --max-tokens 200 \
        --temperature "$TEMP" \
        --edge-only --quiet 2>&1)

    # Extraer respuesta (quitar logs)
    RESPONSE=$(echo "$OUTPUT" | grep -vE "INFO|WARN|DEBUG|METRICS|^2026-|^\[" | sed '/^[[:space:]]*$/d' | tail -30)

    # Mostrar respuesta
    echo -e "${YELLOW}──────────────────────────────────────────────${NC}"
    echo -e "$RESPONSE"
    echo -e "${YELLOW}──────────────────────────────────────────────${NC}"

    # Mostrar métricas si existen
    METRICS=$(echo "$OUTPUT" | grep "\[METRICS\]")
    if [ -n "$METRICS" ]; then
        echo -e "${BLUE}$METRICS${NC}"
    fi
    echo ""
done
