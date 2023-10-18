# Who is Regno for?
For those who want to:
- Run your own Monero node
- Run your own p2pool, block explorer, light-wallet server, and/or atomic swap daemon, etc
- Have it all configured by default to work together
- Manage it all either via a script or via a web UI
- Locally build your own docker images from each project's source code, automatically
- Easily keep up with updates
- View live & historical info regarding your node

# What is the goal of Regno?
To enable as many people as possible to run & understand their own Monero node, along with other optional software that is highly complimentary to Monero.

# Prerequesites
- bash
- docker engine

Currently all testing is only done in Linux. It should eventually work on MacOS and in Windows within WSL.

# Usage
Run `./regno.sh setup` to go through the first-time setup wizard, and build any services you want to run.

Run `./regno.sh start` to start.

# What are some pie-in-the-sky features planned for Regno?
- ✅ Modular: only install what you want. If you don't want a particular service, it is not even downloaded.
- ✅ Build & run monerod image from source
- ✅ Build & run p2pool image from source
- 🔧 Build & run p2pool-observer image from source
- ✅ Build & run onion-monero-blockchain-explorer image from source
- 🔧 Build & run monero-lws image from source
- 🔧 Build & run Haveno image from source
- 🔧 Build & run tor image from source
- 🔧 Modular: easy to extend & add more configurable services
- ✅ Live dashboard with node & network info
- 🔧 Modular: Regno UI acts as a central hub for enabled service UIs
- 🔧 Configurable through web UI (can always manage through commandline if you prefer)
- 🔧 Automatic creation of tor hidden services for services where that would be useful
- 🔧 Easy update process, automatically backing up the previous version and allowing rollback if needed.
- 🔧 Easy p2pool setup
- ❔ Optional historical data collection & graphing (connected peers, mempool info, network difficulty / target / hashrate, etc)
- ❔ Setup of atomic swap daemon & UI
- ❔ Run bitcoind + electrum server? (instead of using a public one for atomic swaps)
- ❔ Build & run nerostr image from source

# Tech
- Run within Docker containers, "orchestrate" with docker-compose & scripts
- sqlite to store historical data
- Phoenix LiveView frontend
- Elixir backend for interacting with monerod RPC, and storing historical data in sqlite
- bash for all setup scripts

# Licensing
- MIT
