include(joinpath(@__DIR__, "io", "sql_queries.jl"))
include(joinpath(@__DIR__, "io", "carregar_previsao.jl"))
include(joinpath(@__DIR__, "config.jl"))
include(joinpath(@__DIR__, "modelo", "estoque.jl"))
include(joinpath(@__DIR__, "modelo", "warehouse.jl"))
include(joinpath(@__DIR__, "estoque", "layout_estoque.jl"))
include(joinpath(@__DIR__, "estoque", "distancia.jl"))
include(joinpath(@__DIR__, "estoque", "gerar_estoque.jl"))
include(joinpath(@__DIR__, "alocacao", "abc.jl"))
include(joinpath(@__DIR__, "alocacao", "alocacao.jl"))
include(joinpath(@__DIR__, "io", "carregar_dados_estoque.jl"))
include(joinpath(@__DIR__, "simulacao", "ciclo_mensal.jl"))

function main()
    run_queries()

    caminho_previsao = joinpath(dirname(@__DIR__), "outputs", "previsao_por_item.csv")
    previsoes = carregar_previsao(caminho_previsao)

    caminho_pedidos = joinpath(dirname(@__DIR__), "outputs", "pedidos.csv")
    caminho_produtos = joinpath(dirname(@__DIR__), "outputs", "produtos.csv")
    pedidos, produtos = carregar_dados_estoque(caminho_pedidos, caminho_produtos)
    config = ConfigEstoque()
    estoque = gerar_estoque(pedidos, produtos, config)
    warehouse = Warehouse(config)
    alocar!(warehouse, estoque, MetodoABC())
    executar_ciclo!(warehouse, previsoes, config)

    return previsoes
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
