# Rezepte von openGym. Werkzeuge kommen aus der devShell, nicht global.

default:
    @just --list

# API lokal auf Port 3000, Daten unter ./data
server:
    cd api && npm install && DATA_DIR=../data npm start

# Oberfläche mit Hot Reload (http://localhost:5173), /api geht an :3000
web:
    cd frontend && npm install && npm run dev

# Tests von Oberfläche, API und MCP-Server
test:
    cd frontend && npm install && npm test
    cd api && npm install && npm test
    cd mcp && npm install && npm test

# Pakete bauen, wie sie das NixOS-Modul nutzt
build:
    nix build .#frontend .#api

# Nach geänderten package-lock.json: neue Hashes für nix/*.nix
hashes:
    prefetch-npm-deps frontend/package-lock.json
    prefetch-npm-deps api/package-lock.json

ci: test build
