# Windowpane
# TODO list after getting domain
1. After deploying, the webhook url registered in Mux settings needs to be changed
2. the webhook for stripe also needs to be changed
3. Consider premium or plus video quality (it will be needed for quality videos)
4. Need to change the creator cut algorithm to be affected by duration
5. need an How-to guide for streamers
6. i think steam cash formula for estimating tax + fees might be incorrect
7. FUTURE - setting up a staging environment (2 separate fly.tomls for 2 separate apps. codebases for prod and stage running separately but 1 instance is enough for stage app since not meant to have traffic)


This command finds all dynamic class names that tailwind tries to purge. must be added to safelist in tailwind.config.js
grep -roh 'class=["'\''][^"'\''"]*["'\'']' lib/   | sed 's/class=["'\'']//;s/["'\'']$//'   | tr ' ' '\n'   | sort -u   | awk '{printf "\"%s\", ", $0}'   | sed 's/, $/\n/' | xclip -selection clipboard

to do premieres, premiere date in project table is already indexed so it should be easy to do quick retrieval

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

To forward stripe webhooks to local dev server, do:
  * stripe listen --forward-to windowpane.tv:4000/stripe/webhook

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
