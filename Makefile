.PHONY: backend frontend build-frontend build-ios-ipa run-ios-release

DART_DEFINES := \
        --dart-define=BACKEND_URL=$$BACKEND_URL \
        --dart-define=PUBLIC_BASE_URL=$$PUBLIC_BASE_URL \
        --dart-define=MERCHANT_DISPLAY_NAME=$$MERCHANT_DISPLAY_NAME \
        --dart-define=REVENUE_CAT_APPLE_KEY=$$REVENUE_CAT_APPLE_KEY \
        --dart-define=STRIPE_CANCEL_URL=$$STRIPE_CANCEL_URL \
        --dart-define=STRIPE_PREMIUM_PLAN_ID=$$STRIPE_PREMIUM_PLAN_ID \
        --dart-define=STRIPE_PUBLISHABLE_KEY=$$STRIPE_PUBLISHABLE_KEY \
        --dart-define=STRIPE_SUCCESS_URL=$$STRIPE_SUCCESS_URL \
        --dart-define=PAYMENTS_ENABLED=$$PAYMENTS_ENABLED

backend:
	cd backend && ./start_backend.sh

frontend:
	cd frontend && ./start_frontend.sh

build-frontend:
	git checkout main
	cd frontend && flutter clean && \
		doppler run --project repduel --config prd_frontend -- \
		flutter build web --release $(DART_DEFINES) && \
	cd ..
	git rev-parse --verify web-deploy >/dev/null 2>&1 || git branch web-deploy
	git checkout web-deploy
	rm -rf deploy
	mkdir -p deploy/public
	rsync -av --exclude='.*' frontend/build/web/ deploy/public/
	printf '%s\n' 'echo "Using pre-built files"' > deploy/build.sh
	chmod +x deploy/build.sh
	git add deploy
	git commit -m "Built production web assets from main branch" || true
	git push origin web-deploy --force-with-lease
	git checkout main

build-ios-ipa:
	cd frontend && flutter clean && \
		doppler run --project repduel --config prd_frontend -- \
		flutter build ipa --release $(DART_DEFINES)

run-ios-release:
	cd frontend && \
		DEVICE_FLAG="" && \
		if [ -n "$(DEVICE)" ]; then DEVICE_FLAG="-d $(DEVICE)"; fi && \
		doppler run --project repduel --config prd_frontend -- \
		flutter run --release $$DEVICE_FLAG $(DART_DEFINES)

