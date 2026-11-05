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
