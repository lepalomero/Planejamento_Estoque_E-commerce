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

### 4.2. ARIMA

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
