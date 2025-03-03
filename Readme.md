# Rahat Setup
## Clone Rahat Setup Repo:
```sh
git clone 
```

## Prerequisites Tools:
- Docker.

## Core Repositories:
- There are two core Repositories:
    - Rahat UI: [https://github.com/rahataid/rahat-ui](https://github.com/rahataid/rahat-ui/)
        - Rahat UI contains two projects, but we will setup rahat-ui only for now.

    - Rahat Platform: [https://github.com/rahataid/rahat-platform](https://github.com/rahataid/rahat-platform)
        - Rahat Platform contains two projects:
            - rahat
            - beneficiary


- There are many projects as microservices like aa, rp and so on. 

## Setup Current Directory:
```sh
export CWD=${PWD}
```

## Clone Repositories:
- Command:
    ```sh
    git clone https://github.com/rahataid/rahat-platform.git && cd rahat-platform && git checkout dev && pnpm install && pnpx prisma generate && cd $CWD
    git clone https://github.com/rahataid/rahat-ui.git && cd rahat-ui && git checkout dev && pnpm install && cd $CWD
    ```

## Setup Local Development:
- Command: 
    ```sh
    cd docker 
    cp .env.platform.example .env.platform
    cp .env.rahat-ui.example .env.rahat-ui
    cd $CWD
    ```

- Setup `.env.platform` and `.env.rahat-ui` according to your needs.
- Once `.env.platform` is setup, copy it into `rahat-platform`.
    ```sh
    cp docker/.env.platform rahat-platform/.env
    ```
- Start Application:
    ```sh
    cd docker
    docker compose -f docker-compose-local.yaml up -d --build
    ```

- Run Prisma Migration:
    ```sh
    cd $CWD
    cd rahat-platform
    pnpx prisma migrate dev --skip-seed
    ```