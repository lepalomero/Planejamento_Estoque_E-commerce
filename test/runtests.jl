using Test

include(joinpath(@__DIR__, "..", "src", "main.jl"))
include(joinpath(@__DIR__, "..", "src", "comparar_metodos.jl"))

@testset "configuracoes gerais e de caminhao" begin
    config = ConfigEstoque(
        janela_historico_dias=45,
        penalidade_quantidade_extra=0.7,
        variacao_aleatoria_extra=0.1,
        cobertura_categorias=0.9,
        capacidade_volume_caminhao=120_000,
        capacidade_quantidade_caminhao=40,
    )
    @test config.janela_historico_dias == 45
    @test config.cobertura_categorias == 0.9
    @test caminhao(config).capacidade_volume == 120_000
    @test caminhao(config).capacidade_quantidade == 40
    caminhao_padrao = caminhao(ConfigEstoque())
    @test caminhao_padrao.capacidade_volume == 30
    @test caminhao_padrao.capacidade_quantidade == 1
    @test_throws ArgumentError caminhao(ConfigEstoque(
        capacidade_volume_caminhao=nothing,
        capacidade_quantidade_caminhao=nothing,
    ))
    @test_throws ArgumentError ConfigEstoque(
        capacidade_volume_caminhao=1,
        capacidade_quantidade_caminhao=nothing,
    )
    @test_throws ArgumentError ConfigEstoque(
        capacidade_volume_caminhao=nothing,
        capacidade_quantidade_caminhao=1,
    )
    @test_throws ArgumentError ConfigEstoque(cobertura_categorias=1.1)
end

@testset "layout espelhado e caminhos pelos corredores" begin
    config = ConfigEstoque(
        n_estantes=16,
        largura_armazem=2,
        comprimento_armazem=8,
    )
    warehouse = Warehouse(config)
    posicoes = [estante.posicao for estante in warehouse.estantes[2:end]]

    @test warehouse.estantes[1].posicao == (0.0, 0.0)
    @test any(posicao[1] < 0 for posicao in posicoes)
    @test any(posicao[1] > 0 for posicao in posicoes)
    @test all(abs(posicao[1]) < config.comprimento_armazem / 2 for posicao in posicoes)

    mesma_ala = distancia_estantes(
        warehouse.estantes[2],
        warehouse.estantes[4],
        config.largura_armazem,
        config.comprimento_armazem,
    )
    @test mesma_ala == 1.0
    @test (0.0, 0.0) in caminho_estantes(
        warehouse.estantes[2],
        warehouse.estantes[3],
        config.largura_armazem,
        config.comprimento_armazem,
    )

    origem = warehouse.estantes[10]
    destino = warehouse.estantes[14]
    caminho = caminho_estantes(
        origem,
        destino,
        config.largura_armazem,
        config.comprimento_armazem,
    )
    @test (4.0, origem.posicao[2]) in caminho
    @test distancia_estantes(
        origem,
        destino,
        config.largura_armazem,
        config.comprimento_armazem,
    ) == _comprimento_caminho(caminho) == 2.0
end

@testset "atualizacao dos arquivos de picking" begin
    mktempdir() do pasta_saida
        arquivos_antigos = [
            "estoque_inicial.csv",
            "grafo_inicial.csv",
            "estoque_inicial_abc_sku.csv",
            "grafo_inicial_random.csv",
            "grafo_inicial_coocorrencia.csv",
            "estoque_mensal_2020-01.csv",
            "estoque_mensal_2020-01_abc_sku.csv",
            "estoque_mensal_2020-01_random.csv",
            "grafo_wave_2020-01-01.csv",
            "grafo_wave_2020-01-01_coocorrencia.csv",
            "rota_wave_2020-01-01.csv",
            "rota_wave_2020-01-01_abc_sku.csv",
            "itens_retirados_wave_2020-01-01.csv",
            "itens_retirados_wave_2020-01-01_random.csv",
            "distancia_wave_2020-01-01.csv",
            "distancia_wave_2020-01-01_abc_sku.csv",
            "tempo_execucao_abc_sku.csv",
        ]
        nao_gerado = joinpath(pasta_saida, "anotacoes.txt")
        foreach(nome -> write(joinpath(pasta_saida, nome), "obsoleto"), arquivos_antigos)
        write(nao_gerado, "preservar")

        limpar_saida_picking!(pasta_saida)

        @test all(nome -> !isfile(joinpath(pasta_saida, nome)), arquivos_antigos)
        @test read(nao_gerado, String) == "preservar"
    end
