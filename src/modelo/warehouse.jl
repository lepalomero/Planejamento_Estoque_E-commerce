mutable struct Estante
    id::Int
    posicao::Tuple{Int,Int}
    itens::Vector{ItemArmazenado}
    capacidade::Float64
    eh_saida::Bool
end

mutable struct GrafoWarehouse
    adjacencias::Vector{Vector{Tuple{Int,Float64}}}
end

GrafoWarehouse() = GrafoWarehouse(Vector{Tuple{Int,Float64}}[])

mutable struct Warehouse
    grafo::GrafoWarehouse
    estantes::Vector{Estante}
    config::ConfigEstoque
    volumes::Dict{String,Union{Nothing,Float64}}
    frequencias_pedidos::Dict{String,Int}
end

function Warehouse(config::ConfigEstoque)
    capacidade = config.capacidade_prateleira * config.prateleiras_por_estante
    estantes = Estante[
        Estante(0, config.posicao_saida, ItemArmazenado[], 0.0, true),
    ]

    for indice in 1:config.n_estantes
        x = div(indice - 1, config.largura_armazem) + 1
        y = mod(indice - 1, config.largura_armazem)
        push!(
            estantes,
            Estante(indice, (x, y), ItemArmazenado[], capacidade, false),
        )
    end

    return Warehouse(
        GrafoWarehouse(),
        estantes,
        config,
        Dict{String,Union{Nothing,Float64}}(),
        Dict{String,Int}(),
    )
end
