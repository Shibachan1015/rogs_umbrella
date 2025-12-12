# Find eligible builder and runner images on Docker Hub.
ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.4
ARG DEBIAN_VERSION=bullseye-20240423-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
COPY apps/rogs_comm/mix.exs apps/rogs_comm/
COPY apps/rogs_identity/mix.exs apps/rogs_identity/
COPY apps/shinkanki/mix.exs apps/shinkanki/
COPY apps/shinkanki_web/mix.exs apps/shinkanki_web/
COPY config config

RUN mix deps.get --only $MIX_ENV
RUN mkdir -p config

# copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# copy all apps
COPY apps apps

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Build assets for shinkanki_web
RUN cd apps/shinkanki_web && mix assets.deploy

COPY rel rel
RUN mix release

# start a new build stage
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/rogs_umbrella ./

USER nobody

CMD ["/app/bin/server"]
