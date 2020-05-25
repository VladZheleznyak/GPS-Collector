FROM ruby:2.6-alpine

ENV BUILD_PACKAGES="curl-dev ruby-dev build-base bash" \
    DEV_PACKAGES="zlib-dev libxml2-dev libxslt-dev tzdata yaml-dev postgresql-dev" \
    RUBY_PACKAGES="ruby-json yaml"

# Update and install base packages and nokogiri gem that requires a
# native compilation
RUN apk update && \
    apk upgrade && \
    apk add --update\
    $BUILD_PACKAGES \
    $DEV_PACKAGES \
    $RUBY_PACKAGES && \
    rm -rf /var/cache/apk/* && \
    gem install bundler

WORKDIR /home/app

# install and cache gems
COPY Gemfile Gemfile.lock ./
RUN bundle config --delete bin && \
    bundle install --no-binstubs

# on each `docker-compose up`:
# 0. wait until DB up and running
# 1. try to recreate a table
# 2. run YARD server on http://localhost:8808/
# 3. run RACK server on http://localhost:9292/
CMD until nc -z db 5432; do echo "Waiting for PG..."; sleep 1; done && \
    ruby -e "require './lib/db_wrapper'; DbWrapper.exec_params('CREATE TABLE  IF NOT EXISTS points (id serial primary key, point geography(POINT))')" && \
    yard server --reload --bind 0.0.0.0 --daemon && \
    rackup config.ru -o 0.0.0.0

EXPOSE 8808 9292