end

@testset "carregamento de dados do estoque" begin
    mktempdir() do diretorio
        caminho_pedidos = joinpath(diretorio, "pedidos.csv")
        caminho_produtos = joinpath(diretorio, "produtos.csv")
        write(
            caminho_pedidos,
            "data_do_pedido,ids_dos_produtos\n2025-01-01 10:00:00,A\n",
        )
        write(
            caminho_produtos,
            "id,categoria,altura,largura,espessura\nA,cat,2,3,4\n",
        )

        pedidos, produtos = carregar_dados_estoque(caminho_pedidos, caminho_produtos)
        @test only(pedidos).ids_dos_produtos == "A"
        @test only(produtos).id == "A"
        @test only(produtos).categoria == "cat"
        @test only(produtos).altura == 2
    end
end

@testset "geracao de estoque" begin
    produtos = [
        (id="A", altura=1, largura=1, espessura=2),
        (id="B", altura=1, largura=1, espessura=3),
    ]
    pedidos = [
        (data_do_pedido="2025-01-01 10:00:00", ids_dos_produtos="A;B"),
        (data_do_pedido="2025-01-31 10:00:00", ids_dos_produtos="A;A"),
        (data_do_pedido="2024-12-31 10:00:00", ids_dos_produtos="B"),
    ]
    estoque = gerar_estoque(
        pedidos,
        produtos,
        ConfigEstoque(n_estantes=2, variedade_por_estante=1),
    )
    por_id = Dict(item.id => item for item in estoque)
    @test por_id["A"].quantidade == 3
    @test por_id["A"].frequencia_pedidos == 2
    @test por_id["B"].quantidade == 1
    @test por_id["B"].frequencia_pedidos == 1
    estoque_historico_maior = gerar_estoque(
        pedidos,
        produtos,
        ConfigEstoque(n_estantes=2, variedade_por_estante=1, janela_historico_dias=45),
    )
    @test only(filter(item -> item.id == "B", estoque_historico_maior)).quantidade == 2
    @test ConfigEstoque().n_estantes == 40 * 80

    produto_sem_dimensoes = [
        (id="A", altura=1, largura=1, espessura=1),
        (id="B", altura=missing, largura=1, espessura=1),
    ]
    estoque_sem_demanda = gerar_estoque(
        [(data_do_pedido="2025-01-31", ids_dos_produtos="A")],
        produto_sem_dimensoes,
        ConfigEstoque(n_estantes=1, variedade_por_estante=2),
    )
    @test only(filter(item -> item.id == "B", estoque_sem_demanda)).volume === nothing
    @test_throws ArgumentError gerar_estoque(
        [(data_do_pedido="2025-01-31", ids_dos_produtos="B")],
        produto_sem_dimensoes,
        ConfigEstoque(n_estantes=1, variedade_por_estante=2),
    )
end

@testset "alocacao aleatoria preenche estantes e respeita capacidade" begin
    config = ConfigEstoque(
        capacidade_prateleira=10,
        prateleiras_por_estante=1,
        n_estantes=3,
        variedade_por_estante=1,
        quantidade_maxima_estantes_item=3,
    )
    estoque = [ProdutoEstoque("A", 7, 3.0, 1)]
    warehouse_a = Warehouse(config)
    warehouse_b = Warehouse(config)
    alocar!(warehouse_a, estoque, MetodoAleatorio(31))
    alocar!(warehouse_b, estoque, MetodoAleatorio(31))

    alocados_a = [
        (estante.id, item.quantidade)
        for estante in warehouse_a.estantes
        for item in estante.itens
    ]
    alocados_b = [
        (estante.id, item.quantidade)
        for estante in warehouse_b.estantes
        for item in estante.itens
    ]
    @test alocados_a == alocados_b
    @test sort(last.(alocados_a)) == [1, 3, 3]
    @test sum(last, alocados_a) == 7
end

