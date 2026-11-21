
#!/bin/bash
set -o pipefail

COMPOSE_FILE="docker-compose.yml"

UP_ERRS="/tmp/up-errs"
DOWN_ERRS="/tmp/down-errs"
STATUS_ERRS="/tmp/status-errs"
TAIL_LOGS="/tmp/tail-logs"

usage() {
    printf "Usage: %s <subcommand>\n" "$0"
    printf "Subcommands:\n"
    printf "  up      Start the stack\n"
    printf "  down    Stop the stack\n"
    printf "  status  Show service health\n"
    printf "  logs    Tail API logs\n"
    printf "  smoke   Run basic API checks\n"
    printf "  clear   Remove temporary files\n"
}


up() {
    if ! docker compose -f "$COMPOSE_FILE" up -d; then
        echo "Compose up failed!"
        return 1
    fi

    local running
    running=$(docker compose -f "$COMPOSE_FILE" ps --status running --services)

    if [[ -z "$running" ]]; then
        echo "ERROR: Stack failed to start. No running services found!"
        docker compose -f "$COMPOSE_FILE" ps -a
        return 1
    fi

    echo -e "Compose stack started successfully!\nRunning services:"
    echo "$running"
}

down() {
    if ! docker compose -f "$COMPOSE_FILE" down 2>"$DOWN_ERRS"; then
        echo "Compose down failed:"
        cat "$DOWN_ERRS"
        return 1
    fi

    echo "Compose down successful!"
}

status() {
    local output

    if ! output=$(docker compose -f "$COMPOSE_FILE" ps --status running); then
        echo "Failed to retrieve stack status"
        return 1
    fi

    if [[ -z "$output" || "$(echo "$output" | wc -l)" -le 1 ]]; then
        echo "Stack is not up! Run: ./scripts/ops.sh up"
        return 0
    fi

    echo "$output"
}


logs() {
    if ! docker compose -f "$COMPOSE_FILE" logs \
        backend --tail=50 >"$TAIL_LOGS" 2>&1; then
        echo "Failed to retrieve logs:"
        cat "$TAIL_LOGS"
        return 1
    fi

    echo "------ Last 50 lines: --------"
    cat "$TAIL_LOGS"
}

smoke() {
    if [[ ! -f .env ]]; then
        echo ".env file not found"
        return 1
    fi

    source .env

    if [[ -z "${PORT:-}" ]]; then
        echo "PORT is not configured"
        return 1
    fi

    local BAD=0
    local status
    local endpoint

    # GET checks
    for endpoint in health users notifications; do
        status=$(curl -sS -o /dev/null -w "%{http_code}" \
            --max-time 2 "http://localhost:${PORT}/${endpoint}")

        if [[ $? -ne 0 || "$status" != "200" ]]; then
            echo "/${endpoint} -> FAILED ($status)"
            ((BAD++))
        else
            echo "/${endpoint} -> OK ($status)"
        fi
    done

    # POST checks
    for endpoint in notifications users; do
        status=$(curl -sS -o /dev/null -w "%{http_code}" \
            --max-time 2 \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"somekey":"somevalue"}' \
            "http://localhost:${PORT}/${endpoint}")

        if [[ $? -ne 0 || ! "$status" =~ ^2[0-9][0-9]$ ]]; then
            echo "POST /${endpoint} -> FAILED ($status)"
            ((BAD++))
        else
            echo "POST /${endpoint} -> OK ($status)"
        fi
    done

    if [[ "$BAD" -eq 0 ]]; then
        echo "All smoke tests passed!"
        return 0
    else
        echo "Found $BAD errors!"
        return 1
    fi
}

cleanup() {
    rm -f "$UP_ERRS" "$DOWN_ERRS" \
        "$STATUS_ERRS" "$TAIL_LOGS"
    echo "Temporary files removed."
}

case "${1:-}" in
    up) up ;;
    down) down ;;
    status) status ;;
    logs) logs ;;
    smoke) smoke ;;
    clear) cleanup ;;
    *) usage; exit 1 ;;
esac
