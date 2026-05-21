# Take-Home Coding Challenge — Infosimples 2026

Solução do desafio de web scraping da página de produto Stellarcraft
(Corellian YT-1300f Light Freighter), proposto no processo seletivo da
Infosimples.

URL alvo:
https://infosimples.com/vagas/desafio/stellarcraft/product.html

## Como executar

Requisitos: Ruby 3.x e a gem Mechanize.

```
# 1. Instale a dependência
gem install mechanize

# 2. Rode o scraper
ruby scraper.rb

# 3. O arquivo produto.json será gerado no diretório atual.
```

Ao rodar, o programa imprime um pequeno resumo do que foi extraído (quantos
SKUs, quantas reviews, etc.), o que facilita verificar visualmente se a
extração funcionou.

## Estrutura

```
.
├── README.md     Este arquivo.
└── scraper.rb    O scraper (código principal).
```

Ao rodar, é gerado o `produto.json` no mesmo diretório.

## Fluxo do scraper

Seguindo o template sugerido pelo PDF do desafio:

1. **GET HTTP** na página de produto via Mechanize.
2. **Parse do HTML** com Nokogiri (forçando UTF-8 — detalhe importante para
   não cortar nós com acentuação).
3. **Extração dos 9 campos** pedidos no spec:
   - `title` — `h1#product_title` (confirmado pelo enunciado do desafio).
   - `brand` — nó com id/class semântica de marca.
   - `categories` — itens do breadcrumb na ordem em que aparecem.
   - `description` — parágrafos da seção de descrição, juntos com `\n\n`.
   - `skus` — uma entrada por variação do produto, contendo `name`,
     `current_price`, `old_price` e `available`. Quando a variação está
     indisponível, ambos os preços viram `null`.
   - `specification` — todas as linhas de todas as tabelas de specs
     consolidadas em uma única lista de pares `{label, value}`.
   - `reviews` — uma entrada por avaliação, com `name`, `date`, `score`
     (contagem das estrelas ★ preenchidas) e `text`.
   - `reviews_average_score` — média extraída diretamente do nó `.avg-score`.
   - `url` — a URL acessada.
4. **Serialização** do hash final em JSON e gravação em `produto.json`.

## Detalhes da implementação

### Conversão de preços brasileiros

Preços vêm no formato `"R$ 4.799.990,00"`. O método `parse_price`:

1. Remove tudo que não é dígito, vírgula ou ponto.
2. Remove os pontos (separador de milhar brasileiro).
3. Troca a vírgula por ponto (separador decimal).
4. Converte para `Float`.

Resultado: `"R$ 4.799.990,00"` → `4799990.0`.

### Contagem de estrelas

As reviews mostram a nota em estrelas Unicode (`★★★★☆`). O método
`count_stars` apenas conta os caracteres `★` (estrelas cheias), ignorando
os `☆` (estrelas vazias). Isso é mais robusto que tentar parsear texto.

### Encoding UTF-8 explícito

O HTML da página contém caracteres acentuados (ç, ã, é, ó, etc.) e o
em-dash (—). Sem passar `'UTF-8'` explicitamente para o Nokogiri, ele
pode interpretar os bytes como ISO-8859-1 e abortar a leitura de nós
no meio de palavras com acento, devolvendo árvores DOM truncadas. Por
isso a linha:

```ruby
doc = Nokogiri::HTML.parse(page.body, nil, 'UTF-8')
```

### Disponibilidade dos SKUs

Cada variação do produto é um `div.variant-btn`. Quando indisponível,
o elemento carrega a classe adicional `unavailable`. A checagem é feita
diretamente nessa classe:

```ruby
available = !sku['class'].to_s.split.include?('unavailable')
```

Quando indisponível, ambos os preços viram `null` (preço de produto sem
estoque não faz sentido para o consumidor).
