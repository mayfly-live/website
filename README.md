# mayfly

Scripts for managing DDEV preview environments on [mayfly.live](https://mayfly.live).

## preview.sh

Run from your TYPO3 project root to trigger deploys locally without going through GitLab CI:

```bash
# one-liner
curl -fsSL get.mayfly.live/preview.sh | bash

# or save locally
curl -fsSL get.mayfly.live/preview.sh -o preview.sh && chmod +x preview.sh

./preview.sh deploy
./preview.sh stop
DB_FILE=./dump.sql.gz ./preview.sh seed
```

Auto-detects the project name from `.ddev/config.yaml`, the current git branch, and your SSH key.
