# NanoRuntime — Makefile para reproducibilidad del paper
#
# Uso:
#   make build         — Compilar el runtime Rust (release)
#   make eval          — MMLU + HumanEval (Qwen 1.5B en PC)
#   make routing       — Benchmark routing por entropía
#   make benchmark-mem — RAM: nanortime vs llama.cpp (requiere Linux/WSL)
#   make fill-paper    — Rellena \TODO{} del paper con datos reales
#   make paper         — Compila el LaTeX del paper a PDF
#   make all-data      — Corre TODOS los benchmarks (no incluye Android)
#
# Variables a configurar:
MODEL ?= models/qwen2.5-1.5b-instruct-q4_k_m.gguf
MODEL_7B ?= models/deepseek-7b-q4_k_m.gguf
BINARY ?= target/release/nanortime.exe
CONFIG ?= nano.manifest.json
PAPER_DIR ?= docs/paper

.PHONY: build eval routing benchmark-mem fill-paper paper all-data clean-data

# ── Compilación ─────────────────────────────────────────────────────
build:
	cargo build --release -p nanortime-cli
	@echo "✅ Binary: $(BINARY)"

# ── Calidad del modelo ────────────────────────────────────────────────
eval: build
	pip install psutil --quiet
	python scripts/eval_harness.py \
		--binary "$(BINARY)" \
		--model  "$(MODEL)" \
		--task   all \
		--max-tokens 512
	@echo "📁 data/research/eval_results.json"

eval-7b: build
	python scripts/eval_harness.py \
		--binary "$(BINARY)" \
		--model  "$(MODEL_7B)" \
		--task   all \
		--max-tokens 512
	@echo "📁 data/research/eval_results.json"

# ── Routing por entropía ─────────────────────────────────────────────
routing: build
	python scripts/benchmark_routing.py \
		--binary "$(BINARY)" \
		--config "$(CONFIG)" \
		--max-tokens 128
	@echo "📁 data/research/routing_results.json"

# ── Benchmark de RAM (Linux/WSL/Android) ─────────────────────────────
benchmark-mem:
	@echo "⚠️  Requiere Linux/WSL/Android con llama-cli en PATH"
	chmod +x scripts/benchmark_memory.sh
	./scripts/benchmark_memory.sh "$(MODEL_7B)" 4096
	@echo "📁 benchmark_results/<timestamp>/benchmark_summary.json"

# ── Rellenar el paper con datos reales ──────────────────────────────
fill-paper:
	python scripts/fill_paper_todos.py
	@echo "📄 docs/paper/main.tex actualizado"

# ── Compilar LaTeX ────────────────────────────────────────────────────
paper:
	@which pdflatex || (echo "❌ pdflatex no encontrado. Instalar TeX Live/MiKTeX." && exit 1)
	cd $(PAPER_DIR) && \
		pdflatex -interaction=nonstopmode main.tex && \
		bibtex main && \
		pdflatex -interaction=nonstopmode main.tex && \
		pdflatex -interaction=nonstopmode main.tex
	@echo "📄 $(PAPER_DIR)/main.pdf generado"

# ── Todo en orden ────────────────────────────────────────────────────
all-data: build eval routing fill-paper
	@echo ""
	@echo "✅ Pipeline de datos completo."
	@echo "   Próximos pasos:"
	@echo "   1. Correr benchmark-mem en Android (make benchmark-mem MODEL_7B=...)"
	@echo "   2. Correr eval-7b en Android (make eval-7b MODEL_7B=...)"
	@echo "   3. make fill-paper para actualizar el paper"
	@echo "   4. make paper para compilar PDF"

# ── Limpieza ─────────────────────────────────────────────────────────
clean-data:
	rm -f data/research/*.json
	@echo "🗑️  Datos de benchmark eliminados"

clean-paper:
	cd $(PAPER_DIR) && rm -f *.aux *.bbl *.blg *.log *.out *.toc
