# RepDuel marketing landing page

The Flutter web frontend now includes a dedicated marketing experience inspired by the visual language of citadel.com. The page
lives at the root route (`/`) and is served on **repduel.com** and **www.repduel.com** in production.

## Page structure

The landing experience is implemented in `frontend/lib/features/landing/screens/landing_page_screen.dart`. It provides:

- A glassmorphism navigation bar with calls to action for login and registration.
- A hero section with animated gradient accents, programme highlights, and high-level platform statistics.
- Narrative sections that cover the platform mission, technology differentiators, culture, and recruiting messaging.
- A full-width call-to-action card and footer that link back into the authenticated RepDuel application.

All sections are responsive down to tablet layouts and rely solely on Flutter widgets—no additional assets are required.

## Preview locally

```bash
cd frontend
flutter run -d chrome --web-renderer canvaskit
```

The command above launches the marketing page and the rest of the application at `http://localhost:7357/`. Navigate to `/` to view the
landing content and to `/login` or `/ranked` to confirm routing into the core product flows.

## Deploy to repduel.com

1. Merge the landing page changes into `main`. This automatically triggers the **Deploy Web** GitHub Actions workflow.
2. The workflow builds the Flutter web bundle with production secrets and publishes it to the Render static site backing `repduel.com`.
3. After the workflow succeeds, verify the rollout:
   - `https://www.repduel.com/` should render the new landing page.
   - `https://www.repduel.com/login` and `/ranked` should still route correctly into the application shell.
4. (Optional) If the Render deploy hook needs to be retriggered manually, run the `Deploy Web` workflow from the GitHub Actions tab.

### Server-side snapshot (Hetzner fallback)

If you are bypassing Render and deploying directly to the Hetzner VPS:

```bash
ssh deploy@178.156.201.92
cd repduel
./tools/redeploy.sh
```

The script pulls the latest `main`, rebuilds the backend container, and reloads Caddy. Because the static files are served from
`/var/www/repduel`, once Caddy reloads the new landing page is immediately available on `repduel.com`.

## Ongoing maintenance

- Keep the messaging aligned with current product positioning. Update copy in the landing page widget file.
- Use the GoRouter helpers (`context.go('/login')`, etc.) to connect new calls to action back to existing routes.
- When adding imagery or assets, register them in `pubspec.yaml` and include web-friendly formats (WebP/SVG).
- Run `flutter analyze` before committing changes to ensure the landing widgets remain lint-clean.
