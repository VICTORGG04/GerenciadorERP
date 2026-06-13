require 'dotenv'
require 'pg'
require 'bcrypt'

Dotenv.load('/etc/gerenciador-erp/.env', '.env')

host     = ENV.fetch('DB_HOST', '127.0.0.1')
port     = ENV.fetch('DB_PORT', '5432')
dbname   = ENV.fetch('DB_NAME', 'gerenciador_estoque')
user     = ENV.fetch('DB_USER', 'gerenciador_erp')
password = ENV.fetch('DB_PASSWORD', '')

begin
  DB = PG.connect(host: host, port: port, dbname: dbname, user: user, password: password)
rescue PG::ConnectionBad => e
  if e.message.include?('does not exist')
    puts "Banco '#{dbname}' não encontrado. Criando..."
    admin = PG.connect(host: host, port: port, dbname: 'postgres', user: user, password: password)
    admin.exec("CREATE DATABASE #{dbname}")
    admin.close
    DB = PG.connect(host: host, port: port, dbname: dbname, user: user, password: password)
  else
    puts "Erro ao conectar: #{e.message}"
    puts "Verifique se o PostgreSQL está rodando e as credenciais em .env"
    exit 1
  end
end

puts "Conectado ao banco #{dbname}!"

DB.exec("CREATE SCHEMA IF NOT EXISTS public")

# =========================
# USERS
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'operator',
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# =========================
# CATEGORIES
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    color VARCHAR(50) DEFAULT '#6366f1',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# =========================
# PRODUCTS
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(100) UNIQUE,
    category_id INTEGER REFERENCES categories(id),
    quantity INTEGER DEFAULT 0,
    min_quantity INTEGER DEFAULT 0,
    price NUMERIC(10,2) DEFAULT 0,
    cost NUMERIC(10,2),
    unit VARCHAR(20) DEFAULT 'un',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# =========================
# STOCK MOVEMENTS
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS stock_movements (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    kind VARCHAR(50) NOT NULL,
    quantity INTEGER NOT NULL,
    reason TEXT,
    reference VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# =========================
# ORDERS
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    reference VARCHAR(255) UNIQUE NOT NULL,
    customer VARCHAR(255),
    notes TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    total NUMERIC(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# =========================
# ORDER ITEMS
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    subtotal NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);
SQL

# =========================
# AUDIT LOGS
# =========================
DB.exec <<~SQL
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    user_name VARCHAR(255) DEFAULT 'Sistema',
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id INTEGER,
    details TEXT,
    ip VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

puts "Tabelas criadas!"

# =========================
# SEED ADMIN USER
# =========================
require 'bcrypt'
admin_hash = BCrypt::Password.create('admin123', cost: 12)
DB.exec_params(
  "INSERT INTO users (name, email, password_hash, role)
   VALUES ($1, $2, $3, $4)
   ON CONFLICT (email) DO NOTHING",
  ['Administrador', 'admin@gerenciador.local', admin_hash, 'admin']
)
puts "Usuario admin criado (email: admin@gerenciador.local / senha: admin123)"

puts "Banco configurado com sucesso!"
