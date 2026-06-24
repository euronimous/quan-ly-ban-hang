FROM ruby:2.5.1

# ── Fix apt: Debian "stretch" (this image's base) is EOL and moved to archive ──
RUN set -eux; \
    sed -i '/stretch-updates/d' /etc/apt/sources.list; \
    sed -i 's|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g' /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# ── System packages ───────────────────────────────────────────────────────────
#   default-libmysqlclient-dev : to build the mysql2 gem
#   default-mysql-client       : the `mysql` CLI used to import the geo data
RUN apt-get -o Acquire::AllowInsecureRepositories=true update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
      default-libmysqlclient-dev \
      default-mysql-client \
      shared-mime-info \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 12 (official binary tarball) + Yarn ───────────────────────────────
ENV NODE_VERSION=12.22.12
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      amd64) NODE_ARCH=x64 ;; \
      arm64) NODE_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm /tmp/node.tar.xz; \
    npm install -g yarn

WORKDIR /app

# ── Ruby gems (matches Gemfile.lock BUNDLED WITH) ─────────────────────────────
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 1.17.3 \
    && bundle _1.17.3_ lock --update mimemagic \
    && bundle _1.17.3_ install --jobs 4 --retry 3

# ── JS packages ───────────────────────────────────────────────────────────────
COPY package.json yarn.lock ./
RUN yarn install

COPY . .

EXPOSE 3000 3035
