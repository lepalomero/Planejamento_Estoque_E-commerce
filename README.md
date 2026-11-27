# Planejamento e Controle de Produção E-commerce 
<img src="media/fig-pcp-github.jpg" width="450">

## Sumário 

- [1. Descrição do Projeto](#1-Descrição-do-Projeto)
- [2. Objetivos](#2-Objetivos)
- [3. Banco de Dados](#3-Banco-de-Dados)
- [4. Previsão de Demanda](#4-Previsão-de-Demanda)
- [5. Layout do Armazém](#5-Layout-do-Armazém)
- [6. Gestão e alocação do estoque](#6-Gestão-e-alocação-do-estoque)
- [7. Roteamento de picking e caminhões](#7-Roteamento-de-picking-e-caminhões)
- [8. Técnicas e Tecnologias Utilizadas](#8-Técnicas-e-Tecnologias-Utilizadas)
- [9. Estrutura do projeto](#9-Estrutura-do-projeto)
- [10. Integrantes](#10-Integrantes)

## 1. Descrição do Projeto 

Este projeto é um estudo de caso de Planejamento e Controle da Produção para um e-commerce brasileiro, baseado no histórico público de vendas da Olist entre janeiro de 2017 e agosto de 2018. A versão final reúne a preparação dos dados com SQL, a análise de previsão de demanda por regressão linear e ARIMA, a geração e alocação de estoque, a simulação de picking e o cálculo e visualização de rotas no armazém. Esta é a versão final do repositório, sem previsão de novas alterações no código.

## 2. Objetivos
Construir um estudo de caso de Planejamento e Controle de Produção, visando cobrir os tópicos de previsão de demanda, organização de armazém e otimização de entrega.

## 3. Banco de Dados
Para a análise, foram utilizados dados públicos e reais de pedidos realizados na plataforma da Olist, empresa de comércio eletrônico brasileiro, entre 2017 e 2018. A base reúne mais de 100 mil pedidos e contempla informações sobre os produtos (categoria, dimensões, preço e peso), os vendedores e id dos clientes, além dos dados de cada pedido. 

Devido à grande quantidade de produtos e pedidos, o processamento da base foi realizada por meio de consultas SQL, executadas em Julia com a biblioteca DuckDB. as 74 categorias originais foram ordenadas de modo decrescente com base no número de itens vendidos no período analisado e foram selecionadas as categorias necessárias para representar ao menos 80% do total de itens vendidos. Esse critério resultou em 16 categorias. Para cada categoria selecionada, construiu-se uma série temporal de itens vendidos. Além disso, foi utilizada uma série agregada, construída a partir da base filtrada, totalizando 17 séries analisadas. 


## 4. Previsão de Demanda
Para o desenvolvimento da previsão de demanda, foram analisados dois modelos diferentes, sendo eles a Regressão Linear e o modelo de ARIMA. Ambos foram aplicados ao período de 02/01/2017 a 20/08/2018 e sua eficácia foi comparada a partir de testes estatísticos. 

### 4.1. Regressão Linear

O modelo de regressão linear utilizado supõe que a demanda y<sub>t</sub> no instante t pode ser decomposta em uma parte sistemática, linear nos parâmetros, e um erro aleatório:

<p align="center">
<b>y<sub>t</sub> = β<sub>0</sub> + β<sub>1</sub> · t + ε<sub>t</sub></b>
</p>

Em que:

- **y<sub>t</sub>**: demanda no instante t
- **t**: instante de tempo (variável explicativa)
- **β<sub>0</sub>**: intercepto do modelo
- **β<sub>1</sub>**: coeficiente angular (tendência da demanda ao longo do tempo)
- **ε<sub>t</sub>**: erro aleatório

#### Resultados

No modelo total, obteve-se o seguinte resultado para a quantidade de produtos a serem vendidos:

- **Intervalo de confiança (IC 95%):** 12,8 a 18,5
- **Coeficiente de determinação (R²):** 0,59

#### Interpretação

O R² = 0,59 indica que cerca de **59%** da variação da demanda é explicada pelo modelo. Considerando a **baixa quantidade de dados** disponíveis, o ajuste é aceitável. Com um histórico maior, o modelo tende a ganhar precisão e a produzir intervalos de confiança mais estreitos.
### 4.2. ARIMA 

O segundo modelo utilizado é o ARIMA(p, d, q), que descreve a demanda a partir dos seus próprios valores passados e dos erros passados. Depois de diferenciada d vezes, a série é modelada por:

<p align="center">
  <b>w<sub>t</sub> = φ<sub>1</sub> w<sub>t-1</sub> + … + φ<sub>p</sub> w<sub>t-p</sub> + θ<sub>1</sub> ε<sub>t-1</sub> + … + θ<sub>q</sub> ε<sub>t-q</sub> + ε<sub>t</sub></b>
</p>

<p align="center">
  em que <b>w<sub>t</sub> = (1 − B)<sup>d</sup> y<sub>t</sub></b>
</p>

Em que:

- **y<sub>t</sub>**: demanda semanal no instante t
- **w<sub>t</sub>**: série após d diferenciações
- **B**: operador de defasagem (B y<sub>t</sub> = y<sub>t-1</sub>)
- **p**: quantas semanas passadas da série entram no modelo (parte autorregressiva)
- **d**: quantas vezes a série foi diferenciada
- **q**: quantos erros passados entram no modelo (parte de médias móveis)
- **φ<sub>i</sub>**: coeficientes autorregressivos
- **θ<sub>j</sub>**: coeficientes de médias móveis
- **ε<sub>t</sub>**: erro aleatório

Os parâmetros (p, d, q) foram escolhidos com a função `auto.arima` do pacote `forecast`, em R. O SARIMA foi descartado porque, com poucos dados, não seria possível estimar a sazonalidade.

#### Resultados

Para a série total, o modelo selecionado foi o **ARIMA(2, 1, 2)**. Ele foi treinado com 52 semanas e validado nas 12 semanas seguintes (junho a agosto de 2018). Depois, foi reajustado com toda a base para prever as próximas 12 semanas.

- **Modelo final (série total):** ARIMA(2, 1, 2)
- **Previsão para as próximas 12 semanas:** parte de 982 itens na primeira semana, sobe até cerca de 1300 em outubro e chega a 1252 em novembro
- **Estacionariedade (teste ADF):** confirmada em apenas 4 das 16 categorias
- **Normalidade dos resíduos:** reprovada em 14 das 16 categorias

#### Interpretação

O ARIMA se adapta melhor ao padrão da série do que a regressão linear, que prevê valores sempre acima do observado. No entanto, suas previsões tendem a ficar próximas da **média da série**, o que é uma alternativa razoável quando há poucos dados. As previsões do ARIMA são bem menores que as da regressão linear (1739 a 1911 itens por semana).

Como a estacionariedade foi reprovada na maioria das categorias e os resíduos não são normais, os **intervalos de previsão ficam comprometidos**. Com apenas 86 semanas de dados, nenhum dos modelos reproduz o pico da Black Friday de novembro de 2017, e **nenhum deles é adequado para uso operacional**.

### 4.3. Verificação da Qualidade dos Métodos
Para verificar a eficácia e a veracidade dos métodos aplicados, testes estatísticos foram aplicados e os resultados analisados nas últimas 12 semanas da base foram comparadas para verificação. Para isso, mais especificamente, os testes Shapirro-Wilk e o teste de homocedasticidade foram analisados. 

Como resultado, notou-se que a regressão apresenta valores mais altos que a previsão em toda a série, já o ARIMA segue um comportamento quase linear, mas sempre chutando na média da série. Por conta da quantidade de dados disponível, concluiu-se que o ARIMA possui um desempenho melhor que a Regressão Linear por respeitar mais o comportamento da série. Entretanto, os pré-requisitos de cada modelo não são obedecidos pelos dados analisados, fato confirmado ao aplicar os testes estatísticos. Nesse sentido, seria necessário a visualização de outros modelos para desenvolvimento de uma previsão de demanda mais confiável. 

## 5. Layout do Armazém

O armazém segue o modelo Grid Layout com Corredores Transversais (Cross Aisles).
, onde há 1 corredor principal central e 1 corredor secundário de cada lado.
Produtos e prateleiras ficam somente nas faixas interiores, entre os corredores e tal estrutura foi escolhida pela boa visibilidade e organização do estoque, além da facilidade de criação de rotas de picking curtas para otimização. 

Na implementação do picking, as estantes ficam espelhadas em torno do eixo central `x = 0`, onde está a saída `(0, 0)`. Cada trecho da rota usa o menor caminho permitido pelos corredores central e laterais; não há deslocamentos diagonais ou atalhos entre estantes. A execução principal gera automaticamente os mapas SVG de todas as waves. Para regenerar as visualizações de um método, execute, por exemplo, `julia --project=. src\visualizacao\visualizar.jl outputs\picking\abc_sku`; substitua `abc_sku` por `random` ou `coocorrencia` para os outros métodos.

```text
┌────────────────────────────────────────────────────┐
│   ▼ RECEBIMENTO · CORREDOR TRANSVERSAL SUPERIOR    │
├────────────────────────────────────────────────────┤
│  SEC     ESTOQUE     PRINCIPAL    ESTOQUE      SEC │
│  ↕    ┌─────┬─────┐      ↕      ┌─────┬─────┐   ↕  │
│  ↕    │     │     │      ↕      │     │     │   ↕  │
│  ↕    └─────┴─────┘      ↕      └─────┴─────┘   ↕  │
│  ↕   · · · · · · · ·     ╬     · · · · · · · ·  ↕  │
│  ↕    ┌─────┬─────┐      ↕      ┌─────┬─────┐   ↕  │
│  ↕    │     │     │      ↕      │     │     │   ↕  │
│  ↕    └─────┴─────┘      ↕      └─────┴─────┘   ↕  │
│  ↕   · · · · · · · ·     ╬     · · · · · · · ·  ↕  │
│  ↕    ┌─────┬─────┐      ↕      ┌─────┬─────┐   ↕  │
│  ↕    │     │     │      ↕      │     │     │   ↕  │
│  ↕    └─────┴─────┘      ↕      └─────┴─────┘   ↕  │
├────────────────────────────────────────────────────┤
│    ▲ EXPEDIÇÃO · CORREDOR TRANSVERSAL INFERIOR     │
└────────────────────────────────────────────────────┘
```
### Legenda

| Símbolo | Elemento | Função |
|---------|----------|--------|
| `PRINCIPAL` | Corredor principal | Eixo central de circulação (empilhadeiras, fluxo de maior volume) |
| `SEC` | Corredores secundários | Circulação lateral junto às paredes (vazios, sem estoque) |
| `· · · ·` | Corredor transversal | Liga os corredores longitudinais e separa as fileiras de prateleiras |
| `╬` | Cruzamento | Encontro do corredor principal com um transversal |
| `↕` | Sentido de circulação | Corredores longitudinais |


## 6. Gestão e alocação do estoque

A geração de estoque, a alocação e a simulação mensal estão implementadas. `gerar_estoque` usa uma janela histórica configurável (30 dias por padrão) para contar unidades vendidas e frequência de pedidos por SKU, calcula o volume a partir das dimensões dos produtos e valida as restrições de capacidade. Quando é configurada uma capacidade finita de prateleira, também verifica os limites de ocupação mínima e máxima; caso seja necessário completar a ocupação mínima, seleciona estoque adicional de forma ponderada pela frequência, com semente reproduzível.

Há três métodos de alocação, executados separadamente pela `main`, cada um com sua própria instância de `Warehouse`:

- **`abc_sku`** (`MetodoABC`): ordena SKUs pela frequência de pedidos e os classifica em faixas ABC. Os percentuais padrão das classes são 70%, 20% e 10%; são configuráveis em `ConfigEstoque`.
- **`random`** (`MetodoAleatorio`): embaralha a ordem dos SKUs e das estantes com uma semente configurável, respeitando a capacidade e o limite de estantes por SKU.
- **`coocorrencia`** (`MetodoCoocorrencia`): constrói relações entre SKUs com previsão positiva na mesma semana e prioriza SKUs que coocorrem com maior frequência.

Durante o ciclo mensal, o sistema repõe o estoque conforme a demanda prevista e processa cada semana como uma wave. Cada método salva seus dados em `outputs/picking/<metodo>/`, sem misturar ou sobrescrever os resultados dos demais métodos. Os CSVs incluem estoque inicial e mensal, grafo do armazém, rotas, itens retirados e distâncias por wave. Para itens não atendidos, os arquivos registram a quantidade em falta e o motivo.

Antes de executar a `main`, `outputs/previsao_por_item.csv` deve estar disponível com as previsões por SKU e semana (previsão, limites inferior e superior para regressão e ARIMA). A análise e os testes dos modelos estão documentados em `previsao_de_demanda.Rmd`; esse arquivo não exporta automaticamente o CSV de previsão consumido pela `main`, que deve ser preparado separadamente. A `main` consulta os CSVs Olist em `archive/`, gera `outputs/pedidos.csv` e `outputs/produtos.csv` e carrega as previsões. Para preparar os dados e rodar os três métodos em sequência, na raiz do projeto:

```powershell
julia --project=. src\main.jl
```

## 7. Roteamento de picking e caminhões

O roteamento de picking está implementado. Em cada wave, a demanda é distribuída entre caminhões respeitando a capacidade volumétrica e o limite de SKUs por caminhão, ambos configuráveis em `ConfigEstoque`. Os padrões atuais são volume `10.000.000` e até `10` SKUs por caminhão. Unidades, volume, estoque insuficiente e itens que não podem ser carregados são registrados nos CSVs da wave.

Para calcular a rota, o sistema identifica as estantes que cada caminhão precisa visitar e usa uma heurística de vizinho mais próximo: a cada passo visita a estante pendente mais próxima da posição atual e, ao terminar, retorna à saída. A distância entre duas estantes considera os corredores do layout — corredor central e corredores laterais — e escolhe o menor caminho Manhattan permitido. A rota não é uma solução exata de otimização global.

Cada wave gera arquivos `rota_wave_<data>_<metodo>.csv` e `distancia_wave_<data>_<metodo>.csv`, com dados discriminados por caminhão. As visualizações mostram todas as waves e desenham os caminhões 1, 2 e 3 em vermelho, azul e verde; os CSVs e os cálculos de distância incluem todos os caminhões utilizados. Cada pasta de método contém um gráfico temporal das distâncias totais por wave. O gráfico comparativo `outputs/picking/distancia_temporal_abc_sku_random_coocorrencia.svg` exibe, no mesmo gráfico, todas as waves dos três métodos em séries de cores distintas.

Depois de executar a `main`, compare as distâncias acumuladas e os tempos de execução:

```powershell
julia --project=. src\comparar_metodos.jl
```

O comparador lê as distâncias de todas as waves e o tempo salvo em `tempo_execucao_<metodo>.csv`, imprime os totais e os métodos com menor distância e menor tempo, e gera `outputs/picking/comparacao_distancia_abc_sku_random_coocorrencia.csv`. O tempo por método inclui alocação, simulação e geração das visualizações; a preparação comum dos dados e a limpeza da saída ficam fora da medição.

Os parâmetros do armazém, estoque, alocação e caminhões ficam em `src/config/config.jl` (`ConfigEstoque`). Cada execução limpa os CSVs anteriores de picking dentro da pasta do método antes de gravar os resultados novos, sem apagar outros arquivos da pasta.

Para executar os testes automatizados:

```powershell
julia --project=. test\runtests.jl
```

## 8. Técnicas e Tecnologias Utilizadas

- **Julia 1.9 ou superior**: linguagem do pipeline de dados, geração de estoque, alocação, simulação, roteamento, comparação e visualizações.
- **DuckDB.jl / DuckDB**: consultas SQL sobre os CSVs Olist e leitura tipada dos arquivos de entrada, sem exigir um servidor de banco de dados.
- **R**: análise e avaliação das séries temporais documentadas em `previsao_de_demanda.Rmd`.
- **Pacotes R**: `tidyverse` (incluindo manipulação e gráficos), `lubridate`, `forecast`, `lmtest` e `tseries`.
- **Overleaf**: ferramenta de edição do relatório do projeto.
- **JuMP e HiGHS**: não são dependências da implementação final nem estão listados em `Project.toml`; alocação e roteamento são feitos pelas heurísticas descritas acima.

O ambiente Julia está descrito em `Project.toml` e travado em `Manifest.toml`. As bibliotecas R são instaladas separadamente no ambiente usado para executar o R Markdown.

## 9. Estrutura do projeto

```text
.
├── archive/
│   ├── olist_customers_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── olist_sellers_dataset.csv
│   └── product_category_name_translation.csv
├── data/
│   └── archive.zip
├── media/
│   └── fig-pcp-github.jpg
├── outputs/
│   ├── pedidos.csv
│   ├── previsao_por_item.csv
│   ├── produtos.csv
│   └── picking/
│       ├── abc_sku/
│       │   ├── *.csv (estoque, grafo, waves, rotas, itens, distâncias e tempo)
│       │   └── visualizacoes/
│       │       ├── index_abc_sku.html
│       │       ├── grafo_inicial_abc_sku.svg
│       │       ├── grafo_wave_<data>_caminhoes_1_2_3_abc_sku.svg
│       │       └── distancia_temporal_abc_sku.svg
│       ├── random/ (mesma estrutura, identificador random)
│       ├── coocorrencia/ (mesma estrutura, identificador coocorrencia)
│       ├── distancia_temporal_abc_sku_random_coocorrencia.svg
│       └── comparacao_distancia_abc_sku_random_coocorrencia.csv (gerado pelo comparador)
├── src/
│   ├── main.jl
│   ├── comparar_metodos.jl
│   ├── alocacao/
│   │   ├── abc.jl
│   │   └── alocacao.jl
│   ├── config/
│   │   └── config.jl
│   ├── estoque/
│   │   ├── distancia.jl
│   │   ├── gerar_estoque.jl
│   │   └── layout_estoque.jl
│   ├── io/
│   │   ├── carregar_dados_estoque.jl
│   │   ├── carregar_previsao.jl
│   │   └── sql_queries.jl
│   ├── modelo/
│   │   ├── estoque.jl
│   │   └── warehouse.jl
│   ├── picking/
│   │   ├── caminhao.jl
│   │   ├── picking.jl
│   │   └── roteamento.jl
│   ├── simulacao/
│   │   └── ciclo_mensal.jl
│   └── visualizacao/
│       └── visualizar.jl
├── test/
│   └── runtests.jl
├── Manifest.toml
├── Project.toml
├── README.md
├── previsao_de_demanda.Rmd
└── Previsão de demanda.pdf
```

`src/main.jl` coordena a consulta aos dados, a preparação do estoque e a execução sequencial das três heurísticas. `src/comparar_metodos.jl` compara distâncias e tempos. Os módulos Julia estão agrupados por responsabilidade em `alocacao/`, `config/`, `estoque/`, `io/`, `modelo/`, `picking/`, `simulacao/` e `visualizacao/`. A implementação SQL fica em `src/io/sql_queries.jl`. Cada pasta de método contém os CSVs de todas as waves, os índices HTML e os SVGs descritos acima.

## 10. Integrantes

Este projeto foi desenvolvido por:

| NOME |
| :--- |
| [ Leticia Palomero Rodrigues ](https://www.linkedin.com/in/leticia-palomero-rodrigues/) [<img src="https://cdn.jsdelivr.net/gh/simple-icons/simple-icons/icons/linkedin.svg" width="16" />](https://www.linkedin.com/in/leticia-palomero-rodrigues/) |
| [ Gabriel Augusto Rebouças Gomes ](https://www.linkedin.com/in/gabriel-augusto-rebou%C3%A7as-gomes/) [<img src="https://cdn.jsdelivr.net/gh/simple-icons/simple-icons/icons/linkedin.svg" width="16" />](https://www.linkedin.com/in/gabriel-augusto-rebou%C3%A7as-gomes/) |
| [ Lucas dos Santos Almeida ](https://www.linkedin.com/in/lucas-dos-santos-almeida-052114312/) [<img src="https://cdn.jsdelivr.net/gh/simple-icons/simple-icons/icons/linkedin.svg" width="16" />](https://www.linkedin.com/in/lucas-dos-santos-almeida-052114312/) |
