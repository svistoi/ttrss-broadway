FROM elixir:1.10.4-slim as builder
COPY . /opt/ttrss-broadway
WORKDIR /opt/ttrss-broadway
ENV MIX_ENV=prod
RUN mix local.hex --force
RUN mix deps.get && mix compile && mix release

FROM debian:buster-slim as release
WORKDIR /opt/ttrss-broadway
COPY --from=builder /opt/ttrss-broadway/_build/prof/rel/ttrss-broadway .
CMD ["bin/ttrss-broadway", "start"]
