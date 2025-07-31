docker compose down --remove-orphans
docker rmi nls_bard-app-backup
docker tag nls_bard-app nls_bard-app-backup
docker compose up --build -d
# docker compose exec app /bin/bash