include(joinpath(@__DIR__, "config", "config.jl"))
include(joinpath(@__DIR__, "picking", "caminhao.jl"))
include(joinpath(@__DIR__, "io", "sql_queries.jl"))
include(joinpath(@__DIR__, "io", "carregar_previsao.jl"))
include(joinpath(@__DIR__, "modelo", "estoque.jl"))
include(joinpath(@__DIR__, "modelo", "warehouse.jl"))
include(joinpath(@__DIR__, "estoque", "layout_estoque.jl"))
include(joinpath(@__DIR__, "estoque", "distancia.jl"))
include(joinpath(@__DIR__, "estoque", "gerar_estoque.jl"))
include(joinpath(@__DIR__, "alocacao", "abc.jl"))
include(joinpath(@__DIR__, "alocacao", "alocacao.jl"))
include(joinpath(@__DIR__, "picking", "roteamento.jl"))
include(joinpath(@__DIR__, "picking", "picking.jl"))
include(joinpath(@__DIR__, "io", "carregar_dados_estoque.jl"))
include(joinpath(@__DIR__, "simulacao", "ciclo_mensal.jl"))
include(joinpath(@__DIR__, "visualizacao", "visualizar.jl"))

function _salvar_tempo_execucao(pasta_saida, metodo, tempo_segundos)
    isfinite(tempo_segundos) && tempo_segundos >= 0 ||
        throw(ArgumentError("Tempo de execucao invalido para $(metodo)"))
    caminho = joinpath(pasta_saida, "tempo_execucao_$(metodo).csv")
    mkpath(pasta_saida)
    open(caminho, "w") do arquivo
        println(arquivo, "metodo,tempo_execucao_segundos")
        println(arquivo, "$(metodo),$(tempo_segundos)")
    end
    return caminho
end

function main()
    config = ConfigEstoque()
    run_queries(config)

    caminho_previsao = joinpath(dirname(@__DIR__), "outputs", "previsao_por_item.csv")
    previsoes = carregar_previsao(caminho_previsao)

    caminho_pedidos = joinpath(dirname(@__DIR__), "outputs", "pedidos.csv")
    caminho_produtos = joinpath(dirname(@__DIR__), "outputs", "produtos.csv")
    pedidos, produtos = carregar_dados_estoque(caminho_pedidos, caminho_produtos)
    estoque = gerar_estoque(pedidos, produtos, config)
    pasta_picking = joinpath(dirname(@__DIR__), "outputs", "picking")
    metodos_alocacao = (
        ("abc_sku", () -> MetodoABC()),
        ("random", () -> MetodoAleatorio(config.semente)),
        ("coocorrencia", () -> MetodoCoocorrencia(previsoes, config.coluna_previsao)),
    )
    for (sufixo_metodo, criar_metodo) in metodos_alocacao
        pasta_metodo = joinpath(pasta_picking, sufixo_metodo)
        limpar_saida_picking!(pasta_metodo)
        inicio_execucao = time_ns()
        metodo_alocacao = criar_metodo()
        warehouse = Warehouse(config)
        alocar!(warehouse, estoque, metodo_alocacao)
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
        executar_ciclo!(
            warehouse,
            previsoes,
            config;
            pasta_saida=pasta_metodo,
            metodo=metodo_alocacao,
            sufixo_metodo=sufixo_metodo,
        )
        gerar_visualizacoes(pasta_metodo; sufixo_metodo=sufixo_metodo)
        tempo_segundos = (time_ns() - inicio_execucao) / 1e9
        _salvar_tempo_execucao(pasta_metodo, sufixo_metodo, tempo_segundos)
        println("Tempo de execucao $(sufixo_metodo): $(tempo_segundos) segundos")
    end
    println(
        "Grafico temporal comparativo salvo em: ",
        gerar_grafico_temporal_comparativo(pasta_picking),
    )

    return previsoes
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
