
COMPOSE_FILE := docker-compose.yml
OPS := ./scripts/ops.sh

.PHONY: up down status logs smoke clear

up:
	$(OPS) up

down:
	$(OPS) down

status:
	$(OPS) status

logs:
	$(OPS) logs

smoke:
	$(OPS) smoke

clear:
	$(OPS) clear
