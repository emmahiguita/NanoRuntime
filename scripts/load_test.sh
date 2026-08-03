#!/bin/bash
# scripts/load_test.sh — Prueba de carga para NanoAI API
# Uso: ./scripts/load_test.sh [ENDPOINT] [REQUESTS] [CONCURRENCY]

set -euo pipefail

ENDPOINT="${1:-http://localhost:8080/api/chat}"
NUM_REQUESTS="${2:-100}"
CONCURRENT="${3:-10}"

echo "======================================"
echo " NanoAI Load Test"
echo "======================================"
echo "Endpoint:     $ENDPOINT"
echo "Requests:     $NUM_REQUESTS"
echo "Concurrency:  $CONCURRENT"
echo "======================================"
echo ""

# Check if 'hey' is installed
if ! command -v hey &> /dev/null; then
    echo "Error: 'hey' is not installed."
    echo "Install it from: https://github.com/rakyll/hey"
    echo ""
    echo "Or use curl-based fallback..."
    echo ""

    # Fallback: simple sequential test with curl
    echo "Running $NUM_REQUESTS sequential requests..."
    START_TIME=$(date +%s)

    for i in $(seq 1 "$NUM_REQUESTS"); do
        curl -s -X POST "$ENDPOINT" \
            -H "Content-Type: application/json" \
            -d '{"prompt": "Hello, how are you?"}' \
            > /dev/null

        if [ $((i % 10)) -eq 0 ]; then
            echo "  Progress: $i/$NUM_REQUESTS"
        fi
    done

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo "Completed $NUM_REQUESTS requests in $DURATION seconds"
    if [ "$DURATION" -gt 0 ]; then
        RPS=$((NUM_REQUESTS / DURATION))
        echo "Average: $RPS requests/second"
    fi
    exit 0
fi

# Run hey load test
hey -n "$NUM_REQUESTS" -c "$CONCURRENT" \
    -m POST \
    -H "Content-Type: application/json" \
    -d '{"prompt": "Hello, how are you?"}' \
    "$ENDPOINT"

echo ""
echo "Load test completed."