@testset "alocacao por coocorrencia de previsoes semanais" begin
    semana_1 = Date(2025, 1, 6)
    semana_2 = Date(2025, 1, 13)
    semana_3 = Date(2025, 1, 20)
    previsoes = Dict(
        "A" => [
            (semana=semana_1, regressao_previsto=1.0),
            (semana=semana_2, regressao_previsto=1.0),
        ],
        "B" => [
            (semana=semana_1, regressao_previsto=1.0),
            (semana=semana_2, regressao_previsto=1.0),
        ],
        "C" => [(semana=semana_3, regressao_previsto=1.0)],
    )
    metodo = MetodoCoocorrencia(previsoes, :regressao_previsto)
    @test _coocorrencia(metodo, "A", "B") == 2
    @test _coocorrencia(metodo, "A", "C") == 0

    config = ConfigEstoque(n_estantes=3, variedade_por_estante=2)
    warehouse = Warehouse(config)
    estoque = [
        ProdutoEstoque("A", 1, 1.0, 1),
        ProdutoEstoque("B", 1, 1.0, 1),
        ProdutoEstoque("C", 1, 1.0, 1),
    ]
    alocar!(warehouse, estoque, metodo)
    estante_por_item = Dict(
        item.id => estante.id
        for estante in warehouse.estantes
        for item in estante.itens
    )
    @test estante_por_item["A"] == estante_por_item["B"]
    @test estante_por_item["C"] != estante_por_item["A"]
end

@testset "resultados e visualizacoes separados por metodo" begin
    mktempdir() do pasta_base
        diretorios = String[]
        previsoes = Dict(
            "A" => [
                (semana=Date(2025, 1, 6), regressao_previsto=1.0),
                (semana=Date(2025, 1, 13), regressao_previsto=1.0),
            ],
        )
        metodos = (
            MetodoABC(),
            MetodoAleatorio(7),
            MetodoCoocorrencia(previsoes, :regressao_previsto),
        )
        for metodo in metodos
            pasta_metodo = _pasta_saida_metodo(pasta_base, metodo)
            sufixo_metodo = _nome_metodo(metodo)
            push!(diretorios, pasta_metodo)
            warehouse = Warehouse(ConfigEstoque(n_estantes=1))
            estoque = [ProdutoEstoque("A", 1, 1.0, 1)]
            alocar!(warehouse, estoque, metodo)
            salvar_estoque(
                joinpath(
                    pasta_metodo,
                    _sufixar_arquivo("estoque_inicial.csv", sufixo_metodo),
                ),
                warehouse,
            )
            salvar_grafo(
                joinpath(
                    pasta_metodo,
                    _sufixar_arquivo("grafo_inicial.csv", sufixo_metodo),
                ),
                warehouse,
            )
            @test isfile(_salvar_tempo_execucao(pasta_metodo, sufixo_metodo, 1.25))
            executar_ciclo!(
                warehouse,
                Dict("A" => [
                    (semana=Date(2025, 1, 6), regressao_previsto=1.0),
                    (semana=Date(2025, 1, 13), regressao_previsto=1.0),
                ]),
                warehouse.config;
                pasta_saida=pasta_metodo,
                metodo=metodo,
                sufixo_metodo=sufixo_metodo,
            )

            caminho_rota = joinpath(
                pasta_metodo,
                "rota_wave_2025-01-06_$(sufixo_metodo).csv",
            )
            linhas_rota = readlines(caminho_rota)
            linhas_tres_caminhoes = [first(linhas_rota)]
            for caminhao_id in 1:3, linha in linhas_rota[2:end]
                campos = String.(split(linha, ','))
                campos[1] = string(caminhao_id)
                push!(linhas_tres_caminhoes, join(campos, ','))
            end
            write(caminho_rota, join(linhas_tres_caminhoes, "\n") * "\n")

            caminho_indice = main_visualizar([pasta_metodo])
            @test isfile(joinpath(
                pasta_metodo,
                "estoque_inicial_$(sufixo_metodo).csv",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "grafo_inicial_$(sufixo_metodo).csv",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "grafo_wave_2025-01-06_$(sufixo_metodo).csv",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "distancia_wave_2025-01-06_$(sufixo_metodo).csv",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "visualizacoes",
                "grafo_inicial_$(sufixo_metodo).svg",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "visualizacoes",
                "grafo_wave_2025-01-06_caminhoes_1_2_3_$(sufixo_metodo).svg",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "visualizacoes",
                "grafo_wave_2025-01-13_caminhoes_1_2_3_$(sufixo_metodo).svg",
            ))
            @test isfile(joinpath(
                pasta_metodo,
                "visualizacoes",
                "distancia_temporal_$(sufixo_metodo).svg",
            ))
            @test endswith(caminho_indice, "index_$(sufixo_metodo).html")
            @test occursin(_nome_metodo(metodo), read(caminho_indice, String))
            caminho_svg = joinpath(
                pasta_metodo,
                "visualizacoes",
                "grafo_wave_2025-01-06_caminhoes_1_2_3_$(sufixo_metodo).svg",
            )
            conteudo_svg = read(caminho_svg, String)
            @test all(
                cor -> occursin("stroke=\"$(cor)\"", conteudo_svg),
                ("#dc2626", "#2563eb", "#16a34a"),
            )
        end
        @test length(unique(diretorios)) == 3
        grafico_comparativo = gerar_grafico_temporal_comparativo(pasta_base)
        @test isfile(grafico_comparativo)
        @test occursin("ABC SKU", read(grafico_comparativo, String))
        @test occursin("Aleatorio", read(grafico_comparativo, String))
        @test occursin("Coocorrencia", read(grafico_comparativo, String))
        conteudo_comparativo = read(grafico_comparativo, String)
        @test occursin("2025-01-06", conteudo_comparativo)
        @test occursin("2025-01-13", conteudo_comparativo)
        @test all(
            cor -> occursin("stroke=\"$(cor)\"", conteudo_comparativo),
            ("#7c3aed", "#ea580c", "#0f766e"),
        )
    end
