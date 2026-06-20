#!/usr/bin/env ruby
# frozen_string_literal: true

# Cria produtos e preços no Stripe para o GerenciadorERP
# Uso: ruby scripts/setup_stripe_prices.rb
# Requer: STRIPE_SECRET_KEY no ambiente

require 'dotenv'
require 'stripe'
require 'fileutils'

env_path = File.expand_path('../.env', __dir__)
if File.exist?(env_path)
  Dotenv.load(env_path)
end

unless ENV['STRIPE_SECRET_KEY']
  puts "ERRO: STRIPE_SECRET_KEY não definida."
  puts "Adicione ao .env ou export e tente novamente."
  exit 1
end

  Stripe.api_key = ENV['STRIPE_SECRET_KEY']

PRODUCTS = {
  gold: {
    name: 'Gold',
    description: 'Até 500 produtos e 3 usuários',
    prices: {
      monthly:  { amount: 1900, interval: 'month', interval_count: 1 },
      semiannual: { amount: 9700, interval: 'month', interval_count: 6 },
      lifetime: { amount: 29700, interval: nil }
    }
  },
  platinum: {
    name: 'Platinum',
    description: 'Produtos e usuários ilimitados',
    prices: {
      monthly:     { amount: 3900, interval: 'month', interval_count: 1 },
      semiannual:  { amount: 19_700, interval: 'month', interval_count: 6 },
      lifetime:    { amount: 59_700, interval: nil }
    }
  },
  enterprise: {
    name: 'Enterprise',
    description: 'Ilimitado + whitelabel + código fonte',
    prices: {
      monthly:     { amount: 8900, interval: 'month', interval_count: 1 },
      semiannual:  { amount: 44_900, interval: 'month', interval_count: 6 },
      lifetime:    { amount: 149_700, interval: nil }
    }
  }
}.freeze

puts "Criando produtos e preços no Stripe..."
puts

env_output = []

PRODUCTS.each do |key, product|
  puts "--- #{product[:name]} ---"

  stripe_prod = Stripe::Product.create(
    name: product[:name],
    description: product[:description]
  )
  puts "  Produto criado: #{stripe_prod.id}"

  product[:prices].each do |interval_key, price_data|
    params = {
      product: stripe_prod.id,
      currency: 'brl',
      unit_amount: price_data[:amount]
    }

    if price_data[:interval]
      params[:recurring] = {
        interval: price_data[:interval],
        interval_count: price_data[:interval_count]
      }
      nickname = "#{product[:name]} #{interval_key.capitalize}"
    else
      nickname = "#{product[:name]} Vitalício"
    end

    params[:nickname] = nickname

    stripe_price = Stripe::Price.create(params)
    puts "  Preço #{interval_key}: #{stripe_price.id} (R$#{'%.2f' % (price_data[:amount] / 100.0)})"

    env_key = "STRIPE_PRICE_#{product[:name].upcase}_#{interval_key.upcase}"
    env_output << "# #{env_key}=#{stripe_price.id}"
  end

  puts "  #{'Ativar no dashboard: https://dashboard.stripe.com/test/products' if stripe_prod.id}"
  puts
end

puts "=" * 60
puts "Adicione ao .env:"
puts
puts env_output.join("\n")
puts
puts "Após adicionar, recarregue o ENV ou reinicie o servidor."
