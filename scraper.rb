# =============================================================================
# Take-Home Coding Challenge - Infosimples 2026
# Scraper da página de produto Stellarcraft (Corellian YT-1300f)
# =============================================================================
#
# Fluxo do programa:
#   1. GET na URL do produto;
#   2. Parse do HTML em UTF-8;
#   3. Extração dos 9 campos pedidos (title, brand, categories, description,
#      skus, specification, reviews, reviews_average_score, url);
#   4. Salva o resultado em produto.json.
# =============================================================================

require 'mechanize'
require 'json'

URL = 'https://infosimples.com/vagas/desafio/stellarcraft/product.html'.freeze

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------

# Converte uma string de preço no padrão brasileiro ("R$ 4.799.990,00") para
# Float. Retorna nil quando a string não contém dígitos.
#
# Estratégia: remove tudo que não é dígito, vírgula ou ponto; em seguida
# remove os pontos (separador de milhar BR) e troca a vírgula por ponto
# (separador decimal).
def parse_price(text)
  return nil if text.nil?
  cleaned = text.gsub(/[^\d,\.]/, '')
  return nil if cleaned.empty?
  cleaned.delete('.').tr(',', '.').to_f
end

# Conta o número de estrelas preenchidas (★) numa string como "★★★★☆".
def count_stars(text)
  return 0 if text.nil?
  text.count('★')
end

# Normaliza espaços em branco (quebras de linha, tabs, espaços múltiplos).
def squish(text)
  return '' if text.nil?
  text.gsub(/\s+/, ' ').strip
end

# ---------------------------------------------------------------------------
# 1) Requisição HTTP e parse do HTML
# ---------------------------------------------------------------------------

agent = Mechanize.new
# Identifica o agent como um navegador comum para evitar bloqueios básicos.
agent.user_agent_alias = 'Mac Safari'
page = agent.get(URL)

# Importante: garantir o parser em UTF-8 explicitamente, caso contrário
# caracteres acentuados (ç, ã, é, ...) podem fazer o Nokogiri abortar a
# leitura no meio do nó.
doc = Nokogiri::HTML.parse(page.body, nil, 'UTF-8')

resposta_final = {}

# ---------------------------------------------------------------------------
# 2) title
# ---------------------------------------------------------------------------
resposta_final['title'] = squish(doc.css('h1#product_title').text)

# ---------------------------------------------------------------------------
# 3) brand
# ---------------------------------------------------------------------------
brand_node = doc.at_css('.product-brand')
resposta_final['brand'] = squish(brand_node ? brand_node.text : '')

# ---------------------------------------------------------------------------
# 4) categories
# ---------------------------------------------------------------------------
breadcrumb_items = doc.css('.breadcrumb-bar nav a')
categories = breadcrumb_items.map { |n| squish(n.text) }.reject(&:empty?).uniq
resposta_final['categories'] = categories

# ---------------------------------------------------------------------------
# 5) description
# ---------------------------------------------------------------------------
description_node = doc.at_css('#tab-description')
if description_node
  paragraphs = description_node.css('p').map { |p| squish(p.text) }
  paragraphs = [squish(description_node.text)] if paragraphs.empty?
  resposta_final['description'] = paragraphs.reject(&:empty?).join("\n\n")
else
  resposta_final['description'] = ''
end

# ---------------------------------------------------------------------------
# 6) skus
# ---------------------------------------------------------------------------
skus = doc.css('.variant-btn').map do |sku|
  available = !sku['class'].to_s.split.include?('unavailable')

  {
    'name'          => squish(sku.at_css('.vname')&.text),
    'current_price' => available ? parse_price(sku.at_css('.vprice')&.text) : nil,
    'old_price'     => available ? parse_price(sku.at_css('.vprice-old')&.text) : nil,
    'available'     => available,
  }
end

resposta_final['skus'] = skus

# ---------------------------------------------------------------------------
# 7) specification
# ---------------------------------------------------------------------------
spec_tables = doc.css('.specs-table')
spec_tables = doc.css('table') if spec_tables.empty?

resposta_final['specification'] = spec_tables.flat_map do |table|
  table.css('tr').filter_map do |row|
    cells = row.css('th, td')
    next if cells.length < 2
    label = squish(cells[0].text)
    next if label.empty?
    { 'label' => label, 'value' => squish(cells[1].text) }
  end
end

# ---------------------------------------------------------------------------
# 8) reviews
# ---------------------------------------------------------------------------
reviews = []
review_nodes = doc.css('.review-card')

review_nodes.each do |r|
  name = squish(r.at_css('.reviewer-name')&.text)
  date = squish(r.at_css('.reviewer-date')&.text)
  score = count_stars(r.at_css('.review-stars')&.text)
  text = squish(r.at_css('.review-text, p')&.text)

  reviews << {
    'name' => name,
    'date' => date,
    'score' => score,
    'text' => text,
  }
end
resposta_final['reviews'] = reviews

# ---------------------------------------------------------------------------
# 9) reviews_average_score
# ---------------------------------------------------------------------------
average_score = doc.at_css('.avg-score')&.text

resposta_final['reviews_average_score'] = average_score

# ---------------------------------------------------------------------------
# 10) url
# ---------------------------------------------------------------------------
resposta_final['url'] = URL

# ---------------------------------------------------------------------------
# Salva o arquivo produto.json
# ---------------------------------------------------------------------------
File.open('produto.json', 'w') do |f|
  f.write(JSON.pretty_generate(resposta_final))
end

puts 'Arquivo produto.json gerado com sucesso!'
puts "Campos extraídos:"
puts "  - title:                 #{resposta_final['title'].inspect}"
puts "  - brand:                 #{resposta_final['brand'].inspect}"
puts "  - categories:            #{resposta_final['categories'].length} itens"
puts "  - description:           #{resposta_final['description'].length} caracteres"
puts "  - skus:                  #{resposta_final['skus'].length} variações"
puts "  - specification:         #{resposta_final['specification'].length} entradas"
puts "  - reviews:               #{resposta_final['reviews'].length} avaliações"
puts "  - reviews_average_score: #{resposta_final['reviews_average_score']}"
puts "  - url:                   #{resposta_final['url']}"