end

@testset "comparacao de distancia total por heuristica" begin
    mktempdir() do pasta_picking
        distancias = Dict(
            "abc_sku" => [10.5, 2.0, 4.5],
            "random" => [6.0, 7.0],
            "coocorrencia" => [8.0, 6.0],
        )
        tempos = Dict("abc_sku" => 8.0, "random" => 3.0, "coocorrencia" => 5.0)
        for (heuristica, valores) in distancias
            pasta_metodo = joinpath(pasta_picking, heuristica)
            mkpath(pasta_metodo)
            write(joinpath(pasta_metodo, "grafo_inicial_$(heuristica).csv"), "grafo\n")
            write(
                joinpath(pasta_metodo, "tempo_execucao_$(heuristica).csv"),
                "metodo,tempo_execucao_segundos\n$(heuristica),$(tempos[heuristica])\n",
            )
            for (indice, distancia) in enumerate(valores)
                write(
                    joinpath(
                        pasta_metodo,
                        "distancia_wave_$(indice)_$(heuristica).csv",
                    ),
                    "semana,caminhao_id,distancia_percorrida\n" *
                    "2025-01-0$(indice),1,$(distancia)\n",
                )
            end
        end

        resultado = comparar_metodos_por_distancia(pasta_picking)
        @test resultado.abc_sku == 17.0
        @test resultado.random == 13.0
        @test resultado.coocorrencia == 14.0
        @test resultado.tempos == tempos
        @test resultado.menor_distancia == "random"
        @test resultado.menor_tempo == "random"
        @test isfile(resultado.caminho_csv)
        @test readlines(resultado.caminho_csv) == [
            "heuristica,distancia_total,tempo_execucao_segundos",
            "abc_sku,17.0,8.0",
            "random,13.0,3.0",
            "coocorrencia,14.0,5.0",
        ]
    end
end

