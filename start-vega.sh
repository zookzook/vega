#!/bin/zsh

echo "Please provide Client-ID, Client-Secret for Github OAUTH-API"

export GITHUB_CLIENT_ID=""
export GITHUB_CLIENT_SECRET=""
export GITHUB_REDIRECT_URI="http://lvh.me:4000/auth/github/callback"

export PORT=4000
iex --name a@127.0.0.1 -S mix phx.server

