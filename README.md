# Planejamento e Controle de Produção E-commerce 
<img src="media/fig-pcp-github.jpg" width="450">

## Sumário 

- [1. Descrição do Projeto](#1-Descrição-do-Projeto)
- [2. Objetivos](#2-Objetivos)
- [3. Banco de Dados](#3-Banco-de-Dados)
- [4. Previsão de Demanda](#4-Previsão-de-Demanda)
- [5. Layout do Armazém](#5-Layout-do-Armazém)
- [6. Otimização estoque](#6-Otimização-estoque)
- [7. Roteamento caminhões](#7-Roteamento-caminhões)
- [8. Técnicas e Tecnologias Utilizadas](#8-Técnicas-e-Tecnologias-Utilizadas)
- [9. Equipe](#9-Equipe)

## 1. Descrição do Projeto 

O trabalho é um estudo de caso de Planejamento e Controle de Produção sobre um E-commerce Brasileiro a partir do histórico de vendas público da Olist, entre janeiro 2017 e agosto de 2018. A execução do trabalho foi dividida em etapas e ainda está em andamento. Primeiro foi realizada a limpeza de dados, utilizando SQL para filtrar os principais produtos a serem analisados e armazenados para compor o estoque principal do e-commerce. A partir de tal seleção, utilizamos os métodos de regressão linear e ARIMA para fazer uma previsão de demanda, uma vez que métodos de aprendizado de máquina não poderiam ser aplicados pela baixa quantidade de dados para análise. Com a previsão de demanda por produto, definimos a estrutura do armazém e utilizamos a distância de Manhattan para estruturar o deslocamento dentro do espaço. 
Como passos seguintes, pretende-se construir o modelo de otimização do posicionamento dos produtos dentro do armazém idealizado e de otimização do roteamento de caminhões para entregas diárias. 

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

Na implementação do picking, as estantes ficam espelhadas em torno do eixo central `x = 0`, onde está a saída `(0, 0)`. Cada trecho da rota usa o menor caminho permitido pelos corredores central e laterais; não há deslocamentos diagonais ou atalhos entre estantes. A execução principal gera os mapas SVG automaticamente; para regenerá-los, execute `julia src\visualizacao\visualizar.jl outputs\picking\abc_sku`, `outputs\picking\random` ou `outputs\picking\coocorrencia`.

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


## 6. Otimização Estoque
Em desenvolvimento 

### Picking e simulação

Execute `julia --project=. src/main.jl` para gerar e simular sequencialmente `abc_sku`, `random` e `coocorrencia`, cada método com seu próprio `Warehouse`. Os resultados ficam separados em `outputs/picking/abc_sku/`, `outputs/picking/random/` e `outputs/picking/coocorrencia/`; todos os CSVs e as visualizações também incluem o identificador do método no nome. A alocação `random` embaralha SKUs e estantes com a semente configurada, preenchendo cada estante escolhida até sua capacidade antes de sortear outra. `coocorrencia` agrupa SKUs cujas previsões são positivas nas mesmas semanas. Cada pasta contém estoque inicial e mensal, grafos, rotas, itens retirados, distâncias e visualizações em SVG/HTML. Rotas, itens retirados e distâncias são discriminados por caminhão (`caminhao_id`). A falta de estoque ou de capacidade aparece nas colunas `falta` e `motivo` dos arquivos de itens retirados. Os mapas de rota são gerados para todas as waves e mostram os caminhões 1, 2 e 3 simultaneamente, em vermelho, azul e verde, dentro do índice visual de cada método. Cada método recebe um gráfico temporal com a distância total de todas as waves. `outputs/picking/distancia_temporal_abc_sku_random_coocorrencia.svg` compara os três métodos no mesmo gráfico, cada um com uma cor, somando a distância de todos os caminhões por wave.

Depois das três execuções, compare a soma das distâncias de todas as waves e caminhões e o tempo de execução com `julia --project=. src\comparar_metodos.jl`. A duração medida para cada método inclui a alocação inicial, a simulação mensal e a geração das visualizações; a preparação comum dos dados e a limpeza da pasta ficam fora da medição. O tempo de cada método é salvo em `tempo_execucao_<metodo>.csv` na pasta correspondente. O comparador imprime as distâncias e os tempos, identifica o método mais rápido e gera `outputs/picking/comparacao_distancia_abc_sku_random_coocorrencia.csv` com ambos os valores.

Os parâmetros gerais ficam em `ConfigEstoque` (`src/config/config.jl`), incluindo janela histórica, cobertura de categorias e critérios de reposição aleatória. As capacidades padrão do caminhão são volume `30` e variedade de `1` SKU; ajuste `capacidade_volume_caminhao` e `capacidade_quantidade_caminhao` em conjunto. O volume da carga é calculado como volume unitário vezes quantidade e usa a mesma unidade cúbica dos produtos. Cada execução remove os CSVs de picking gerados anteriormente antes de gravar os novos, sem apagar outros arquivos da pasta.

`MetodoABC()` ordena os SKUs pela frequência de pedidos. `MetodoAleatorio(semente)` escolhe a ordem dos SKUs e das estantes aleatoriamente, usando a semente para resultados reproduzíveis e respeitando capacidades e limite de estantes por SKU. `MetodoCoocorrencia(previsoes, coluna)` ordena SKUs pela coocorrência de previsões semanais positivas. O script principal executa os três métodos e grava cada resultado em sua própria pasta, sem sobrescrever os dados dos outros métodos.

## 7. Roteamento caminhões
Em desenvolvimento

## 8. Técnicas e Tecnologias Utilizadas
- ``Julia``
- ``R``
- ``HiGHS``
- ``JuMP``
- ``Overleaf``
## 9. Equipe

Este projeto foi desenvolvido por:

| NOME  | 
| :--- |
| Leticia Palomero Rodrigues | 
| Gabriel Augusto Rebouças Gomes | 
| Lucas dos Santos Almeida|

## Estrutura do projeto

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
│       ├── coocorrencia/
│       ├── random/
│       ├── comparacao_distancia_abc_sku_random_coocorrencia.csv
│       └── distancia_temporal_abc_sku_random_coocorrencia.svg
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

`src/main.jl` coordena a preparação dos dados e a execução sequencial das heurísticas. `src/comparar_metodos.jl` compara as distâncias e os tempos de execução. Os módulos estão agrupados por responsabilidade: alocação, configuração, estoque, entrada/saída de dados, modelos, picking, simulação e visualização. As consultas SQL ficam em `src/io/sql_queries.jl`; os arquivos duplicados e obsoletos que estavam diretamente em `src/` foram removidos. Cada pasta de método em `outputs/picking/` contém `visualizacoes/` e CSVs com o sufixo do método, incluindo distâncias, rotas, estoque e `tempo_execucao_<metodo>.csv`; esses resultados variam conforme os dados. O índice de cada pasta mostra todas as waves, as rotas dos três primeiros caminhões e um gráfico temporal da distância total. O gráfico comparativo apresenta todas as waves dos três métodos em séries coloridas.
