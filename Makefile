SHELL := /bin/bash

COMPOSE := docker compose
RESULTS_DIR := scripts/results
MEASURE_DURATION ?= 30s
DURATION ?= $(MEASURE_DURATION)
COOLDOWN ?= 20            # pausa em segundos após restart
VUS ?= 10
REPETITIONS ?= 10
VUS_LIST ?= 10 50 100

UP_TARGET := $(word 2,$(MAKECMDGOALS))

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Comandos principais:"
	@echo "  make build              Builda as imagens Docker"
	@echo "  make up                 Sobe banco, seed, Laravel e Django"
	@echo "  make up laravel         Sobe Laravel e derruba Django"
	@echo "  make up django          Sobe Django e derruba Laravel"
	@echo "  make down               Para e remove containers do projeto"
	@echo "  make stop               Para containers sem remover"
	@echo ""
	@echo "Banco:"
	@echo "  make db                 Sobe apenas Postgres + seed"
	@echo "  make seed               Executa db/seed.sql novamente"
	@echo "  make db-count           Mostra total de produtos"
	@echo "  make db-shell           Abre psql no banco"
	@echo "  make reset-db           Remove volume do banco e recria tudo"
	@echo ""
	@echo "Testes de API:"
	@echo "  make curl-laravel       Testa http://localhost:8001/api/items"
	@echo "  make curl-django        Testa http://localhost:8002/api/items"
	@echo "  make logs-laravel       Logs do Laravel"
	@echo "  make logs-django        Logs do Django"
	@echo "  make ps                 Lista containers"
	@echo ""
	@echo "Desempenho:"
	@echo "  make k6-laravel VUS=50 MEASURE_DURATION=30s"
	@echo "  make k6-django VUS=50 MEASURE_DURATION=30s"
	@echo "  make bench-laravel      Sobe só Laravel e salva resultado k6"
	@echo "  make bench-django       Sobe só Django e salva resultado k6"
	@echo "  make experiment         Roda Laravel e Django isolados com VUs 10/50/100"
	@echo "  make summary           Gera tabela CSV com medias e desvios por cenario"
	@echo "  make results            Lista arquivos de resultado"
	@echo "  make clean-results      Remove resultados gerados pelo k6"
	@echo ""
	@echo "Variaveis: VUS=$(VUS), MEASURE_DURATION=$(MEASURE_DURATION), REPETITIONS=$(REPETITIONS), VUS_LIST='$(VUS_LIST)'"

.PHONY: build
build:
	$(COMPOSE) build

.PHONY: up
up:
	@if [ "$(UP_TARGET)" = "laravel" ]; then \
		$(MAKE) up-laravel; \
	elif [ "$(UP_TARGET)" = "django" ]; then \
		$(MAKE) up-django; \
	elif [ -z "$(UP_TARGET)" ]; then \
		$(MAKE) up-all; \
	else \
		echo "Uso: make up [laravel|django]"; \
		exit 2; \
	fi

.PHONY: up-all
up-all:
	$(COMPOSE) up -d --build db db-seed laravel-api django-api

.PHONY: up-laravel laravel
up-laravel:
	$(COMPOSE) stop django-api || true
	$(COMPOSE) up -d --build db db-seed laravel-api
laravel:
	@:

.PHONY: up-django django
up-django:
	$(COMPOSE) stop laravel-api || true
	$(COMPOSE) up -d --build db db-seed django-api
django:
	@:

.PHONY: db
db:
	$(COMPOSE) up -d db db-seed

.PHONY: seed
seed:
	$(COMPOSE) up db-seed

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: reset-db
reset-db:
	$(COMPOSE) down -v
	$(COMPOSE) up -d --build db db-seed

.PHONY: ps
ps:
	$(COMPOSE) ps -a

.PHONY: results clean-results
results:
	@find $(RESULTS_DIR) -maxdepth 1 -type f -name '*.json' -print 2>/dev/null | sort || true
	@find $(RESULTS_DIR) -maxdepth 1 -type f -name '*.csv' -print 2>/dev/null | sort || true
clean-results:
	rm -rf $(RESULTS_DIR)

.PHONY: summary
summary:
	./scripts/summarize_results.sh

.PHONY: logs logs-laravel logs-django logs-db logs-seed
logs:
	$(COMPOSE) logs -f --tail=100
logs-laravel:
	$(COMPOSE) logs -f --tail=100 laravel-api
