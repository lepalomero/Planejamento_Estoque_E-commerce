# Previsao-de-demanda
Repositório criado para armazenar arquivos do Trabalho Final da disciplina MS715- Planejamento e Controle de Produção 

Equipe: 
Gabriel Augusto Rebouças 
Letícia Palomero Rodrigues 
Lucas dos Santos Almeida 

## Geracao e alocacao de estoque

`src/config.jl` define `ConfigEstoque`. Os padroes incluem ocupacao entre 53% e
90%, capacidade de prateleira ilimitada, 3 prateleiras por estante, variedade
de 3 itens por estante, limite de 1 estante por item e classes ABC 70/20/10.
O armazem padrao tem largura 40, comprimento 80 e uma estante de saida em
`(0, 0)`; `n_estantes` e calculado como largura × comprimento.

`carregar_dados_estoque` le diretamente as colunas de `pedidos.csv` e
`produtos.csv` em `outputs/`. `gerar_estoque(pedidos, produtos, config)` garante
a demanda dos ultimos 30 dias e, com capacidade finita, completa a ocupacao
minima sem ultrapassar a maxima. Com capacidade infinita, a geracao interrompe
com aviso se nao houver variedade suficiente para todos os IDs dos produtos.
Produtos sem dimensoes podem permanecer sem estoque; se houver demanda recente
para um deles, a geracao interrompe com erro, pois nao e possivel calcular seu
volume.

`alocar!(warehouse, estoque, MetodoABC())` monta o grafo a partir da estante
de saida e distribui os itens por frequencia de pedidos; itens de classe A
recebem primeiro as estantes mais proximas. A mesma funcao aceita chamadas
incrementais no Warehouse preenchido, respeitando a capacidade e o limite de
estantes por item.

`executar_ciclo!(warehouse, previsoes, config)` agrega as previsoes semanais
por mes calendario e repoe, no inicio de cada mes, apenas o deficit em relacao
ao estoque atual. A coluna pode ser configurada por `coluna_previsao` (padrao
`:regressao_previsto`). A retirada diaria ainda nao esta implementada. Rode os
testes focados com `julia --project test\\runtests.jl`.
