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
#
# Como executar:
#   1. Instale o Ruby (testado com Ruby 3.x).
#   2. Instale a gem Mechanize:
#        gem install mechanize
#   3. Rode:
#        ruby scraper.rb
#   4. O arquivo produto.json será gerado no diretório atual.
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
# O próprio enunciado do desafio cita explicitamente que o título do produto
# está numa <h1 id="product_title">.
resposta_final['title'] = squish(doc.css('h1#product_title').text)

# ---------------------------------------------------------------------------
# 3) brand
# ---------------------------------------------------------------------------
# A marca aparece logo abaixo do título. Tentamos vários seletores semânticos
# comuns; se nenhum bater, ficamos com string vazia (e o usuário pode ajustar
# o seletor após inspecionar o HTML).
brand_node = doc.at_css('#product_brand') ||
             doc.at_css('.product-brand') ||
             doc.at_css('[itemprop="brand"]')
resposta_final['brand'] = squish(brand_node ? brand_node.text : '')

# ---------------------------------------------------------------------------
# 4) categories
# ---------------------------------------------------------------------------
# As categorias estão no breadcrumb no topo da página, na ordem da mais geral
# à mais específica. Pegamos cada link/span do breadcrumb.
breadcrumb_items = doc.css('nav[aria-label="breadcrumbs"] a, ' \
                           '.breadcrumb-bar nav a')
categories = breadcrumb_items.map { |n| squish(n.text) }.reject(&:empty?).uniq
resposta_final['categories'] = categories

# ---------------------------------------------------------------------------
# 5) description
# ---------------------------------------------------------------------------
# A descrição é composta por parágrafos. Se houver vários <p>, juntamos com
# uma quebra dupla para preservar a separação.
description_node = doc.at_css('#tab-description') ||
                   doc.at_css('#product_description') ||
                   doc.at_css('.product-description')
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
# Cada SKU é uma variação do produto. As 3 variações esperadas são:
#   - Standard Configuration (disponível, com preço atual + preço antigo)
#   - Battle-Ready Configuration (indisponível, sem preços)
#   - Smuggler's Special (disponível, apenas preço atual)
skus = []
sku_nodes = doc.css('.variant-btn')

sku_nodes.each do |sku|
  name = squish(sku.at_css('.vname')&.text || '')

  current_node = sku.at_css('.vprice')
  current_price = current_node ? parse_price(current_node.text) : nil

  old_node = sku.at_css('.vprice-old')
  old_price = old_node ? parse_price(old_node.text) : nil

  # Disponibilidade: classe "unavailable" diretamente no elemento .variant-btn.
  available = !(sku['class'] || '').split.include?('unavailable')

  if !available
    current_price = nil
    old_price = nil
  end

  skus << {
    'name' => name,
    'current_price' => current_price,
    'old_price' => old_price,
    'available' => available,
  }
end

resposta_final['skus'] = skus

# ---------------------------------------------------------------------------
# 7) specification
# ---------------------------------------------------------------------------
# As specs aparecem em uma ou mais tabelas (Primary Specs / Secondary Specs).
# Cada linha tem um par label/value. Combinamos tudo numa única lista.
specifications = []
spec_tables = doc.css('#product_specifications table, ' \
                      '.product-specifications table, ' \
                      '.specifications table, ' \
                      '.specs-table')

# Fallback: se não achou tabelas em um container nomeado, tenta qualquer
# tabela da página (provavelmente são apenas as de specs mesmo).
spec_tables = doc.css('table') if spec_tables.empty?

spec_tables.each do |table|
  table.css('tr').each do |row|
    cells = row.css('th, td')
    next if cells.length < 2
    label = squish(cells[0].text)
    value = squish(cells[1].text)
    next if label.empty?
    specifications << { 'label' => label, 'value' => value }
  end
end
resposta_final['specification'] = specifications

# ---------------------------------------------------------------------------
# 8) reviews
# ---------------------------------------------------------------------------
reviews = []
review_nodes = doc.css('.review-card')

review_nodes.each do |r|
  name = squish(r.at_css('.reviewer-name')&.text || '')
  date = squish(r.at_css('.reviewer-date')&.text || '')
  score = count_stars(r.at_css('.review-stars')&.text || '')
  text = squish(r.at_css('.review-text, p')&.text || '')

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
# Preferimos extrair a média da própria página (mais fiel ao que o site
# exibe). Se não houver nó com a média, calculamos a partir dos scores.
avg_node = doc.at_css('.avg-score, #reviews_average_score, ' \
                      '.reviews-average-score, [itemprop="ratingValue"]')
average_score =
  if avg_node
    match = avg_node.text.match(/\d+[.,]?\d*/)
    match ? match[0].tr(',', '.').to_f : nil
  end

if average_score.nil? && !reviews.empty?
  total = reviews.sum { |r| r['score'].to_i }
  average_score = (total.to_f / reviews.length).round(2)
end

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
