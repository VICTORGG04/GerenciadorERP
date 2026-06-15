FROM ruby:3.3-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    libpq-dev postgresql-client curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock .env.example ./
RUN gem install bundler && bundle install --jobs 4 --retry 3

COPY . .

RUN mkdir -p logs storage backups

EXPOSE 4568

ENV APP_HOST=0.0.0.0
ENV APP_PORT=4568
ENV RACK_ENV=production

CMD ["bash", "-c", "bundle exec ruby app.rb"]
