require_relative 'base'
require 'roo'
require 'csv'

class Import
  extend BaseModel

  # Colunas esperadas na planilha (case-insensitive)
  REQUIRED_COLS = %w[nome preco custo quantidade].freeze
  OPTIONAL_COLS = %w[sku categoria quantidade_minima unidade descricao].freeze

  Result = Struct.new(:success, :created, :skipped, :errors, keyword_init: true)

  # ── Importar arquivo ─────────────────────────────────────────────────────
  # Aceita: .xlsx, .xls, .csv, .ods
  # Retorna um Result com o resumo
  def self.from_file(filepath, user_id: nil)
    ext = File.extname(filepath).downcase

    rows = if ext == '.csv'
      parse_csv(filepath)
    else
      parse_spreadsheet(filepath)
    end

    created  = 0
    skipped  = 0
    errors   = []

    rows.each_with_index do |row, i|
      line = i + 2  # linha real na planilha (cabeçalho = linha 1)

      # Validações obrigatórias
      name = row['nome']&.to_s&.strip
      if name.nil? || name.empty?
        errors << "Linha #{line}: coluna 'nome' está vazia"
        skipped += 1
        next
      end

      price = parse_decimal(row['preco'])
      if price.nil?
        errors << "Linha #{line} (#{name}): 'preco' inválido — use ponto ou vírgula como decimal"
        skipped += 1
        next
      end

      cost     = parse_decimal(row['custo'])     || 0.0
      qty      = parse_integer(row['quantidade']) || 0
      min_qty  = parse_integer(row['quantidade_minima']) || 0
      sku      = row['sku']&.to_s&.strip.presence
      unit     = row['unidade']&.to_s&.strip.presence
      desc     = row['descricao']&.to_s&.strip.presence

      # Categoria — busca ou ignora
      cat_id = nil
      cat_name = row['categoria']&.to_s&.strip
      if cat_name && !cat_name.empty?
        result = db.exec_params(
          "SELECT id FROM categories WHERE LOWER(name) = LOWER($1) LIMIT 1", [cat_name]
        )
        cat_id = result[0]['id'].to_i if result.ntuples > 0
      end

      # Verifica duplicata por SKU (se informado)
      if sku
        dup = db.exec_params("SELECT id FROM products WHERE sku = $1", [sku])
        if dup.ntuples > 0
          errors << "Linha #{line} (#{name}): SKU '#{sku}' já existe — ignorado"
          skipped += 1
          next
        end
      end

      db.exec_params(
        "INSERT INTO products (name, sku, price, cost, quantity, min_quantity, unit, description, category_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)",
        [name, sku, price, cost, qty, min_qty, unit, desc, cat_id]
      )
      created += 1

    rescue => e
      errors << "Linha #{line}: erro inesperado — #{e.message}"
      skipped += 1
    end

    Result.new(success: errors.empty?, created: created, skipped: skipped, errors: errors)
  end

  # ── Gerar planilha modelo para download ──────────────────────────────────
  def self.template_csv
    header = %w[nome sku categoria preco custo quantidade quantidade_minima unidade descricao]
    example = ['Produto Exemplo', 'SKU-001', 'Eletrônicos', '99.90', '45.00', '10', '2', 'un', 'Descrição opcional']
    [header, example].map { |row| row.join(';') }.join("\n")
  end

  private

  def self.parse_spreadsheet(path)
    wb    = Roo::Spreadsheet.open(path)
    sheet = wb.sheet(0)
    rows  = sheet.to_a
    return [] if rows.size < 2

    # Primeira linha = cabeçalho
    header = rows[0].map { |h| h.to_s.strip.downcase.gsub(/[áàãâ]/, 'a').gsub(/[éê]/, 'e').gsub(/[íi]/, 'i').gsub(/[óôõ]/, 'o').gsub(/[úü]/, 'u').gsub(/\s+/, '_') }

    rows[1..].map do |row|
      header.each_with_index.with_object({}) do |(col, idx), h|
        h[col] = row[idx]
      end
    end.reject { |r| r.values.all?(&:nil?) }
  end

  def self.parse_csv(path)
    rows = []
    CSV.foreach(path, headers: true, col_sep: detect_separator(path),
                encoding: 'UTF-8', liberal_parsing: true) do |row|
      normalized = row.to_h.transform_keys { |k| k.to_s.strip.downcase }
      rows << normalized
    end
    rows
  rescue CSV::MalformedCSVError => e
    raise "Arquivo CSV inválido: #{e.message}"
  end

  def self.detect_separator(path)
    first_line = File.open(path, 'r:UTF-8') { |f| f.readline rescue '' }
    first_line.count(';') > first_line.count(',') ? ';' : ','
  end

  def self.parse_decimal(val)
    return nil if val.nil?
    str = val.to_s.strip.gsub(/[R$\s]/, '').gsub(',', '.')
    Float(str)
  rescue ArgumentError
    nil
  end

  def self.parse_integer(val)
    return nil if val.nil?
    Integer(val.to_s.strip)
  rescue ArgumentError
    nil
  end
end
