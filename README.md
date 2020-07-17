- [Introduction](#introduction)
- [Installation](#installation)
- [Appendix](#appendix)
  - [TODO](#todo)
  - [Issue with HTTPoison and hackney](#issue-with-httpoison-and-hackney)
  - [Reference Elixir GenStage/Broadway](#reference-elixir-genstagebroadway)
  - [Reference TT-RSS](#reference-tt-rss)

# Introduction

This is a learning project to examine development with Elixir,
[GenStage](https://hexdocs.pm/gen_stage/GenStage.html),
[Broadway](https://hexdocs.pm/broadway/Broadway.html) message processing, as
well as working with BEAM.

I manage all my RSS subscriptions - articles, software releases, youtube and
podcasts using [TT-RSS](https://tt-rss.org/).

In order to make the podcasts available on my phone and multiple
dekstops/laptops for listening, I download the "un-read" podcasts, and use
[SyncThing](https://syncthing.net/) to share the files. After listening, I
just delete the file which removes the podcast. This is different from
typical setups of just using AntennaPod (or whatever apple equivalent) and
just using your phone.

On download, I re-encode from typical mp3, to opus and reduce the bitrate.
This reduces file size by 2x, with imperceivable (to me) quality reduction.

# Installation

Install elixir 10.3, and erlang 22.x or newer.  Compile
```
env MIX_ENV=prod mix release
```

Create config.yaml with accounts to query various tt-rss endpoints
```
accounts:
  - username: <username>
    password: <password>
    output: /destination/directory/to/save
    api: http://tt-rss.network.org/api/
```

Run
```
_build/prod/rel/ttrss_broadway/bin/ttrss_broadway start
```

# Appendix

## TODO

- profile
- examine telemetry feature of broadway
- live-reload
- config.exs with more options

## Issue with HTTPoison and hackney

https://elixirforum.com/t/genstage-unexpected-ssl-closed-message/9688

For now I used httpc for download.

TODO: Look at Mint.HTTP

## Reference Elixir GenStage/Broadway

- https://www.youtube.com/watch?v=IzFmNQGzApQ
- https://blog.jola.dev/push-based-genstage
- http://www.codinsanity.eu/2019/11/16/push-based-genstage-with-acknowledgement.html
- https://elixirforum.com/t/confusion-about-how-genstage-demand-mechanism-works/26670

## Reference TT-RSS

- https://git.tt-rss.org/git/tt-rss/wiki/ApiReference
