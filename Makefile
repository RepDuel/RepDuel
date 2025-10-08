.PHONY: backend frontend

backend:
	cd backend && ./start_backend.sh

frontend:
	cd frontend && ./start_frontend.sh
