#!/usr/bin/env bash
# bean-check the live ledger. Exit 0 = clean.
exec /usr/local/bin/docker exec fava-custom bean-check /data/main.beancount