@testset "limites de capacidade" begin
    pedidos = [(data_do_pedido="2025-01-31", ids_dos_produtos="A")]
    produtos = [(id="A", altura=1, largura=1, espessura=2)]
    config = ConfigEstoque(
        ocupacao_min=0.53,
        ocupacao_max=0.90,
        capacidade_prateleira=10,
        prateleiras_por_estante=1,
        n_estantes=2,
        quantidade_maxima_estantes_item=2,
    )
    estoque = gerar_estoque(pedidos, produtos, config)
    @test sum(item.quantidade * item.volume for item in estoque) >= 0.53 * 20
    @test sum(item.quantidade * item.volume for item in estoque) <= 0.90 * 20
    warehouse = Warehouse(config)
    alocar!(warehouse, estoque, MetodoABC())
    quantidades_alocadas = [
        item.quantidade
        for estante in warehouse.estantes
        for item in estante.itens
    ]
    @test sum(quantidades_alocadas) == only(estoque).quantidade
    @test length(quantidades_alocadas) == 2
    @test all(==(3), quantidades_alocadas)

    config_sem_variedade = ConfigEstoque(
        n_estantes=1,
        variedade_por_estante=1,
    )
    dois_produtos = [
        (id="A", altura=1, largura=1, espessura=1),
        (id="B", altura=1, largura=1, espessura=1),
    ]
    @test_throws ArgumentError gerar_estoque(
        [(data_do_pedido="2025-01-31", ids_dos_produtos="A;B")],
        dois_produtos,
        config_sem_variedade,
    )

    config_sem_demanda = ConfigEstoque(
        ocupacao_min=0.53,
        ocupacao_max=0.90,
        capacidade_prateleira=1,
        prateleiras_por_estante=1,
        n_estantes=1,
    )
    @test_throws ArgumentError gerar_estoque(
        [(data_do_pedido="2025-01-31", ids_dos_produtos="")],
        [(id="A", altura=1, largura=1, espessura=1)],
        config_sem_demanda,
    )

    config_demanda_acima = ConfigEstoque(
        ocupacao_min=0.1,
        ocupacao_max=0.9,
        capacidade_prateleira=1,
        prateleiras_por_estante=1,
        n_estantes=1,
    )
    @test_throws ArgumentError gerar_estoque(
        pedidos,
        [(id="A", altura=1, largura=1, espessura=2)],
        config_demanda_acima,
    )
end

@testset "alocacao ABC e divisao entre estantes" begin
    config = ConfigEstoque(
        capacidade_prateleira=10,
        prateleiras_por_estante=1,
        n_estantes=6,
        largura_armazem=2,
        comprimento_armazem=3,
        variedade_por_estante=2,
        quantidade_maxima_estantes_item=3,
    )
    estoque = [
        ProdutoEstoque("A", 12, 2.0, 10),
        ProdutoEstoque("B", 1, 1.0, 1),
        ProdutoEstoque("C", 1, 1.0, 1),
    ]
    warehouse = Warehouse(config)
    @test isempty(warehouse.grafo.adjacencias)
    alocar!(warehouse, estoque, MetodoABC())
    @test length(warehouse.grafo.adjacencias) == length(warehouse.estantes)
    @test warehouse.estantes[1].eh_saida
    @test warehouse.estantes[1].capacidade == 0

    alocacoes_a = [
        (estante.id, item.quantidade)
        for estante in warehouse.estantes
        for item in estante.itens
        if item.id == "A"
    ]
    @test length(alocacoes_a) == 3
    @test all(quantidade == 4 for (_, quantidade) in alocacoes_a)
    @test 1 in first.(alocacoes_a)
    @test_throws ArgumentError alocar!(warehouse, estoque, MetodoABC())
    alocar!(warehouse, [ProdutoEstoque("A", 1, 2.0, 10)], MetodoABC())
    @test sum(
        item.quantidade
        for estante in warehouse.estantes
        for item in estante.itens
        if item.id == "A";
        init=0,
    ) == 13
    @test sum(
        item.quantidade
        for estante in warehouse.estantes
        for item in estante.itens
        if item.id == "B";
        init=0,
    ) == 1
    @test sum(
        item.quantidade
        for estante in warehouse.estantes
        for item in estante.itens
        if item.id == "C";
        init=0,
    ) == 1
    @test length([
        estante for estante in warehouse.estantes
        if any(item -> item.id == "A", estante.itens)
    ]) == 3

    limite_config = ConfigEstoque(
        capacidade_prateleira=10,
        prateleiras_por_estante=1,
        n_estantes=3,
        quantidade_maxima_estantes_item=2,
    )
    @test_throws ArgumentError alocar!(
        Warehouse(limite_config),
        [ProdutoEstoque("A", 12, 2.0, 1)],
        MetodoABC(),
    )

    warehouse_sem_estoque = Warehouse(ConfigEstoque(
        n_estantes=1,
        variedade_por_estante=1,
    ))
    alocar!(
        warehouse_sem_estoque,
        [
            ProdutoEstoque("A", 1, 1.0, 1),
            ProdutoEstoque("B", 0, nothing, 0),
        ],
        MetodoABC(),
    )
    @test only(warehouse_sem_estoque.estantes[2].itens).id == "A"
    @test warehouse_sem_estoque.volumes["B"] === nothing
