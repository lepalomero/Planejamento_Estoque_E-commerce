using Test

include(joinpath(@__DIR__, "..", "src", "main.jl"))

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
    @test_throws ArgumentError gerar_estoque(pedidos, dois_produtos, config_sem_variedade)

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
        executar_ciclo!(warehouse, previsao, config)
        @test sum(
            item.quantidade
            for estante in warehouse.estantes
            for item in estante.itens
            if item.id == "A";
            init=0,
        ) == 5

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
        ) == 8
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
    @test_logs (:warn, r"Reposicao nao coube no Warehouse") executar_ciclo!(
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
    ) == 1
end