logs-django:
	$(COMPOSE) logs -f --tail=100 django-api
logs-db:
	$(COMPOSE) logs -f --tail=100 db
logs-seed:
	$(COMPOSE) logs --tail=100 db-seed

.PHONY: db-shell db-count
db-shell:
	$(COMPOSE) exec db psql -U user -d perf_db
db-count:
	$(COMPOSE) exec -T db psql -U user -d perf_db -c "SELECT COUNT(*) AS total_items FROM items;"

.PHONY: curl-laravel curl-django
curl-laravel:
	curl -s http://localhost:8001/api/items
curl-django:
	curl -s http://localhost:8002/api/items

.PHONY: k6-laravel k6-django
k6-laravel: up-laravel
	./scripts/run_k6_service.sh laravel-api http://localhost:8001 \
		--env FRAMEWORK=laravel \
		--env VUS=$(VUS) \
		--env MEASURE_DURATION=$(MEASURE_DURATION) \
		/scripts/load_test.js

k6-django: up-django
	./scripts/run_k6_service.sh django-api http://localhost:8002 \
		--env FRAMEWORK=django \
		--env VUS=$(VUS) \
		--env MEASURE_DURATION=$(MEASURE_DURATION) \
		/scripts/load_test.js

.PHONY: bench-laravel bench-django
bench-laravel: up-laravel
	mkdir -p $(RESULTS_DIR)
	./scripts/run_k6_service.sh laravel-api http://localhost:8001 \
		--env FRAMEWORK=laravel \
		--env REPETITION=1 \
		--env VUS=$(VUS) \
		--env MEASURE_DURATION=$(DURATION) \
		--env SUMMARY_FILE=/scripts/results/laravel_vu$(VUS).json \
		/scripts/load_test.js

bench-django: up-django
	mkdir -p $(RESULTS_DIR)
	./scripts/run_k6_service.sh django-api http://localhost:8002 \
		--env FRAMEWORK=django \
		--env REPETITION=1 \
		--env VUS=$(VUS) \
		--env MEASURE_DURATION=$(DURATION) \
		--env SUMMARY_FILE=/scripts/results/django_vu$(VUS).json \
		/scripts/load_test.js

.PHONY: experiment experiment-laravel experiment-django
experiment: experiment-laravel experiment-django
	@echo "Experimento concluido. Resultados em $(RESULTS_DIR)"

experiment-laravel: up-laravel
	mkdir -p $(RESULTS_DIR) && chmod 777 $(RESULTS_DIR)
	@total=$$(($(words $(VUS_LIST)) * $(REPETITIONS))); current=0; \
	for vu in $(VUS_LIST); do \
		for rep in $$(seq 1 $(REPETITIONS)); do \
			current=$$((current + 1)); \
			echo ""; \
			echo "[$$current/$$total] Laravel | VUs: $$vu | Repeticao: $$rep"; \
			$(COMPOSE) restart laravel-api; \
			sleep $(COOLDOWN); \
			./scripts/run_k6_service.sh laravel-api http://localhost:8001 \
				--env FRAMEWORK=laravel \
				--env REPETITION=$$rep \
				--env VUS=$$vu \
				--env MEASURE_DURATION=$(MEASURE_DURATION) \
				--env SUMMARY_FILE=/scripts/results/laravel_vu$${vu}_rep$${rep}.json \
				/scripts/load_test.js; \
		done; \
	done

experiment-django: up-django
	mkdir -p $(RESULTS_DIR) && chmod 777 $(RESULTS_DIR)
	@total=$$(($(words $(VUS_LIST)) * $(REPETITIONS))); current=0; \
	for vu in $(VUS_LIST); do \
		for rep in $$(seq 1 $(REPETITIONS)); do \
			current=$$((current + 1)); \
			echo ""; \
			echo "[$$current/$$total] Django | VUs: $$vu | Repeticao: $$rep"; \
			$(COMPOSE) restart django-api; \
			sleep $(COOLDOWN); \
			./scripts/run_k6_service.sh django-api http://localhost:8002 \
				--env FRAMEWORK=django \
				--env REPETITION=$$rep \
				--env VUS=$$vu \
				--env MEASURE_DURATION=$(MEASURE_DURATION) \
				--env SUMMARY_FILE=/scripts/results/django_vu$${vu}_rep$${rep}.json \
				/scripts/load_test.js; \
		done; \
	done