end

@testset "ciclo mensal de reposicao" begin
    @test ConfigEstoque().coluna_previsao == :regressao_previsto
    config = ConfigEstoque(
        capacidade_prateleira=10,
        prateleiras_por_estante=1,
        n_estantes=2,
        variedade_por_estante=1,
        quantidade_maxima_estantes_item=1,
        coluna_previsao=:regressao_previsto,
    )
    warehouse = Warehouse(config)
    alocar!(warehouse, [ProdutoEstoque("A", 3, 1.0, 2)], MetodoABC())
    mktempdir() do diretorio
        caminho_previsao = joinpath(diretorio, "previsao.csv")
        write(
            caminho_previsao,
            "categoria,item,semana,regressao_previsto,regressao_inferior,regressao_superior,arima_previsto,arima_inferior,arima_superior\n" *
            "cat,A,2025-01-06,2,0,0,4,0,0\n" *
            "cat,A,2025-01-13,2,0,0,4,0,0\n" *
            "cat,A,2025-02-03,5,0,0,5,0,0\n",
        )
        previsao = carregar_previsao(caminho_previsao)
        pasta_picking = joinpath(diretorio, "picking")
        salvar_estoque(joinpath(pasta_picking, "estoque_inicial.csv"), warehouse)
        salvar_grafo(joinpath(pasta_picking, "grafo_inicial.csv"), warehouse)
        executar_ciclo!(warehouse, previsao, config; pasta_saida=pasta_picking)
        @test isfile(joinpath(pasta_picking, "estoque_inicial.csv"))
        @test isfile(joinpath(pasta_picking, "grafo_inicial.csv"))
        @test isfile(joinpath(pasta_picking, "estoque_mensal_2025-01.csv"))
        @test isfile(joinpath(pasta_picking, "estoque_mensal_2025-02.csv"))
        @test isfile(joinpath(pasta_picking, "rota_wave_2025-01-06.csv"))
        @test isfile(joinpath(pasta_picking, "itens_retirados_wave_2025-01-06.csv"))
        @test isfile(joinpath(pasta_picking, "distancia_wave_2025-01-06.csv"))
        @test isfile(joinpath(pasta_picking, "grafo_wave_2025-01-06.csv"))
        rota = readlines(joinpath(pasta_picking, "rota_wave_2025-01-06.csv"))
        @test split(rota[2], ',')[1:3] == ["1", "1", "0"]
        @test split(rota[end], ',')[3] == "0"
        itens_retirados = readlines(
            joinpath(pasta_picking, "itens_retirados_wave_2025-01-06.csv"),
        )
        @test split(itens_retirados[2], ',')[1:3] == ["1", "A", "2"]
        @test split(itens_retirados[2], ',')[6] == "0"
        linhas_distancia = readlines(
            joinpath(pasta_picking, "distancia_wave_2025-01-06.csv"),
        )
        @test length(linhas_distancia) == 2
        distancia = split(linhas_distancia[2], ',')
        @test distancia[2] == "1"
        @test parse(Float64, distancia[3]) > 0
        @test sum(
            item.quantidade
            for estante in warehouse.estantes
            for item in estante.itens
            if item.id == "A";
            init=0,
        ) == 0

        config_arima = ConfigEstoque(
            capacidade_prateleira=10,
            prateleiras_por_estante=1,
            n_estantes=2,
            variedade_por_estante=1,
            quantidade_maxima_estantes_item=1,
            coluna_previsao=:arima_previsto,
        )
        warehouse_arima = Warehouse(config_arima)
        alocar!(warehouse_arima, [ProdutoEstoque("A", 3, 1.0, 2)], MetodoABC())
        executar_ciclo!(warehouse_arima, previsao, config_arima)
        @test sum(
            item.quantidade
            for estante in warehouse_arima.estantes
            for item in estante.itens
            if item.id == "A";
            init=0,
        ) == 0
    end

    @testset "distancia e carga por caminhao" begin
        config = ConfigEstoque(
            capacidade_prateleira=10,
            prateleiras_por_estante=1,
            n_estantes=2,
            variedade_por_estante=1,
            quantidade_maxima_estantes_item=1,
            capacidade_volume_caminhao=3,
            capacidade_quantidade_caminhao=1,
        )
        warehouse = Warehouse(config)
        alocar!(
            warehouse,
            [
                ProdutoEstoque("A", 1, 2.0, 1),
                ProdutoEstoque("B", 1, 2.0, 1),
            ],
            MetodoABC(),
        )

        mktempdir() do pasta_saida
            executar_picking_wave!(
                warehouse,
                Date(2025, 1, 6),
                Dict("A" => 1, "B" => 1),
                pasta_saida,
            )
            linhas_distancia = readlines(
                joinpath(pasta_saida, "distancia_wave_2025-01-06.csv"),
            )
            @test length(linhas_distancia) == 3
            @test split(linhas_distancia[2], ',')[2] == "1"
            @test split(linhas_distancia[3], ',')[2] == "2"
            @test all(
                parse(Float64, split(linha, ',')[7]) <= config.capacidade_volume_caminhao
                for linha in linhas_distancia[2:end]
            )
            linhas_rota = readlines(
                joinpath(pasta_saida, "rota_wave_2025-01-06.csv"),
            )[2:end]
            @test Set(split(linha, ',')[1] for linha in linhas_rota) == Set(["1", "2"])
            @test Set(split(linha, ',')[1] for linha in
                      readlines(joinpath(pasta_saida, "itens_retirados_wave_2025-01-06.csv"))[2:end]) ==
                  Set(["1", "2"])
        end

        config_volume_insuficiente = ConfigEstoque(
            capacidade_prateleira=10,
            prateleiras_por_estante=1,
            n_estantes=1,
            variedade_por_estante=1,
            quantidade_maxima_estantes_item=1,
            capacidade_volume_caminhao=1,
            capacidade_quantidade_caminhao=1,
        )
        warehouse_volume_insuficiente = Warehouse(config_volume_insuficiente)
        alocar!(
            warehouse_volume_insuficiente,
            [ProdutoEstoque("A", 1, 2.0, 1)],
            MetodoABC(),
        )
        mktempdir() do pasta_saida
            @test_logs (:warn, r"Itens nao carregados na wave") executar_picking_wave!(
                warehouse_volume_insuficiente,
                Date(2025, 1, 6),
                Dict("A" => 1),
                pasta_saida,
            )
            itens = readlines(
                joinpath(pasta_saida, "itens_retirados_wave_2025-01-06.csv"),
            )
            @test split(itens[2], ',')[1] == ""
            @test split(itens[2], ',')[6:7] == ["1", "capacidade_volume"]
            @test length(readlines(
                joinpath(pasta_saida, "distancia_wave_2025-01-06.csv"),
            )) == 1
            @test sum(
                item.quantidade
                for estante in warehouse_volume_insuficiente.estantes
                for item in estante.itens
                if item.id == "A";
                init=0,
            ) == 1
        end
    end

    config_sem_capacidade = ConfigEstoque(
        capacidade_prateleira=10,
        prateleiras_por_estante=1,
        n_estantes=2,
        variedade_por_estante=1,
        quantidade_maxima_estantes_item=1,
    )
    warehouse_sem_capacidade = Warehouse(config_sem_capacidade)
    alocar!(
        warehouse_sem_capacidade,
        [
            ProdutoEstoque("A", 10, 1.0, 2),
            ProdutoEstoque("B", 0, 1.0, 1),
        ],
        MetodoABC(),
    )
    previsao_sem_capacidade = Dict(
        "A" => [PrevisaoSemanal("cat", Date(2025, 1, 6), 11, 0, 0, 0, 0, 0)],
        "B" => [PrevisaoSemanal("cat", Date(2025, 1, 6), 1, 0, 0, 0, 0, 0)],
    )
    @test_logs (:warn, r"Reposicao nao coube no Warehouse") (:warn, r"Itens nao carregados na wave") executar_ciclo!(
        warehouse_sem_capacidade,
        previsao_sem_capacidade,
        config_sem_capacidade,
    )
    @test sum(
        item.quantidade
        for estante in warehouse_sem_capacidade.estantes
        for item in estante.itens
        if item.id == "B";
        init=0,
    ) == 0
end
