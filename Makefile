.PHONY: backend frontend build-frontend build-ios run-ios test test-backend test-frontend

backend:
	cd backend && ./start_backend.sh

frontend:
	cd frontend && ./start_frontend.sh

build-frontend:
	git checkout main
	cd frontend && flutter clean && \
	doppler run --project repduel --config prd_frontend -- bash -lc '\
		echo "DBG(build_web): BACKEND_URL=$$BACKEND_URL PUBLIC_BASE_URL=$$PUBLIC_BASE_URL"; \
		flutter build web --release \
		--dart-define=BACKEND_URL=$$BACKEND_URL \
		--dart-define=PUBLIC_BASE_URL=$$PUBLIC_BASE_URL \
		--dart-define=MERCHANT_DISPLAY_NAME=$$MERCHANT_DISPLAY_NAME \
		--dart-define=REVENUE_CAT_APPLE_KEY=$$REVENUE_CAT_APPLE_KEY \
		--dart-define=STRIPE_CANCEL_URL=$$STRIPE_CANCEL_URL \
		--dart-define=STRIPE_PREMIUM_PLAN_ID=$$STRIPE_PREMIUM_PLAN_ID \
		--dart-define=STRIPE_PUBLISHABLE_KEY=$$STRIPE_PUBLISHABLE_KEY \
		--dart-define=STRIPE_SUCCESS_URL=$$STRIPE_SUCCESS_URL \
		--dart-define=PAYMENTS_ENABLED=$$PAYMENTS_ENABLED' && \
	cd .. && \
	git rev-parse --verify web-deploy >/dev/null 2>&1 || git branch web-deploy && \
	git checkout web-deploy && \
	rm -rf deploy && mkdir -p deploy/public && \
	rsync -av --exclude='.*' frontend/build/web/ deploy/public/ && \
	printf '%s\n' 'echo "Using pre-built files"' > deploy/build.sh && \
	chmod +x deploy/build.sh && \
	git add deploy && \
	git commit -m "Built production web assets from main branch" || true && \
	git push origin web-deploy --force-with-lease && \
	git checkout main

build-ios:
	cd frontend && flutter clean && \
	doppler run --project repduel --config prd_frontend -- bash -lc '\
		echo "DBG(build_ipa): BACKEND_URL=$$BACKEND_URL PUBLIC_BASE_URL=$$PUBLIC_BASE_URL"; \
		flutter build ipa --release \
		--dart-define=BACKEND_URL=$$BACKEND_URL \
		--dart-define=PUBLIC_BASE_URL=$$PUBLIC_BASE_URL \
		--dart-define=MERCHANT_DISPLAY_NAME=$$MERCHANT_DISPLAY_NAME \
		--dart-define=REVENUE_CAT_APPLE_KEY=$$REVENUE_CAT_APPLE_KEY \
		--dart-define=STRIPE_CANCEL_URL=$$STRIPE_CANCEL_URL \
		--dart-define=STRIPE_PREMIUM_PLAN_ID=$$STRIPE_PREMIUM_PLAN_ID \
		--dart-define=STRIPE_PUBLISHABLE_KEY=$$STRIPE_PUBLISHABLE_KEY \
		--dart-define=STRIPE_SUCCESS_URL=$$STRIPE_SUCCESS_URL \
		--dart-define=PAYMENTS_ENABLED=$$PAYMENTS_ENABLED'

run-ios:
	cd frontend && \
	DEVICE_FLAG="" && \
	if [ -n "$(DEVICE)" ]; then DEVICE_FLAG="-d $(DEVICE)"; fi && \
	export DEVICE_FLAG && \
	doppler run --project repduel --config prd_frontend -- bash -lc '\
		echo "DBG(run_ios): BACKEND_URL=$$BACKEND_URL PUBLIC_BASE_URL=$$PUBLIC_BASE_URL"; \
		flutter clean; \
		flutter run --release $$DEVICE_FLAG \
		--dart-define=BACKEND_URL=$$BACKEND_URL \
		--dart-define=PUBLIC_BASE_URL=$$PUBLIC_BASE_URL \
		--dart-define=MERCHANT_DISPLAY_NAME=$$MERCHANT_DISPLAY_NAME \
		--dart-define=REVENUE_CAT_APPLE_KEY=$$REVENUE_CAT_APPLE_KEY \
		--dart-define=STRIPE_CANCEL_URL=$$STRIPE_CANCEL_URL \
		--dart-define=STRIPE_PREMIUM_PLAN_ID=$$STRIPE_PREMIUM_PLAN_ID \
		--dart-define=STRIPE_PUBLISHABLE_KEY=$$STRIPE_PUBLISHABLE_KEY \
		--dart-define=STRIPE_SUCCESS_URL=$$STRIPE_SUCCESS_URL \
		--dart-define=PAYMENTS_ENABLED=$$PAYMENTS_ENABLED'

test: test-backend test-frontend

test-backend:
	cd backend && \
	test -d .venv || python3 -m venv .venv && \
	. .venv/bin/activate && \
	python3 -m pip install -U pip && \
	( pip install -r requirements-dev.txt || pip install -r requirements.txt ) && \
	python -m pytest

test-frontend:
	cd frontend && flutter test
