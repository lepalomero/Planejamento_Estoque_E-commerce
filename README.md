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
