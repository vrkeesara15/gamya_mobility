# Alternative: serve the admin web build from Cloud Run instead of a GCS bucket.
#   flutter build web --release --dart-define=API_BASE_URL=...   (in apps/admin_web)
#   docker build -f infra/nginx.Dockerfile -t gamya-admin-web apps/admin_web
FROM nginx:1.27-alpine
COPY build/web /usr/share/nginx/html
RUN printf 'server { listen 8080; root /usr/share/nginx/html; index index.html; location / { try_files $uri $uri/ /index.html; } location ~* \\.(js|css|wasm|png|jpg|svg|woff2?)$ { expires 7d; add_header Cache-Control "public"; } }' > /etc/nginx/conf.d/default.conf
EXPOSE 8080
