docker-compose down --remove-orphans
docker rmi nls_bard-app
docker-compose up --build -d
# docker-compose exec app /bin/bash