#!/bin/bash
# This script should be run from the project's root directory.
# It gets new books and exits without starting an interactive session.
docker-compose run --rm app ruby nls_bard.rb -g 30 exit
