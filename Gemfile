source "https://rubygems.org"

ruby "3.2.3"

gem "sinatra",         "~> 4.1"
gem "sinatra-contrib", "~> 4.1"
gem "puma",            "~> 6.6"
gem "pg",              "~> 1.5"
gem "bcrypt",          "~> 3.1"
gem "roo",             "~> 2.10"   # leitura de Excel/CSV
gem "rubyzip",         "~> 2.3"    # ZIP de backups
gem "nokogiri",        "~> 1.18"
gem "rack-protection", "~> 4.1"
gem "webrick",         "~> 1.9"
gem "logger"
gem "rackup",          "~> 2.3"

# ── Novas dependências ────────────────────────────────────────────────────────
gem "dotenv",           "~> 3.1"   # variáveis de ambiente via .env
gem "rufus-scheduler",  "~> 3.9"   # backup automático agendado
gem "google-apis-sheets_v4", "~> 0.40"  # validação de licenças via Google Sheets
gem "googleauth",       "~> 1.11"  # autenticação service account Google

group :development do
  gem "rubocop", require: false
end